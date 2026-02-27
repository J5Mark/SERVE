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
from postgres_conn import User, UserAuth, get_db, Community, Post

router = APIRouter(prefix='/post', tags=['posts'])

@router.post('/')
async def create_post_ep(
    req: CreatePostRequest,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    user_id = int(payload.sub)
    await create_post(req, user_id, db)
    await db.commit()

    return {'post': 'created'}


@router.get('/{post_id}')
async def get_post_ep(
    post_id: int,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    post = await get_post(post_id, db)
    return post


@router.delete('/{post_id}')
async def delete_post_ep(
    post_id: int,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    await delete_post(post_id, db)
    await db.commit()
    
    return {'post': 'deleted'}


@router.post('/edit')
async def edit_post_ep(
    req: EditPostRequest,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    await edit_post(req, db)
    await db.commit()

    return {'post': 'edited'}


@router.post('/vote')
async def vote_on_post_ep(
    req: VoteOnPostRequest,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    user_id = int(payload.sub)
    await vote_on_post(req, user_id, db)
    await db.commit()

    return {'vote': 'put'}
    

@router.get('/list')
async def list_posts(
    n: int,
    offset: int,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    pass
