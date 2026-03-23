from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.db.database import get_db
from backend.db.models import Job, User
from backend.api.models.response_models import StrategyResultResponse
from backend.services.auth_service import get_current_user
from typing import List

router = APIRouter(prefix="/api/v1", tags=["results"])

@router.get("/results/history", response_model=List[StrategyResultResponse])
async def get_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return the current user's job history (up to 5 most recent)."""
    jobs = (
        db.query(Job)
        .filter(Job.user_id == current_user.id)
        .order_by(Job.created_at.desc())
        .limit(5)
        .all()
    )
    return [
        {
            "job_id": str(j.id),
            "status": j.status.value,
            "compile_success": j.compile_success,
            "compile_log": j.compile_log,
            "backtest_result": j.backtest_result,
            "script_content": j.script_content,
            "prompt": j.user_prompt,
        }
        for j in jobs
    ]

@router.get("/results/{job_id}", response_model=StrategyResultResponse)
async def get_results(
    job_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    job = db.query(Job).filter(Job.id == job_id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    # Users can only view their own jobs
    if job.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to view this job")
    return {
        "job_id": str(job.id),
        "status": job.status.value,
        "compile_success": job.compile_success,
        "compile_log": job.compile_log,
        "backtest_result": job.backtest_result,
        "script_content": job.script_content,
        "prompt": job.user_prompt,
    }
