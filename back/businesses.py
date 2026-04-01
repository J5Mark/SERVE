import os
import logging
from fastapi import Depends, HTTPException, APIRouter, UploadFile, File
from fastapi.responses import StreamingResponse

logging.basicConfig(level=logging.DEBUG)
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
from vecutils import *
from ranking import fetch_useful_businessmen
from postgres_conn import User, UserAuth, get_db, Community, Post, Business
from minio_conn import (
    upload_business_avatar, fetch_business_avatar, delete_business_avatar,
)

router = APIRouter(prefix="/api/business", tags=["businesses"])


@router.post("/create")
async def create_business_ep(
    req: CreateBusinessRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()  # Will later have to abstract it to use cache

    if user.entrep:
        logging.warning(req)
        
        await moderate(db, req.name, req.bio, req.cont_goal)
        
        business = await create_business(req, user_id, db)
        await db.commit()
        await db.refresh(business)
        return {"business": "created", "business_id": business.id}
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
    await moderate(db, req.bio, req.cont_goal)
    
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
        cont_goal=business.cont_goal,
        reaction_time=business.reaction_time,
        image=business.image,
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
    else:
        newcomers = await get_newcomers(int(n), communities_ids, db)
    
    result = []
    for b in newcomers:
        verifications_count = {}
        for v in b.verifications:
            verifications_count[v.type] = verifications_count.get(v.type, 0) + 1
        result.append({
            'id': b.id,
            'name': b.name,
            'bio': b.bio,
            'verifications': verifications_count,
            'user_id': b.user_id,
            'reaction_time': b.reaction_time,
            'cont_goal': b.cont_goal,
        })
    return result


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


@router.post('/avatar')
async def upload_business_avatar_ep(
    business_id: int,
    image: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    result = await db.execute(select(Business).where(Business.id == business_id))
    business = result.scalars().first()
    if not business or business.user_id != user_id:
        raise HTTPException(status_code=403, detail="Cannot upload avatar for this business")
    
    image_bytes = await image.read()
    await upload_business_avatar(business_id, image_bytes, content_type=image.content_type)
    
    business.image = True
    await db.commit()
    
    return {"status": "uploaded", "business_id": business_id}


@router.get('/avatar/{business_id}')
async def get_business_avatar_ep(business_id: int):
    try:
        return await fetch_business_avatar(business_id)
    except Exception as e:
        logging.error(f"Error fetching business avatar: {e}")
        raise HTTPException(status_code=404, detail="Avatar not found")


@router.delete('/avatar/{business_id}')
async def delete_business_avatar_ep(
    business_id: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    result = await db.execute(select(Business).where(Business.id == business_id))
    business = result.scalars().first()
    if not business or business.user_id != user_id:
        raise HTTPException(status_code=403, detail="Cannot delete avatar for this business")
    
    await delete_business_avatar(business_id)
    business.image = False
    await db.commit()
    return {"status": "deleted"}
