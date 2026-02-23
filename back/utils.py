from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import and_, delete
from sqlalchemy import select, func, update, desc
from sqlalchemy.orm import selectinload
from typing import List
from langdetect import detect

import logging
from schemas import *
from postgres_conn import *
from auth import hash_password

async def register_user(req: RegisterRequest, db: AsyncSession):
    try:
        result = await db.execute(select(User).where(User.device_id == req.device_id))
        user = result.scalars().first()

        if user:
           raise HTTPException(status_code=401, detail="User already exists")

        # create the user
        user = User(
            device_id    = req.device_id    ,
            username     = req.username     ,
            first_name   = req.first_name   ,
            last_name    = req.last_name    ,
            phone_number = req.phone_number ,
            email        = req.email        ,
            entrep       = req.entrep       ,
            admin        = req.admin        ,
        )
        db.add(user)
        await db.flush()
        
        # create user_auth
        logging.warning(req.password)
        user_auth = UserAuth(
            device_id     = user.device_id              ,
            user_id       = user.id                     ,
            username      = user.username               ,
            password_hash = hash_password(req.password) ,
            email         = user.email                  ,
            phone         = user.phone_number           ,
        )
        db.add(user_auth)        
       
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to register user: {e}")


async def create_community(req: CreateCommunityRequest, user_id: int, db: AsyncSession):
    try:
        result = await db.execute(select(Community).where(Community.name == req.name))
        ex_community = result.scalars().first()
    
        if ex_community:
            raise HTTPException(status_code=401, detail='Community already exists')
    
        user_id = int(user_id)
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalars().first()

        mod = Moderator(
            user_id = user.id,
        )
    
        community = Community(
            name         = req.name        ,
            description  = req.description ,
            reddit_link  = req.reddit_link ,
            creator_id   = user_id         ,
            slug         = req.slug        ,
            mods         = [mod]           ,
            participants = [user]          ,
        )
        db.add(community)
        await db.flush()

        mod.moderates = community

    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Failed to create a community: {e}')


async def delete_community(community_id: int, db: AsyncSession):
    try:
        result = await db.execute(select(Community).where(Community.id == community_id))
        comm = result.scalars().first()

        if not comm:
            raise HTTPException(status_code=404, detail=f'Community not found')

        await db.delete(comm)

    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Failed to delete a community: {e}')


async def create_business(req: CreateBusinessRequest, user_id: int, db: AsyncSession):
    try:
        result = db.execute(select(Business).where(Business.user_id == user_id))
        ex_business = result.scalars().all()
        if len(ex_business) > 5:
            raise HTTPException(status_code=401, detail='Too many businesses')
        
        communities = []
        for c in req.community_ids:
            result = db.execute(select(Community).where(Community.id == c))
            communities.append(result.scalars().first())
        
        business = Business(
            name          = req.name    ,
            bio           = req.bio     ,
            communities   = communities ,
            user_id       = user_id     ,
            verifications = []          ,
        )

        db.add(business)
        
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Failed to create business: {e}')


async def delete_business(business_id: int, user_id: int, db: AsyncSession):
    try:
        result = await db.execute(select(Business).where(
                                      Business.id      == business_id,
                                      Business.user_id == user_id,
                                  ))
        business = result.scalars().first()

        if not business:
            raise HTTPException(status_code=404, detail=f'Business not found')

        await db.delete(business)
        
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Could not delete business: {e}')


async def edit_business(req: EditBusinessRequest, user_id: int, db: AsyncSession):
    try:
        result = await db.execute(select(Business).where(
                                        Business.id == req.business_id,
                                        Business.user_id == user_id
                                    ).options(
                                      selectinload(Business.communities)
                                  ))
        business = result.scalars().first()

        if not business:
            raise HTTPException(status_code=404, detail=f'Business not found')

        if req.bio is not None:
            business.bio = req.bio 

        if req.community_ids:
            communities = []

            for c in req.community_ids:
                result = db.execute(select(Community).where(Community.id == c))
                communities.append(result.scalars().first())
            
            business.communities = communities
        
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Could not edit business: {e}')


async def get_business(business_id: int, user_id: int, db: AsyncSession):
    try:
        result = await db.execute(select(Business).where(
                                      Business.id      == business_id,
                                      Business.User_id == user_id,
                                  ).options(
                                      selectinload(
                                          Business.communities,
                                          Business.verifications,
                                      )
                                  ))
        business = result.scalars().first()

        if not business:
            raise HTTPException(status_code=404, detail=f'Business not found')

        return business
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not get business')
