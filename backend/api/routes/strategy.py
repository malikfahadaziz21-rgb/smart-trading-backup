from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from backend.workers.tasks import process_strategy_pipeline
from backend.api.models.request_models import StrategyRequest
from backend.db.database import get_db
from backend.db.models import Job, User
from backend.services.auth_service import get_current_user, enforce_script_limit

router = APIRouter(prefix="/api/v1", tags=["strategy"])

async def create_job(prompt: str, user_id, db: Session) -> Job:
    job = Job(user_prompt=prompt, script_name="", user_id=user_id)
    db.add(job)
    db.commit()
    db.refresh(job)
    return job

@router.post("/generate")
async def generate_and_compile(
    request: StrategyRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from datetime import date
    from fastapi import HTTPException
    
    # Enforce daily limit for free users
    if not current_user.is_pro:
        if current_user.last_used_date != date.today():
            current_user.daily_used = 0
            current_user.last_used_date = date.today()
            
        if current_user.daily_used >= 5:
            raise HTTPException(status_code=429, detail="Daily limit reached. Please upgrade to Pro.")
            
        current_user.daily_used += 1
        db.commit()

    # Create job linked to user
    job = await create_job(request.prompt, current_user.id, db)
    
    # Enforce 5-script rolling limit (delete oldest if > 5)
    enforce_script_limit(current_user.id, db)
    
    # Queue the full pipeline via Celery
    process_strategy_pipeline.delay(str(job.id), request.prompt)
    
    return {
        "job_id": str(job.id),
        "status": "pending",
        "message": "Pipeline started"
    }
