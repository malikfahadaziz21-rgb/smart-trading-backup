from pydantic import BaseModel
from typing import Optional

class StrategyDraftResponse(BaseModel):
    job_id: str
    status: str
    message: str

class StrategyResultResponse(BaseModel):
    job_id: str
    status: str
    compile_success: Optional[str]
    compile_log: Optional[str]
    backtest_result: Optional[str]
    script_content: Optional[str]
