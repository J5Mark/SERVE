import os
import logging
import secrets
import string

logging.basicConfig(level=logging.DEBUG)
from fastapi import Depends, HTTPException, APIRouter
from auth import auth, create_user_tokens, get_user_id_from_token, hash_password
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


def generate_username() -> str:
    """Generate a random username like user_ik384fnds"""
    alphabet = string.ascii_lowercase + string.digits
    random_part = ''.join(secrets.choice(alphabet) for _ in range(8))
    return f"user_{random_part}"


@router.post('/register_simple')
async def register_simple(
    req: SimpleRegisterRequest,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    """Simple registration for anonymous users - creates a user profile"""
    sub = payload.sub
    
    # Must be anonymous token (device_id)
    if sub.isdigit():
        raise HTTPException(status_code=400, detail="Already registered")
    
    device_id = sub
    
    # Check if user already exists
    result = await db.execute(select(User).where(User.device_id == device_id))
    existing_user = result.scalars().first()
    
    if existing_user:
        raise HTTPException(status_code=400, detail="User already exists")
    
    # Generate username if not provided
    username = req.username or generate_username()
    
    # Create user
    user = User(
        device_id=device_id,
        username=username,
        first_name=req.first_name or "User",
        last_name=req.last_name,
        email=req.email,
    )
    db.add(user)
    await db.flush()
    
    # Create UserAuth
    password_hash = ""
    if req.password:
        from auth import hash_password
        password_hash = hash_password(req.password)
    
    user_auth = UserAuth(
        device_id=device_id,
        user_id=user.id,
        username=username,
        password_hash=password_hash,
        email=req.email,
    )
    db.add(user_auth)
    await db.commit()
    await db.refresh(user)
    
    # Create new authenticated tokens
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
    
    # Check if token contains user_id (authenticated) or device_id (anonymous)
    if sub.isdigit():
        # Authenticated token - contains user_id
        user_id = int(sub)
        result = await db.execute(select(User)
                                  .options(
                                           selectinload(User.communities),
                                           selectinload(User.businesses),
                                           selectinload(User.posts),
                                       )
                                  .where(User.id == user_id))
    else:
        # Anonymous token - contains device_id
        device_id = sub
        result = await db.execute(select(User)
                                  .options(
                                           selectinload(User.communities),
                                           selectinload(User.businesses),
                                           selectinload(User.posts),
                                       )
                                  .where(User.device_id == device_id))
    
    user = result.scalars().first()
    
    # No lazy user creation - return 404 if no user exists for anonymous device
    if not user and not sub.isdigit():
        raise HTTPException(status_code=404, detail="User not registered")
    
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
        businesses=[{'id': b.id, 'name': b.name} for b in user.businesses],
        posts=[{'id': p.id, 'name': p.name} for p in user.posts],
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


@router.delete('/me')
async def delete_user_ep(
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    await delete_user(db, user_id)
    await db.commit()

    return {'user': 'deleted'}
