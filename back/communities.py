import os
import logging
import aiohttp
from fastapi import Depends, HTTPException, APIRouter, UploadFile, File
from fastapi.responses import StreamingResponse

logging.basicConfig(level=logging.DEBUG)
from fastapi import Depends, HTTPException, APIRouter
from auth import auth, get_user_id_from_token
from authx import TokenPayload
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload, defer
from schemas import *
from typing import Optional
from uuid import uuid4
from utils import *
from postgres_conn import User, UserAuth, get_db, Community
from minio_conn import (
    upload_community_avatar, fetch_community_avatar, delete_community_avatar,
)

router = APIRouter(prefix="/api/comm", tags=["communities"])


INTEGRATIONS_BASE = os.getenv('INTEGRATIONS_BASE', 'http://integrations:3000')


@router.post("/create")
async def create_community_ep(
    req: CreateCommunityRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    await moderate(db, req.description, req.name)

    community = await create_community(req, user_id, db)
    await db.commit()
    await db.refresh(community)

    return {"community created": f"{req.name}", "community_id": community.id}


@router.delete("/del/{community_id}")
async def delete_community_ep(
    community_id: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()

    if user.admin:
        await delete_community(community_id, db)
        await db.commit()
    else:
        raise HTTPException(status_code=401, detail="Forbidden")

    return {"community": "deleted"}


@router.get("/{community_id}", response_model=CommunityResponse)
async def get_community_ep(
    community_id: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    result = await db.execute(
        select(Community)
        .where(Community.id == community_id)
        .options(
            selectinload(Community.participants),
            selectinload(Community.mods),
            defer(Community.embedding),
        )
    )
    community = result.scalars().first()

    if not community:
        raise HTTPException(status_code=404, detail=f"Community not found")

    mod_ids = [mod.user_id for mod in community.mods]
    participant_ids = [p.id for p in community.participants]
    
    is_moderator = user_id in mod_ids
    is_member = user_id in participant_ids

    reddit_subscribers = None
    reddit_description = None
    
    if community.reddit_link:
        reddit_name = community.reddit_link.replace('reddit.com/', '').replace('/r/', '').replace('r/', '').strip()
        if reddit_name:
            try:
                async with aiohttp.ClientSession(base_url=INTEGRATIONS_BASE) as client:
                    async with client.get(f'/get-subreddit-participants/{reddit_name}') as resp:
                        if resp.status == 200:
                            data = await resp.json()
                            reddit_subscribers = int(data.get('subscribers', 0))
                    async with client.get(f'/reddit/get-description/{reddit_name}') as resp:
                        if resp.status == 200:
                            data = await resp.json()
                            reddit_description = data.get('description')
            except Exception as e:
                logging.warning(f"Failed to fetch reddit data for {reddit_name}: {e}")

    resp = CommunityResponse(
        community_id=community_id,
        participants=len(community.participants),
        name=community.name,
        description=community.description,
        reddit_link=community.reddit_link,
        reddit_subscribers=reddit_subscribers,
        reddit_description=reddit_description,
        is_moderator=is_moderator,
        is_member=is_member,
        mods=mod_ids,
    )

    return resp


@router.post('/edit')
async def edit_community_ep(
    req: EditCommunityRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    await moderate(db, req.description)
    
    edit_community(req, db, user_id)
    await db.commit()
    return {'community': 'edited'}


@router.post('/change_moderators')
async def change_moderators_ep(
    req: ChangeModeratorsRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    change_moderators(req, db, user_id)
    await db.commit()
    return {'moderators': 'changed'}


@router.post('/list_communities')
async def list_communities_ep(
    req: ListCommunitiesRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    match req.sorting:
        case 'popular':
            communities = await list_popular_communities(req.n, req.offset, db, user_id)
            return communities

        case 'new':
            communities = await list_new_communities(req.n, req.offset, db, user_id)
            return communities

        case 'relevant':
            raise HTTPException(status_code=404, detail='Not implemented')
            # one of the latest to implement features honestly

        case _:
            raise HTTPException(status_code=404, detail='Sorting does not exist')

@router.post('/search')
async def search_communities_ep(
    req: SearchCommunitiesRequest,
    db: AsyncSession = Depends(get_db),
):
    communities = await search_communities(req.query, req.n, db, None)
    return communities


@router.post('/join')
async def join_community_ep(
    req: JoinCommunityRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    await join_community(req, db, user_id)
    await db.commit()

    return {'community': 'joined'}


@router.post('/leave')
async def leave_community_ep(
    req: LeaveCommunityRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    await leave_community(req, db, user_id)
    await db.commit()

    return {'community': 'out'}


@router.post('/avatar')
async def upload_community_avatar_ep(
    community_id: int,
    image: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    result = await db.execute(select(Community).where(Community.id == community_id))
    community = result.scalars().first()
    if not community:
        raise HTTPException(status_code=404, detail="Community not found")
    
    mod_ids = [mod.user_id for mod in community.mods]
    if user_id not in mod_ids:
        raise HTTPException(status_code=403, detail="Only moderators can upload avatar")
    
    image_bytes = await image.read()
    await upload_community_avatar(community_id, image_bytes)
    
    community.image = True
    await db.commit()
    
    return {"status": "uploaded", "community_id": community_id}


@router.get('/avatar/{community_id}')
async def get_community_avatar_ep(community_id: int):
    try:
        return await fetch_community_avatar(community_id)
    except Exception as e:
        logging.error(f"Error fetching community avatar: {e}")
        raise HTTPException(status_code=404, detail="Avatar not found")


@router.delete('/avatar/{community_id}')
async def delete_community_avatar_ep(
    community_id: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    result = await db.execute(select(Community).where(Community.id == community_id))
    community = result.scalars().first()
    if not community:
        raise HTTPException(status_code=404, detail="Community not found")
    
    mod_ids = [mod.user_id for mod in community.mods]
    if user_id not in mod_ids:
        raise HTTPException(status_code=403, detail="Only moderators can delete avatar")
    
    await delete_community_avatar(community_id)
    community.image = False
    await db.commit()
    return {"status": "deleted"}
