import os
import logging
from fastapi import Depends, HTTPException, APIRouter
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from authx import AuthX, AuthXConfig
from pwdlib import PasswordHash
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import Optional
from uuid import uuid4
from datetime import datetime, timezone
from schemas import *
from postgres_conn import User, UserAuth, get_db


JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "qwertyuiop")
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET", "")
GOOGLE_REDIRECT_URI = os.getenv("GOOGLE_REDIRECT_URI", "")

config = AuthXConfig(
    JWT_SECRET_KEY=JWT_SECRET_KEY,
    JWT_TOKEN_LOCATION=["headers"],
    JWT_ALGORITHM="HS256",
    JWT_ACCESS_TOKEN_EXPIRES=60 * 15,
    JWT_REFRESH_TOKEN_EXPIRES=60 * 60 * 24 * 7,
)

auth = AuthX(config=config)

password_hasher = PasswordHash.recommended()

router = APIRouter(prefix="/auth", tags=["auth"])
security = HTTPBearer(auto_error=False)


def hash_password(password: str) -> str:
    hash = password_hasher.hash(password)
    logging.warning(hash)
    return hash


def verify_password(password: str, hashed_password: str) -> bool:
    return password_hasher.verify(password, hashed_password)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str


# async def get_current_user(
#     credentials: HTTPAuthorizationCredentials = Depends(security),
#     db: AsyncSession = Depends(get_db),
# ) -> User:
#     token = credentials.credentials
#     try:
#         payload = auth.token_decode(token)
#         user_id = payload.get("sub")
#         if not user_id:
#             raise HTTPException(status_code=401, detail="Invalid token")

#         result = await db.execute(select(User).where(User.id == int(user_id)))
#         user = result.scalars().first()

#         if not user:
#             raise HTTPException(status_code=401, detail="User not found")

#         return user
#     except Exception as e:
#         logging.error(f"Token validation error: {e}")
#         raise HTTPException(status_code=401, detail="Invalid or expired token")


def create_tokens(user_id: int | None, device_id: str) -> dict[str, str]:
    now = datetime.now(timezone.utc)

    common_claims = {
        "uid": user_id,
        "device_id": device_id,
        "iat": now,
    }

    access_token = auth.create_access_token(
        uid=device_id,
        # data=common_claims,
    )

    refresh_token = auth.create_refresh_token(
        uid=device_id,
        # data=common_claims,
    )

    return (
        access_token,
        refresh_token,
    )


def validate_refresh() -> bool:
    pass


def revoke_old_refresh() -> None:
    pass


@router.post("/devicelogin")
async def device_login(req: DeviceLoginRequest, db: AsyncSession = Depends(get_db)):
    # check if exists in auth users
    # if doesn't exist, create a record
    # then create access and refresh tokens
    result = await db.execute(select(User).where(User.device_id == req.device_id))
    ex_user = result.scalars().first()
    if not ex_user:
        # create record
        try:
            ex_user = User(device_id=req.device_id)
            db.add(ex_user)
            # probably set up a cronjob later that would delete 'empty' UserAuth-s
            await db.commit()

        except Exception as e:
            logging.error(f"Could not record new auth:\n\n{e}")
            raise HTTPException(status_code=500, detail=f"Error: {e}")

    # create tokens
    access, refresh = create_tokens(user_id=ex_user.id, device_id=ex_user.device_id)
    logging.debug(access)

    return {
        "access_token": access,
        "refresh_token": refresh,
    }


@router.post("/login", response_model=TokenResponse)
async def login(req: AuthRequest, db: AsyncSession = Depends(get_db)):
    query_conditions = []
    if req.username:
        query_conditions.append(UserAuth.username == req.username)
    if req.email:
        query_conditions.append(UserAuth.email == req.email)
    if req.phone:
        query_conditions.append(UserAuth.phone == str(req.phone))

    query_conditions.append(UserAuth.device_id == req.device_id)
    
    if not query_conditions:
        raise HTTPException(
            status_code=400, detail="Username, email, or phone required"
        )

    result = await db.execute(select(UserAuth).where(*query_conditions))
    user_auth = result.scalars().first()

    if not user_auth or not verify_password(req.password, user_auth.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    result = await db.execute(select(User).where(User.id == user_auth.user_id))
    user = result.scalars().first()

    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")

    access_token = auth.create_access_token(uid=str(user.id))
    refresh_token = auth.create_refresh_token(uid=str(user.id))

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(req: RefreshRequest):
    try:
        payload = auth.token_decode(req.refresh_token)
        user_id = payload.get("sub")

        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid refresh token")

        access_token = auth.create_access_token(uid=user_id)
        refresh_token = auth.create_refresh_token(uid=user_id)

        return TokenResponse(access_token=access_token, refresh_token=refresh_token)
    except Exception as e:
        logging.error(f"Refresh token error: {e}")
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")
