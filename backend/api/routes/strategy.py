from fastapi import APIRouter, BackgroundTasks, Depends
from sqlalchemy.orm import Session
from backend.workers.tasks import process_strategy_pipeline
from backend.api.models.request_models import StrategyRequest
from backend.db.database import get_db
from backend.db.models import Job

router = APIRouter(prefix="/api/v1", tags=["strategy"])

async def create_job(prompt: str, db: Session) -> Job:
    job = Job(user_prompt=prompt, script_name="")
    db.add(job)
    db.commit()
    db.refresh(job)
    return job

@router.post("/generate")
async def generate_and_compile(
    request: StrategyRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    # Create job in DB
    job = await create_job(request.prompt, db)
    
    # Queue the full pipeline as background task
    # Note: Bypassing Celery for quick local testing and using BackgroundTasks.
    from backend.workers.tasks import process_strategy_pipeline
    background_tasks.add_task(process_strategy_pipeline, str(job.id), request.prompt)
    
    return {
        "job_id": str(job.id),
        "status": "pending",
        "message": "Pipeline started"
    }
