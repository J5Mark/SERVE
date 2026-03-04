import os
import logging

logging.basicConfig(level=logging.DEBUG)
from fastapi import Depends, HTTPException, APIRouter
from auth import auth, get_user_id_from_token
from authx import TokenPayload
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from schemas import *
from typing import Optional
from uuid import uuid4
from utils import *
from postgres_conn import User, UserAuth, get_db, Community, Post

router = APIRouter(prefix='/post', tags=['posts'])

@router.post('/c')
async def create_post_ep(
    req: CreatePostRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    await create_post(req, user_id, db)
    await db.commit()

    return {'post': 'created'}


@router.get('/g/{post_id}')
async def get_post_ep(
    post_id: int,
    db: AsyncSession = Depends(get_db),
):
    post = await get_post(post_id, db)
    return post


@router.delete('/d/{post_id}')
async def delete_post_ep(
    post_id: int,
    db: AsyncSession = Depends(get_db),
):
    await delete_post(post_id, db)
    await db.commit()
    
    return {'post': 'deleted'}


@router.post('/edit')
async def edit_post_ep(
    req: EditPostRequest,
    db: AsyncSession = Depends(get_db),
):
    await edit_post(req, db)
    await db.commit()

    return {'post': 'edited'}


@router.post('/vote')
async def vote_on_post_ep(
    req: VoteOnPostRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    await vote_on_post(req, user_id, db)
    await db.commit()

    return {'vote': 'put'}
    

@router.get('/list_popular/{n}/{offset}')
async def list_posts(
    n: int,
    offset: int,
    db: AsyncSession = Depends(get_db)
):
    posts = await fetch_popular_posts(n, offset, db)
    return posts


@router.get('/list/{n}/{offset}')
async def list_posts_for_user(
    n: int,
    offset: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    posts = await fetch_n_posts_for_user(user_id, n, offset, db)
    return posts


@router.post('/search')
async def search_posts_ep(
    req: SearchPostRequest,
    db: AsyncSession = Depends(get_db),
):
    found_posts = await search_posts(req.query, req.n, db)
    return found_posts
