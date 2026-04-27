from fastapi import APIRouter, Depends, HTTPException, Request, Header
from sqlalchemy.orm import Session
from backend.db.database import get_db
from backend.db.models import User
from backend.services.auth_service import get_current_user
from backend.services.stripe_service import create_checkout_session, create_portal_session
from backend.config import settings
from pydantic import BaseModel
import stripe

router = APIRouter(prefix="/api/v1/billing", tags=["billing"])

class BillingStatusResponse(BaseModel):
    is_pro: bool
    daily_used: int
    tries_remaining: int
    has_portal: bool

@router.get("/status", response_model=BillingStatusResponse)
async def get_billing_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Return the user's current billing and usage status."""
    from datetime import date
    
    # Reset daily limit if it's a new day
    if current_user.last_used_date != date.today():
        current_user.daily_used = 0
        current_user.last_used_date = date.today()
        db.commit()

    tries_remaining = "unlimited" if current_user.is_pro else max(0, 5 - current_user.daily_used)
    
    return {
        "is_pro": current_user.is_pro,
        "daily_used": current_user.daily_used,
        "tries_remaining": 99999 if current_user.is_pro else tries_remaining,
        "has_portal": bool(current_user.stripe_customer_id)
    }

@router.post("/create-checkout")
async def create_checkout(
    current_user: User = Depends(get_current_user)
):
    """Create a Stripe checkout session."""
    if current_user.is_pro:
        raise HTTPException(status_code=400, detail="User is already Pro.")
        
    url = create_checkout_session(str(current_user.id), current_user.email)
    return {"url": url}

@router.post("/create-portal")
async def create_portal(
    current_user: User = Depends(get_current_user)
):
    """Create a Stripe billing portal session."""
    if not current_user.stripe_customer_id:
        raise HTTPException(status_code=400, detail="No billing history found.")
        
    url = create_portal_session(current_user.stripe_customer_id)
    return {"url": url}

@router.post("/webhook")
async def stripe_webhook(
    request: Request,
    stripe_signature: str = Header(None),
    db: Session = Depends(get_db)
):
    """Handle Stripe webhook events."""
    payload = await request.body()
    
    try:
        event = stripe.Webhook.construct_event(
            payload, stripe_signature, settings.STRIPE_WEBHOOK_SECRET
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail="Invalid payload")
    except stripe.error.SignatureVerificationError as e:
        raise HTTPException(status_code=400, detail="Invalid signature")

    # Handle the event
    if event['type'] == 'checkout.session.completed':
        session = event['data']['object']
        
        user_id = session.get('client_reference_id')
        customer_id = session.get('customer')
        
        if user_id and customer_id:
            user = db.query(User).filter(User.id == user_id).first()
            if user:
                user.is_pro = True
                user.stripe_customer_id = customer_id
                db.commit()
                print(f"User {user_id} upgraded to Pro!")

    elif event['type'] == 'customer.subscription.deleted':
        subscription = event['data']['object']
        customer_id = subscription.get('customer')
        
        user = db.query(User).filter(User.stripe_customer_id == customer_id).first()
        if user:
            user.is_pro = False
            db.commit()
            print(f"User {user.id} subscription cancelled.")

    return {"status": "success"}
