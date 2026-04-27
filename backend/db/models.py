from sqlalchemy import Column, String, Text, DateTime, Enum, ForeignKey, Boolean, Integer, Date
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import relationship
import uuid
from datetime import datetime, date
import enum

from backend.db.database import Base

class JobStatus(enum.Enum):
    PENDING = "pending"
    GENERATING = "generating"
    COMPILING = "compiling"
    BACKTESTING = "backtesting"
    COMPLETED = "completed"
    FAILED = "failed"

class User(Base):
    __tablename__ = "users"

    id                 = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username           = Column(String(50), unique=True, nullable=False, index=True)
    email              = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password    = Column(String(255), nullable=False)
    created_at         = Column(DateTime, default=datetime.utcnow)
    is_pro             = Column(Boolean, default=False)
    daily_used         = Column(Integer, default=0)
    last_used_date     = Column(Date, nullable=True)
    stripe_customer_id = Column(String(255), nullable=True)

    jobs = relationship("Job", back_populates="user", order_by="Job.created_at.desc()")

class Job(Base):
    __tablename__ = "jobs"

    id              = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id         = Column(PG_UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    user_prompt     = Column(Text, nullable=False)
    script_name     = Column(String(255), nullable=False)
    script_content  = Column(Text, nullable=True)
    compile_log     = Column(Text, nullable=True)
    compile_success = Column(String(10), nullable=True)
    backtest_result = Column(Text, nullable=True)
    status          = Column(Enum(JobStatus), default=JobStatus.PENDING)
    github_run_id   = Column(String(50), nullable=True)
    created_at      = Column(DateTime, default=datetime.utcnow)
    updated_at      = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    error_message   = Column(Text, nullable=True)

    user = relationship("User", back_populates="jobs")
