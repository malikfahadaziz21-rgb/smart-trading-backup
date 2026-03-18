import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    GITHUB_TOKEN = os.getenv("GITHUB_TOKEN", "")
    GITHUB_REPO_OWNER = os.getenv("GITHUB_REPO_OWNER", "")
    GITHUB_REPO_NAME = os.getenv("GITHUB_REPO_NAME", "")
    GITHUB_WORKFLOW_FILE = os.getenv("GITHUB_WORKFLOW_FILE", "compile.yml")
    
    GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
    
    DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./smarttrade.db")
    REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    
    SECRET_KEY = os.getenv("SECRET_KEY", "secret")
    DEBUG = os.getenv("DEBUG", "False").lower() == "true"

settings = Config()
