import os
import logging

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

router = APIRouter(prefix="/api/comm", tags=["communities"])


@router.post("/create")
async def create_community_ep(
    req: CreateCommunityRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    await moderate(db, req.description, req.name)

    await create_community(req, user_id, db)
    await db.commit()

    return {"community created": f"{req.name}"}


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

    resp = CommunityResponse(
        community_id=community_id,
        participants=len(community.participants),
        name=community.name,
        description=community.description,
        reddit_link=community.reddit_link,
        is_moderator=False,
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
):
    match req.sorting:
        case 'popular':
            communities = await list_popular_communities(req.n, req.offset, db)
            return communities

        case 'new':
            communities = await list_new_communities(req.n, req.offset, db)
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
