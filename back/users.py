import os
import logging

logging.basicConfig(level=logging.DEBUG)
from fastapi import Depends, HTTPException, APIRouter
from auth import auth
from authx import TokenPayload
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from schemas import *
from typing import Optional
from uuid import uuid4
from utils import *
from postgres_conn import User, UserAuth, get_db

router = APIRouter(prefix='/users', tags=['users'])

@router.post('/register')
async def register(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    await register_user(req, db)
    await db.commit()
    return {'status': 'ok'}


@router.get('/{device_id}')
async def get_user(
    device_id: str,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
) -> User:
    result = await db.execute(select(User)
                              .options(selectinload(User.communities))
                              .where(User.device_id == device_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
