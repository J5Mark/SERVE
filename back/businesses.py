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

router = APIRouter(prefix='/business', tags=['businesses'])


@router.post('/create')
async def create_business_ep(
    req: CreateBusinessRequest,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    user_id = int(payload.sub)
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first() # Will later have to abstract it to use cache

    if user.entrep:
        await create_business(req, user_id, db)
        await db.commit()
        return {'business': 'created'}
    else:
        raise HTTPException(status_code=401, detail='Forbidden')

@router.delete('/{business_id}')
async def delete_business_ep(
    business_id: int,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    user_id = int(payload.sub)
    await delete_business(business_id, user_id, db)
    await db.commit()
    return {'business': 'deleted'}


@router.post('/edit/{business_id}')
async def edit_business_ep(
    business_id: int,
    req: EditBusinessRequest,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    user_id = int(payload.sub)
    await edit_business(req, user_id, business_id, db)
    await db.commit()
    return {'business': 'edited'}


@router.get('/{business_id}')
async def get_business_ep(
    business_id: int,
    db: AsyncSession = Depends(get_db),
    payload: TokenPayload = Depends(auth.access_token_required)
):
    user_id = int(payload.sub)
    business = await get_business(business_id, user_id, db)
    return business
