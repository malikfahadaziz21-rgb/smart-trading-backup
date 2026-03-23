from pydantic import BaseModel
from typing import Optional

class StrategyDraftResponse(BaseModel):
    job_id: str
    status: str
    message: str

class StrategyResultResponse(BaseModel):
    job_id: str
    status: str
    compile_success: Optional[str] = None
    compile_log: Optional[str] = None
    backtest_result: Optional[str] = None
    script_content: Optional[str] = None
    prompt: Optional[str] = None

class AuthResponse(BaseModel):
    token: str
    username: str

class UserProfileResponse(BaseModel):
    id: str
    username: str
    email: str
