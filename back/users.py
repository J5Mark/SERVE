import os
import logging

logging.basicConfig(level=logging.DEBUG)
from fastapi import Depends, HTTPException, APIRouter
from auth import auth, create_user_tokens, get_user_id_from_token
from authx import TokenPayload
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
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
    
    # Get the user to create new tokens with user_id
    result = await db.execute(select(User).where(User.device_id == req.device_id))
    user = result.scalars().first()
    
    # Issue NEW tokens with user_id (authenticated tokens)
    access_token, refresh_token = create_user_tokens(user.id)
    
    return {
        'status': 'ok',
        'access_token': access_token,
        'refresh_token': refresh_token,
    }


@router.get('/me', response_model=UserResponse)
async def get_current_user(
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    sub = payload.sub
    
    # Check if token contains user_id (authenticated) or device_id (anonymous)
    if sub.isdigit():
        # Authenticated token - contains user_id
        user_id = int(sub)
        result = await db.execute(select(User)
                                  .options(selectinload(User.communities))
                                  .where(User.id == user_id))
    else:
        # Anonymous token - contains device_id
        device_id = sub
        result = await db.execute(select(User)
                                  .options(selectinload(User.communities))
                                  .where(User.device_id == device_id))
    
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return UserResponse(
        id=user.id,
        device_id=user.device_id,
        username=user.username,
        first_name=user.first_name,
        last_name=user.last_name,
        phone_number=user.phone_number,
        email=user.email,
        admin=user.admin,
        balance=user.balance,
        entrep=user.entrep,
        suspended=user.suspended,
        created_at=user.created_at,
        communities=[{'id': c.id, 'name': c.name} for c in user.communities],
    )


@router.get('/{device_id}', response_model=UserResponse)
async def get_user(
    device_id: str,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
) -> UserResponse:
    result = await db.execute(select(User)
                              .options(selectinload(User.communities))
                              .where(User.device_id == device_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return UserResponse(
        id=user.id,
        device_id=user.device_id,
        username=user.username,
        first_name=user.first_name,
        last_name=user.last_name,
        phone_number=user.phone_number,
        email=user.email,
        admin=user.admin,
        balance=user.balance,
        entrep=user.entrep,
        suspended=user.suspended,
        created_at=user.created_at,
        communities=[{'id': c.id, 'name': c.name} for c in user.communities],
    )


@router.patch('/{user_id}', response_model=UserResponse)
async def update_user(
    user_id: int,
    req: UpdateUserRequest,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if req.username is not None:
        user.username = req.username
    if req.first_name is not None:
        user.first_name = req.first_name
    if req.last_name is not None:
        user.last_name = req.last_name
    if req.phone_number is not None:
        user.phone_number = req.phone_number
    if req.email is not None:
        user.email = req.email
    
    await db.commit()
    await db.refresh(user)
    
    result = await db.execute(
        select(User)
        .options(selectinload(User.communities))
        .where(User.id == user_id)
    )
    user = result.scalars().first()
    
    return UserResponse(
        id=user.id,
        device_id=user.device_id,
        username=user.username,
        first_name=user.first_name,
        last_name=user.last_name,
        phone_number=user.phone_number,
        email=user.email,
        admin=user.admin,
        balance=user.balance,
        entrep=user.entrep,
        suspended=user.suspended,
        created_at=user.created_at,
        communities=[{'id': c.id, 'name': c.name} for c in user.communities],
    )
