from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import re

from backend.db.database import get_db
from backend.db.models import User
from backend.services.auth_service import (
    hash_password,
    verify_password,
    create_access_token,
    get_current_user,
)
from backend.api.models.request_models import RegisterRequest, LoginRequest
from backend.api.models.response_models import AuthResponse, UserProfileResponse

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])

def validate_password(password: str):
    """Enforce strong password: min 8 chars, 1 letter, 1 digit, 1 special character."""
    if len(password) < 8:
        raise HTTPException(status_code=400, detail="Password must be at least 8 characters long")
    if not re.search(r"[A-Za-z]", password):
        raise HTTPException(status_code=400, detail="Password must contain at least one letter")
    if not re.search(r"\d", password):
        raise HTTPException(status_code=400, detail="Password must contain at least one number")
    if not re.search(r"[!@#$%^&*()_+\-=\[\]{};':\"\\|,.<>\/?~`]", password):
        raise HTTPException(status_code=400, detail="Password must contain at least one special character")

@router.post("/register", response_model=AuthResponse)
async def register(request: RegisterRequest, db: Session = Depends(get_db)):
    # Validate password strength
    validate_password(request.password)

    # Check if username or email already exists
    if db.query(User).filter(User.username == request.username).first():
        raise HTTPException(status_code=400, detail="Username already taken")
    if db.query(User).filter(User.email == request.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    user = User(
        username=request.username,
        email=request.email,
        hashed_password=hash_password(request.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(data={"sub": str(user.id)})
    return {"token": token, "username": user.username}

@router.post("/login", response_model=AuthResponse)
async def login(request: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == request.username).first()
    if not user or not verify_password(request.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid username or password")

    token = create_access_token(data={"sub": str(user.id)})
    return {"token": token, "username": user.username}

@router.get("/me", response_model=UserProfileResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    return {
        "id": str(current_user.id),
        "username": current_user.username,
        "email": current_user.email,
    }
