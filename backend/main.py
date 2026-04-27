from fastapi import FastAPI
from backend.api.routes import strategy, results, auth, billing
from backend.db.database import engine, Base

from fastapi.middleware.cors import CORSMiddleware

# Create tables if they don't exist
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Smart Trade Automation API",
    description="API for converting English prompts to backtested MQL5 expert advisors",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(strategy.router)
app.include_router(results.router)
app.include_router(billing.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to Smart Trade Automation Platform"}
