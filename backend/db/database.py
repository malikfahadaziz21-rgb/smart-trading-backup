from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from backend.config import settings

# Neon PostgreSQL requires SSL; SQLite needs check_same_thread
db_url = settings.DATABASE_URL

# SQLite-specific threading workaround
if db_url.startswith("sqlite"):
    connect_args = {"check_same_thread": False}
else:
    connect_args = {}

engine = create_engine(db_url, connect_args=connect_args, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
