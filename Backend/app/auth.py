from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/auth", tags=["Authentication"])

# TEMP USERS (Later connect DB)
fake_users_db = {
    "bhuvan@gmail.com": {
        "password": "Bhuvan@2001",
        "name": "Bhuvan"
    }
}

class LoginRequest(BaseModel):
    email: str
    password: str

@router.post("/login")
async def login(request: LoginRequest):
    user = fake_users_db.get(request.email)
    if not user or user["password"] != request.password:
        raise HTTPException(status_code=401, detail="Invalid Credentials")

    return {
        "message": "Login Successful",
        "name": user["name"],
        "email": request.email
}
