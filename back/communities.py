import os
import logging

logging.basicConfig(level=logging.DEBUG)
from fastapi import Depends, HTTPException, APIRouter
from auth import auth, get_user_id_from_token
from authx import TokenPayload
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from schemas import *
from typing import Optional
from uuid import uuid4
from utils import *
from postgres_conn import User, UserAuth, get_db, Community

router = APIRouter(prefix="/comm", tags=["communities"])


async def check_reddit_community(name: str) -> bool:
    pass


@router.post("/create")
async def create_community_ep(
    req: CreateCommunityRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    # if req.reddit_link:
    #     reddit_exists = await check_reddit_community(req.reddit_link)
    #     if not reddit_exists:
    #         raise HTTPException(status_code=404, detail=f'Community {req.reddit_link} does not exist on reddit')

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
async def get_community_ep(community_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Community)
        .where(Community.id == community_id)
        .options(selectinload(Community.participants))
    )
    community = result.scalars().first()

    if not community:
        raise HTTPException(status_code=404, detail=f"Community not found")

    resp = CommunityResponse(
        community_id=community_id,
        participants=len(community.participants),
        name=community.name,
        description=community.description,
        reddit_link=community.reddit_link,
    )

    return resp


@router.post('/edit')
async def edit_community_ep(
    req: EditCommunityRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
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
    user_id: int = Depends(get_user_id_from_token)
):
    communities = []
    match req.sorting:
        case 'popular':
            pass

        case 'new':
            pass

        case 'relevant':
            pass # one of the latest to implement features honestly


@router.post('/search')
async def search_communities_ep(
    req: SearchCommunitiesRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    pass


@router.post('/join')
async def join_community_ep(
    req: JoinCommunityRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    await join_community(req, db, user_id)
    await db.commit()

    return {'community': 'joined'}
