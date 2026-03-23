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
