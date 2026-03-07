from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import and_, delete
from sqlalchemy import select, func, update, desc, asc
from sqlalchemy.orm import selectinload
from typing import List
from langdetect import detect
import numpy as np

import logging
from schemas import *
from postgres_conn import *
from auth import hash_password


LANG_MAP = {
    "en": "english",
    "ru": "russian",
    "nl": "dutch",
}

def detect_language(name: str, contents: str) -> str:
    try:
        code = detect(f"{name} {contents}")
    except Exception:
        return "english"

    return LANG_MAP.get(code, "english")

async def register_user(req: RegisterRequest, db: AsyncSession):
    try:
        result = await db.execute(select(UserAuth).where(UserAuth.device_id == req.device_id))
        user_auth = result.scalars().first()

        if user_auth:
           raise HTTPException(status_code=401, detail="User already exists")

        result = await db.execute(select(User).where(User.device_id == req.device_id))
        user = result.scalars().first()

        # create the user if it doesn't exist (from deviceLogin)
        if not user:
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
        else:
            # Update existing user with registration details
            user.username = req.username
            user.first_name = req.first_name
            user.last_name = req.last_name
            user.phone_number = req.phone_number
            user.email = req.email
            user.entrep = req.entrep
            user.admin = req.admin
        
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
       
    except HTTPException:
        raise
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

    except HTTPException:
        raise
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

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Failed to delete a community: {e}')


async def create_business(req: CreateBusinessRequest, user_id: int, db: AsyncSession):
    try:
        result = await db.execute(select(Business).where(Business.user_id == user_id))
        ex_business = result.scalars().all()
        if len(ex_business) > 5:
            raise HTTPException(status_code=401, detail='Too many businesses')
        
        communities = []
        for c in req.community_ids:
            result = await db.execute(select(Community).where(Community.id == c))
            communities.append(result.scalars().first())
        
        business = Business(
            name          = req.name    ,
            bio           = req.bio     ,
            communities   = communities ,
            user_id       = user_id     ,
            verifications = []          ,
        )

        db.add(business)
        
    except HTTPException:
        raise
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
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Could not delete business: {e}')


async def edit_business(req: EditBusinessRequest, user_id: int, business_id: int, db: AsyncSession):
    try:
        result = await db.execute(select(Business).where(
                                        Business.id == business_id,
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
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Could not edit business: {e}')


async def get_business(business_id: int, user_id: int, db: AsyncSession):
    try:
        result = await db.execute(
            select(Business)
            .where(
                Business.id == business_id,
                Business.user_id == user_id,
            )
            .options(
                selectinload(Business.communities),
                selectinload(Business.verifications),
            )
        )
        
        business = result.scalars().first()
        if not business:
            raise HTTPException(status_code=404, detail=f'Business not found')

        return business
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not get business: {e}')


async def get_user_communities_ids(user_id: int, db: AsyncSession):
    try:
        result = await db.execute(
            select(ParticipantsLink.community_id)
            .where(
                ParticipantsLink.user_id == user_id
            )
        )
        communities_ids = result.scalars().all()
        return communities_ids
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not get communities ids: {e}')


async def get_newcomers_overall(n: int, db: AsyncSession):
    try:
        result = await db.execute(
            select(Business)
            .options(
                selectinload(Business.communities)
            )
            .order_by(desc(Business.created_at))
            .limit(n)
        )
        businesses = result.scalars().all()        
        return businesses
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not get overall newcomers: {e}')


async def get_newcomers(n: int, communities_ids: List[int], db: AsyncSession):
    try:
        result = await db.execute(
            select(BusinessOperationsLink.business_id)
            .where(BusinessOperationsLink.community_id.in_(communities_ids))
        )
        business_ids = result.scalars().all()

        result = await db.execute(
            select(Business)
            .where(Business.id.in_(business_ids))
            .options(
                selectinload(Business.communities)
            )
            .order_by(desc(Business.created_at))
            .limit(n)
        )
        businesses = result.scalars().all()
        return businesses
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not get newcomers: {e}')


async def verify_business(
    req: VerifyBusinessRequest,
    user_id: int,
    db: AsyncSession
):
    try:
        result = await db.execute(
            select(Business)
            .where(Business.id == req.business_id)
        )
        business = result.scalars().first()
        if not business:
            raise HTTPException(status_code=404, detail='Business does not exist')
        
        verification = Verification(
            user_id     = user_id         ,
            business_id = req.business_id ,
            type        = req.type        ,
        )

        db.add(verification)

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Could not put verification on business: {e}')


async def create_post(req: CreatePostRequest, user_id: int, db: AsyncSession):
    try:
        result = await db.execute(
            select(Community)
            .where(Community.id == req.community_id)
        )
        community = result.scalars().first()
        if not community:
            raise HTTPException(status_code=404, detail='Community not found')
        
        post = Post(
            name         = req.name         ,
            contents     = req.contents     ,
            community_id = req.community_id ,
            user_id      = user_id          ,
            language     = detect_language(req.name, req.contents)
        )
        db.add(post)
        await db.flush()
        
        vote = Vote(
            post_id  = post.id ,
            voter_id = user_id ,
        )

        db.add(vote)

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Could not create post: {e}')


async def get_post(post_id: int, db: AsyncSession):
    try:
        result = await db.execute(
            select(Post)
            .where(Post.id == post_id)
            .options(
                selectinload(Post.votes),
                selectinload(Post.community)
            )
        )
        post = result.scalars().first()

        if not post:
            raise HTTPException(status_code=404, detail='Post not found')

        would = [v.would_pay for v in post.votes if v.would_pay is not None]
        stats = None
        if would:      
            stats = {
                'amount': len(post.votes),
                'mean': round(float(np.mean(would)), 2),
                'median': round(float(np.median(would)), 2),
                'min': min(would),
                'max': max(would)
            }

        votes_data = []
        for v in post.votes:
            vote_dict = {}
            if v.competition is not None:
                vote_dict['competition'] = v.competition
            if v.problems is not None:
                vote_dict['problems'] = v.problems
            if vote_dict:
                votes_data.append(vote_dict)

        return {'post': post, 'stats': stats, 'votes': votes_data}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not get post: {e}')



async def delete_post(post_id: int, db: AsyncSession):
    try:
        result = await db.execute(
            select(Post)
            .where(Post.id == post_id)
        )
        post = result.scalars().first()

        if not post:
            raise HTTPException(status_code=404, detail='Post not found')

        await db.delete(post)
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Could not delete post: {e}')


async def edit_post(req: EditPostRequest, db: AsyncSession):
    try:
        result = await db.execute(
            select(Post)
            .where(Post.id == req.post_id)
        )
        post = result.scalars().first()

        if not post:
            raise HTTPException(status_code=404, detail='Post not found')

        post.contents = req.contents

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Could not edit post: {e}')


async def vote_on_post(req: VoteOnPostRequest, user_id: int, db: AsyncSession):
    try:
        result = await db.execute(
            select(Post)
            .where(Post.id == req.post_id)
        )
        post = result.scalars().first()

        if not post:
            raise HTTPException(status_code=404, detail='Post not found')

        vote = Vote(
            post_id   = req.post_id       ,
            would_pay = req.would_pay     ,
            voter_id  = user_id           ,
            competition = req.competition ,
            problems = req.problems       ,
        )

        db.add(vote)
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Could not vote on post: {e}')


async def fetch_popular_posts(n: int, offset: int, db: AsyncSession) -> List[PostPreview]:
    try:
        result = await db.execute(
            select(Post)
            .outerjoin(Post.votes)
            .options(
                selectinload(Post.votes),
                selectinload(Post.community)
            )
            .group_by(Post.id)
            .order_by(func.count(Vote.id).desc())
            .offset(offset)
            .limit(n)
        )        
        posts = result.scalars().all()

        if not posts:
            raise HTTPException(status_code=404, detail='No posts found')

        previews = []
        for post in posts:
            votes = [v.would_pay for v in post.votes if v.would_pay is not None]
            med = float(np.median(votes)) if votes else 0.0
            preview = PostPreview(
                post_id        = post.id             ,
                name           = post.name           ,
                contents       = post.contents[:50]  ,
                n_votes        = len(votes)          ,
                median         = med                 ,
                created_at     = post.created_at     ,
                community_name = post.community.name ,
                community_id   = post.community_id   ,
            )
            previews.append(preview)
        
        return previews
                    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not fetch popular posts: {e}')
    

async def fetch_n_posts_for_user(user_id: int, n: int, offset: int, db: AsyncSession) -> List[PostPreview]:
    try:
        result = await db.execute(
            select(Post)
            .join(ParticipantsLink, ParticipantsLink.community_id == Post.community_id)
            .outerjoin(Post.votes)
            .options(
                selectinload(Post.votes).load_only(Vote.would_pay),
                selectinload(Post.community)
            )
            .where(ParticipantsLink.user_id == user_id)
            .group_by(Post.id)
            .order_by(func.count(Vote.id).desc())
            .offset(offset)
            .limit(n)
        )
        
        posts = result.scalars().all()
        
        previews = []
        for post in posts:
            votes = [v.would_pay for v in post.votes if v.would_pay is not None]
            med = float(np.median(votes)) if votes else 0.0
            preview = PostPreview(
                post_id        = post.id             ,
                name           = post.name           ,
                contents       = post.contents[:50]  ,
                n_votes        = len(votes)          ,
                median         = med                 ,
                created_at     = post.created_at     ,
                community_name = post.community.name ,
                community_id   = post.community_id   ,
            )
            previews.append(preview)

        return previews
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not fetch posts for user: {e}')


async def search_posts(query: str, n: int, db: AsyncSession) -> List[Post]:
    try:
        language = detect_language('', query)

        ts_query = func.plainto_tsquery(language, query)

        stmt = (
            select(Post)
            .options(
                     selectinload(Post.votes),
                     selectinload(Post.community),
                 )
            .where(Post.search_vector.op('@@')(ts_query))
            .order_by(func.ts_rank_cd(Post.search_vector, ts_query).desc())
            .limit(n)
        )

        result = await db.execute(stmt)
        posts = result.scalars().all()

        previews = []
        for post in posts:
            votes = [v.would_pay for v in post.votes]
            med = np.median(votes)
            preview = PostPreview(
                post_id        = post.id             ,
                name           = post.name           ,
                n_votes        = len(votes)          ,
                median         = med                 ,
                created_at     = post.created_at     ,
                community_name = post.community.name ,
                community_id   = post.community_id   ,
            )
            previews.append(preview)

        return previews

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not search posts: {e}')


async def connect(requester_id: int, contact_ids: list[int], db: AsyncSession):
    try:
        result = await db.execute(
            select(Connection).where(
                Connection.requester_id == requester_id,
                Connection.contact_id.in_(contact_ids)
            )
        )
        existing_contact_ids = {row[0] for row in result.fetchall()}

        new_contact_ids = [cid for cid in contact_ids if cid not in existing_contact_ids]

        for cid in new_contact_ids:
            db.add(Connection(requester_id=requester_id, contact_id=cid))
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(statius_code=500, detail=f'Could not add contacts: {e}')


async def join_community(
    req: JoinCommunityRequest,
    db: AsyncSession,
    user_id: int
):
    try:
        community = await db.get(Community, req.community_id)
        if not community:
            raise HTTPException(404, "Community not found")
        
        link = ParticipantsLink(
            user_id=user_id,
            community_id=req.community_id
        )
        
        db.add(link)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not join community')


async def fetch_popular_communities():
    pass


async def fetch_new_communities():
    pass


async def edit_community(req: EditCommunityRequest, db: AsyncSession, user_id: int):
    try:
        result = await db.execute(
            select(Community)
            .options(
                selectinload(Community.mods)
            )
            .where(Community.id == req.community_id)
        )
        community = result.scalars().first()

        result = await db.execute(
            select(ParticipantsLink)
            .where(ParticipantsLink.user_id == user_id,
                   ParticipantsLink.community_id == req.community_id)
        )
        participant = result.scalars().firat()
    
        if not participant:
            raise HTTPException(status_code=401, detail="User in not in the community")    

        if not community:
            raise HTTPException(status_code=404, detail='Community not found')

        if user_id not in [m.user_id for m in community.mods]:
            raise HTTPException(status_code=401, detail='Forbidden')
        
        community.description = req.description
        
        await db.flush()
        await db.ferfesh(community)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not edit community: {e}')


async def change_moderators(req: ChangeModeratorsRequest, db: AsyncSession, user_id: int):
    try:
        if req.add:
            result = await db.execute(
                select(Moderator)
                .where(Moderator.user_id == req.add, Moderator.community_id == req.community_id)
            )
            mod = result.scalars().first()

            if mod:
                raise HTTPException(status_code=401, detail='Moderator already exists')
            else:
                mod = Moderator(
                    community_id = req.community_id ,
                    user_id      = user_id          ,
                )
                db.add(mod)
            
        if req.remove:
            result = await db.execute(
                select(Moderator)
                .where(Moderator.user_id == req.remove, Moderator.community_id == req.community_id)
            )
            mod = result.scalars().first()

            if not mod:
                raise HTTPException(status_code=404, detail="User doesn't moderate community")
            else:
                await db.delete(mod)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not edit community: {e}')


async def list_new_communities():
    try:
        

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not edit community: {e}')
    

async def list_popular_communities():
    pass
