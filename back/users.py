import os
import logging
import secrets
import string

logging.basicConfig(level=logging.DEBUG)
from fastapi import Depends, HTTPException, APIRouter
from auth import auth, create_user_tokens, get_user_id_from_token, get_anonymous_id_from_token, hash_password
from authx import TokenPayload
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from schemas import *
from typing import Optional
from uuid import uuid4
from utils import *
from postgres_conn import User, UserAuth, get_db

router = APIRouter(prefix='/api/users', tags=['users'])


def generate_username() -> str:
    """Generate a random username like user_ik384fnds"""
    alphabet = string.ascii_lowercase + string.digits
    random_part = ''.join(secrets.choice(alphabet) for _ in range(8))
    return f"user_{random_part}"


@router.post('/register')
async def register(
    req: RegisterRequest,
    db: AsyncSession = Depends(get_db),
):
    """Registration - creates a user profile"""
    # Check if user already exists by email
    if req.email:
        result = await db.execute(select(User).where(User.email == req.email))
        existing_user = result.scalars().first()
        if existing_user:
            raise HTTPException(status_code=400, detail="User already exists with this email")
    
    # Also check if username exists
    username = req.username or generate_username()
    result = await db.execute(select(User).where(User.username == username))
    existing_by_username = result.scalars().first()
    if existing_by_username:
        username = generate_username()
    
    user = User(
        username   = username                 ,
        first_name = req.first_name or "User" ,
        last_name  = req.last_name            ,
        email      = req.email                ,
        entrep     = req.entrep               ,
    )
    db.add(user)
    await db.flush()
    
    password_hash = ""
    if req.password:
        from auth import hash_password
        password_hash = hash_password(req.password)
    
    user_auth = UserAuth(
        user_id=user.id,
        username=username,
        password_hash=password_hash,
        email=req.email,
    )
    db.add(user_auth)
    
    await db.commit()
    await db.refresh(user)
    
    access_token, refresh_token = create_user_tokens(user.id)
    
    return {
        'status': 'ok',
        'access_token': access_token,
        'refresh_token': refresh_token,
        'user_id': user.id,
    }


@router.get('/me', response_model=UserResponse)
async def get_current_user(
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    sub = payload.sub
    
    if sub.isdigit():
        user_id = int(sub)
        result = await db.execute(select(User)
                                  .options(
                                           selectinload(User.communities),
                                           selectinload(User.businesses),
                                           selectinload(User.posts),
                                       )
                                  .where(User.id == user_id))
    else:
        anonymous_id = sub
        result = await db.execute(select(UserAuth).where(UserAuth.anonymous_id == anonymous_id))
        user_auth = result.scalars().first()
        if not user_auth or not user_auth.user_id:
            raise HTTPException(status_code=404, detail="User not registered")
        
        result = await db.execute(select(User)
                                  .options(
                                           selectinload(User.communities),
                                           selectinload(User.businesses),
                                           selectinload(User.posts),
                                       )
                                  .where(User.id == user_auth.user_id))
    
    user = result.scalars().first()
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return UserResponse(
        id=user.id,
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
        businesses=[{'id': b.id, 'name': b.name} for b in user.businesses],
        posts=[{'id': p.id, 'name': p.name} for p in user.posts],
    )


@router.get('/{user_id}', response_model=UserResponse)
async def get_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
) -> UserResponse:
    result = await db.execute(select(User)
                              .options(selectinload(User.communities))
                              .where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return UserResponse(
        id=user.id,
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
        await moderate(db, req.username)
        user.username = req.username
    if req.first_name is not None:
        await moderate(db, req.first_name)
        user.first_name = req.first_name
    if req.last_name is not None:
        await moderate(db, req.last_name)
        user.last_name = req.last_name
    if req.phone_number is not None:
        user.phone_number = req.phone_number
    if req.entrep is not None:
        user.entrep = req.entrep
    
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


@router.delete('/me')
async def delete_user_ep(
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    await delete_user(db, user_id)
    await db.commit()

    return {'user': 'deleted'}
