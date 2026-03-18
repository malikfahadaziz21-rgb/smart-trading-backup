from fastapi import FastAPI
from backend.api.routes import strategy, results
from backend.db.database import engine, Base

# Create tables if they don't exist
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Smart Trade Automation API",
    description="API for converting English prompts to backtested MQL5 expert advisors",
    version="1.0.0"
)

app.include_router(strategy.router)
app.include_router(results.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to Smart Trade Automation Platform"}
