from pydantic import BaseModel

class StrategyRequest(BaseModel):
    prompt: str
