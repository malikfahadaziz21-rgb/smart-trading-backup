import stripe
from backend.config import settings

stripe.api_key = settings.STRIPE_SECRET_KEY

def create_checkout_session(user_id: str, email: str) -> str:
    """Create a Stripe checkout session for a user."""
    try:
        session = stripe.checkout.Session.create(
            payment_method_types=['card'],
            line_items=[{
                'price': settings.STRIPE_PRO_PRICE_ID,
                'quantity': 1,
            }],
            mode='subscription',
            success_url='http://localhost:5173/?success=true&session_id={CHECKOUT_SESSION_ID}',
            cancel_url='http://localhost:5173/?canceled=true',
            customer_email=email,
            client_reference_id=str(user_id),
            metadata={
                'user_id': str(user_id)
            }
        )
        return session.url
    except Exception as e:
        print(f"Error creating checkout session: {str(e)}")
        raise e

def create_portal_session(customer_id: str) -> str:
    """Create a Stripe customer portal session for managing billing."""
    try:
        session = stripe.billing_portal.Session.create(
            customer=customer_id,
            return_url='http://localhost:5173/'
        )
        return session.url
    except Exception as e:
        print(f"Error creating portal session: {str(e)}")
        raise e
