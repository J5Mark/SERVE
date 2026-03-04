import os
import logging

logging.basicConfig(level=logging.DEBUG)
from fastapi import Depends, HTTPException, APIRouter
from auth import auth, get_user_id_from_token
from authx import TokenPayload
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from schemas import (
    CreateBusinessRequest,
    EditBusinessRequest,
    VerifyBusinessRequest,
    BusinessResponse,
)
from typing import Optional
from uuid import uuid4
from utils import *
from ranking import fetch_useful_businessmen
from postgres_conn import User, UserAuth, get_db, Community, Post

router = APIRouter(prefix="/business", tags=["businesses"])


@router.post("/create")
async def create_business_ep(
    req: CreateBusinessRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()  # Will later have to abstract it to use cache

    if user.entrep:
        await create_business(req, user_id, db)
        await db.commit()
        return {"business": "created"}
    else:
        raise HTTPException(status_code=401, detail="Forbidden")


@router.delete("/{business_id}")
async def delete_business_ep(
    business_id: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    await delete_business(business_id, user_id, db)
    await db.commit()
    return {"business": "deleted"}


@router.post("/edit/{business_id}")
async def edit_business_ep(
    business_id: int,
    req: EditBusinessRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    await edit_business(req, user_id, business_id, db)
    await db.commit()
    return {"business": "edited"}


@router.get("/{business_id}", response_model=BusinessResponse)
async def get_business_ep(
    business_id: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    business = await get_business(business_id, user_id, db)
    verifications_count = {}
    for v in business.verifications:
        verifications_count[v.type] = verifications_count.get(v.type, 0) + 1
    return BusinessResponse(
        id=business.id,
        name=business.name,
        bio=business.bio,
        user_id=business.user_id,
        created_at=business.created_at,
        community_ids=[c.id for c in business.communities],
        verifications=verifications_count,
    )


@router.get("/newcomers/{n}")
async def get_newcomers_ep(
    n: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    communities_ids = await get_user_communities_ids(user_id, db)
    logging.warning(f"Communities ids: {communities_ids}")
    # something's wrong here
    if not communities_ids:
        newcomers = await get_newcomers_overall(int(n), db)
        return newcomers

    newcomers = await get_newcomers(int(n), communities_ids, db)
    return newcomers


@router.post("/verify")
async def veryfy_business_ep(
    req: VerifyBusinessRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    await verify_business(req, user_id, db)
    await db.commit()
    return {"business": "verified"}


@router.post('/get_contacts')
async def get_contacts(
    req: GetContactsRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    contacts = await fetch_useful_businessmen(
        req.n            ,
        user_id          ,
        req.community_id ,
        req.post_id      ,
        db               ,
    )

    return contacts


@router.post('/connect')
async def connect_ep(
    req: ConnectRequest,
    db: AsyncSession = Depends(get_db),
    requester_id: int = Depends(get_user_id_from_token),
):
    await connect(requester_id, req.contact_ids, db)
    await db.commit()

    return {'connections': 'created'}
