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
    pass


@router.get('/{post_id}')
async def get_post_ep(
    post_id: int,
    db: AsyncSession = Depends(get_db),
):
    pass


@router.delete('/{post_id}')
async def delete_post_ep(
    post_id: int,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    pass


@router.post('/edit/{post_id}')
async def edit_post_ep(
    post_id: int,
    req: EditPostRequest,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    pass
