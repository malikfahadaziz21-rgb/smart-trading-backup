from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.db.database import get_db
from backend.db.models import Job
from backend.api.models.response_models import StrategyResultResponse

router = APIRouter(prefix="/api/v1", tags=["results"])

async def get_job_by_id(job_id: str, db: Session) -> Job:
    job = db.query(Job).filter(Job.id == job_id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return job

@router.get("/results/{job_id}", response_model=StrategyResultResponse)
async def get_results(job_id: str, db: Session = Depends(get_db)):
    job = await get_job_by_id(job_id, db)
    return {
        "job_id": str(job.id),
        "status": job.status.value,
        "compile_success": job.compile_success,
        "compile_log": job.compile_log,
        "backtest_result": job.backtest_result,
        "script_content": job.script_content
    }
