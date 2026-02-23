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
from postgres_conn import User, UserAuth, get_db, Community

router = APIRouter(prefix='/comm', tags=['communities'])


async def check_reddit_community(name: str) -> bool:
    pass


@router.post('/create')
async def create_community_ep(
    req: CreateCommunityRequest,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    # if req.reddit_link:
    #     reddit_exists = await check_reddit_community(req.reddit_link)
    #     if not reddit_exists:
    #         raise HTTPException(status_code=404, detail=f'Community {req.reddit_link} does not exist on reddit')
    
    await create_community(req, payload.sub, db)
    await db.commit()

    return {'community created': f'{req.name}'}


@router.delete('/del/{community_id}')
async def delete_community_ep(
    community_id: int,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    user_id = int(payload.sub)
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()

    if user.admin:
        await delete_community(community_id, db)
        await db.commit()
    else:
        raise HTTPException(status_code=401, detail='Forbidden')

    return {'community': 'deleted'}
