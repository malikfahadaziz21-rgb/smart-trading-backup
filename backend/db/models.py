from sqlalchemy import Column, String, Text, DateTime, Enum
import uuid
from datetime import datetime
import enum

from backend.db.database import Base

class JobStatus(enum.Enum):
    PENDING = "pending"
    GENERATING = "generating"
    COMPILING = "compiling"
    BACKTESTING = "backtesting"
    COMPLETED = "completed"
    FAILED = "failed"

class Job(Base):
    __tablename__ = "jobs"

    id              = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_prompt     = Column(Text, nullable=False)       # original user input
    script_name     = Column(String(255), nullable=False) # e.g. strategy_abc123.mq5
    script_content  = Column(Text, nullable=True)        # generated MQL5 code
    compile_log     = Column(Text, nullable=True)        # MetaEditor output
    compile_success = Column(String(10), nullable=True)  # "yes" or "no"
    backtest_result = Column(Text, nullable=True)        # JSON string of metrics
    status          = Column(Enum(JobStatus), default=JobStatus.PENDING)
    github_run_id   = Column(String(50), nullable=True)  # for polling
    created_at      = Column(DateTime, default=datetime.utcnow)
    updated_at      = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    error_message   = Column(Text, nullable=True)
