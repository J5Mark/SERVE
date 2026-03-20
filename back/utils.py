from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import and_, delete
from sqlalchemy import select, func, update, desc, asc
from sqlalchemy.orm import selectinload, defer
from typing import List
from langdetect import detect
import numpy as np
import traceback

import logging
from schemas import *
from postgres_conn import *
from vecutils import sentiment_check, get_embeddings
from auth import hash_password
from red_flags import RED_FLAGS
import re


LANG_MAP = {
    "en": "english",
    "ru": "russian",
    "nl": "dutch",
}

_ESCAPED_FLAGS = [re.escape(flag.lower()) for flag in RED_FLAGS]
_RED_FLAGS_REGEX = re.compile('|'.join(_ESCAPED_FLAGS))

def red_flags_check(message: str) -> bool:
    message_lower = message.lower()
    matches = _RED_FLAGS_REGEX.finditer(message_lower)
    found = []
    seen = set()
    for match in matches:
        matched_text = match.group(0)
        # Находим оригинальный флаг по совпадению
        original = next(flag for flag in RED_FLAGS if flag.lower() == matched_text)
        if original not in seen:
            found.append(original)
            seen.add(original)
    
    if not found:
        return True
    return False


async def moderate(db: AsyncSession, *args):
    try:
        if not red_flags_check(' '.join(args)):
            raise HTTPException(status_code=403, detail='Moderation not passed')
        
        async for mod_db in get_db():
            try:
                sentiment = await sentiment_check(mod_db, args)
            finally:
                await mod_db.close()
        
        if not sentiment:
            raise HTTPException(status_code=403, detail='Moderation not passed')

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f'Could not moderate: {e}')
        raise

def detect_language(name: str, contents: str) -> str:
    try:
        code = detect(f"{name} {contents}")
    except Exception:
        return "english"

    return LANG_MAP.get(code, "english")


async def create_community(req: CreateCommunityRequest, user_id: int, db: AsyncSession):
    try:
        
        result = await db.execute(select(Community).where(Community.name == req.name))
        ex_community = result.scalars().first()
    
        if ex_community:
            raise HTTPException(status_code=401, detail='Community already exists')
    
        user_id = int(user_id)
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalars().first()

        mod = Moderator(user_id=user.id)
    
        community = Community(
            name         = req.name        ,
            description  = req.description ,
            reddit_link  = req.reddit_link ,
            creator_id   = user_id         ,
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
        
        text_for_embedding = f"{req.name} {req.bio}"
        embedding = await get_embeddings([text_for_embedding])
        
        business = Business(
            name          = req.name          ,
            bio           = req.bio           ,
            communities   = communities       ,
            user_id       = user_id           ,
            verifications = []                ,
            cont_goal     = req.cont_goal     ,
            reaction_time = req.reaction_time ,
            embedding     = embedding[0]      ,
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
                                      selectinload(Business.communities),
                                      defer(Business.embedding),
                                  ))
        business = result.scalars().first()

        if not business:
            raise HTTPException(status_code=404, detail='Business not found')

        if req.bio is not None:
            business.bio = req.bio 

        if req.community_ids:
            communities = []

            for c in req.community_ids:
                result = db.execute(select(Community).where(Community.id == c))
                communities.append(result.scalars().first())
            
            business.communities = communities
        
        text_for_embedding = f"{business.name} {business.bio}"
        embedding = await get_embeddings([text_for_embedding])
        business.embedding = embedding[0]
        
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
                defer(Business.embedding),
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
                selectinload(Business.communities),
                defer(Business.embedding),
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
                selectinload(Business.communities),
                defer(Business.embedding),
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
        
        text_for_embedding = f"{req.name} {req.contents}"
        embedding = await get_embeddings([text_for_embedding])
        
        post = Post(
            name         = req.name         ,
            contents     = req.contents     ,
            community_id = req.community_id ,
            user_id      = user_id          ,
            language     = detect_language(req.name, req.contents),
            embedding    = embedding[0],
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
                selectinload(Post.community),
                defer(Post.embedding),
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

        text_for_embedding = f"{post.name} {post.contents}"
        embedding = await get_embeddings([text_for_embedding])
        post.embedding = embedding[0]

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

        result = await db.execute(
            select(UserAuth)
            .where(UserAuth.user_id == user_id)
        )
        user = result.scalars().first()

        if not user:
            raise HTTPException(status_code=401, detail='An account should be created to vote')
        
        text_parts = []
        if req.competition:
            text_parts.append(req.competition)
        if req.problems:
            text_parts.append(req.problems)
        text_for_embedding = " ".join(text_parts)
        embedding = await get_embeddings([text_for_embedding])

        vote = Vote(
            post_id   = req.post_id       ,
            would_pay = req.would_pay     ,
            voter_id  = user_id           ,
            competition = req.competition ,
            problems = req.problems       ,
            embedding = embedding[0]       ,
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
                selectinload(Post.community),
                defer(Post.embedding),
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
        votes_count = select(func.count(Vote.id)).where(Vote.post_id == Post.id).scalar_subquery()
        result = await db.execute(
            select(Post)
            .join(ParticipantsLink, ParticipantsLink.community_id == Post.community_id)
            .outerjoin(Post.votes)
            .options(
                selectinload(Post.votes).load_only(Vote.would_pay),
                selectinload(Post.community),
                defer(Post.embedding),
            )
            .where(ParticipantsLink.user_id == user_id)
            .order_by(votes_count.desc())
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
        if not query.strip():
            return []
        
        language = detect_language(query, '')  # Фикс аргумента
        ts_query = func.plainto_tsquery(language, query)
    
        vote_subq = select(Vote.post_id, func.count(Vote.id).label('n_votes')) \
            .group_by(Vote.post_id).subquery()
    
        stmt = select(
            Post.id, 
            Post.name, 
            Post.created_at, 
            Post.community_id,
            Post.contents,
            Community.name.label('community_name'),
            vote_subq.c.n_votes,
            func.percentile_cont(0.5).within_group(Vote.would_pay).label('median')
        ).select_from(Post) \
         .join(Community, Post.community_id == Community.id) \
         .outerjoin(vote_subq, Post.id == vote_subq.c.post_id) \
         .outerjoin(Vote, Post.id == Vote.post_id) \
         .where(Post.search_vector.op('@@')(ts_query)) \
         .group_by(
             Post.id, Post.name, Post.created_at, Post.community_id, 
             Community.name, vote_subq.c.n_votes
         ) \
         .order_by(func.ts_rank_cd(Post.search_vector, ts_query).desc()) \
         .limit(n)        
        result = await db.execute(stmt)
        rows = result.all()
        
        return [
            PostPreview(
                post_id=row[0],
                name=row[1],
                created_at=row[2], 
                community_id=row[3],
                community_name=row[4] or "Unknown",
                contents=row[5],
                n_votes=row[6] or 0,
                median=float(row[7]) if row[7] else 0.0,
            )
            for row in rows
        ]
            
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


async def list_new_communities(n: int, offset: int, db: AsyncSession):
    try:
        result = await db.execute(
            select(Community)
            .order_by(Community.created_at.desc())
            .limit(n)
            .offset(offset)
        )
        communities = result.scalars().all()

        return communities

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not edit community: {e}')
    

async def list_popular_communities(n: int, offset: int, db: AsyncSession):
    try:
        subq = select(
            ParticipantsLink.community_id,
            func.count().label('participant_count')
        ).group_by(ParticipantsLink.community_id).subquery()
        
        result = await db.execute(
            select(Community)
            .outerjoin(subq, Community.id == subq.c.community_id)
            .order_by(
                subq.c.participant_count.desc(),
                Community.id.desc()
            )
            .limit(n)
            .offset(offset)
        )
        communities = result.scalars().all()

        return communities

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not edit community: {e}')


async def search_communities(query: str, n: int, db: AsyncSession, user_id: int | None = None) -> List[CommunityPreview]:
    try:
        language = detect_language('', query)

        ts_query = func.plainto_tsquery(language, query)

        participants_subq = (
            select(ParticipantsLink.community_id, func.count(ParticipantsLink.user_id).label('participant_count'))
            .group_by(ParticipantsLink.community_id)
            .subquery()
        )

        posts_subq = (
            select(Post.community_id, func.count(Post.id).label('post_count'))
            .group_by(Post.community_id)
            .subquery()
        )

        stmt = (
            select(Community, participants_subq.c.participant_count, posts_subq.c.post_count)
            .outerjoin(participants_subq, Community.id == participants_subq.c.community_id)
            .outerjoin(posts_subq, Community.id == posts_subq.c.community_id)
            .where(Community.search_vector.op('@@')(ts_query))
            .order_by(func.ts_rank_cd(Community.search_vector, ts_query).desc())
            .limit(n)
        )

        result = await db.execute(stmt)
        rows = result.all()

        joined_ids = set()
        if user_id:
            joined_result = await db.execute(
                select(ParticipantsLink.community_id).where(ParticipantsLink.user_id == user_id)
            )
            joined_ids = {r[0] for r in joined_result.fetchall()}

        previews = []
        for row in rows:
            community = row[0]
            participant_count = row[1] or 0
            post_count = row[2] or 0
            
            preview = CommunityPreview(
                id=community.id,
                name=community.name,
                description=community.description,
                participant_count=participant_count,
                post_count=post_count,
                joined=community.id in joined_ids,
            )
            previews.append(preview)

        return previews

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not search communities: {e}')
    

async def fetch_new_community_posts(community_id: int, n: int, db: AsyncSession) -> List[PostPreview]:
    try:
        vote_subq = (
            select(Vote.post_id, func.count(Vote.id).label('n_votes'))
            .group_by(Vote.post_id)
            .subquery()
        )

        stmt = (
            select(Post, vote_subq.c.n_votes)
            .outerjoin(vote_subq, Post.id == vote_subq.c.post_id)
            .options(selectinload(Post.community), defer(Post.embedding))
            .where(Post.community_id == community_id)
            .order_by(Post.created_at.desc())
            .limit(n)
        )

        result = await db.execute(stmt)
        rows = result.all()

        previews = []
        for row in rows:
            post = row[0]
            n_votes = row[1] or 0
            
            votes_result = await db.execute(
                select(Vote.would_pay).where(Vote.post_id == post.id)
            )
            votes = [v[0] for v in votes_result.fetchall() if v[0] is not None]
            med = float(np.median(votes)) if votes else 0.0
            
            preview = PostPreview(
                post_id        = post.id             ,
                name           = post.name           ,
                contents       = post.contents       ,
                n_votes        = n_votes             ,
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
        raise HTTPException(status_code=500, detail=f'Could not fetch new community posts: {e}')


async def fetch_popular_community_posts(community_id: int, n: int, db: AsyncSession) -> List[PostPreview]:
    try:
        vote_subq = (
            select(Vote.post_id, func.count(Vote.id).label('n_votes'))
            .group_by(Vote.post_id)
            .subquery()
        )

        stmt = (
            select(Post, vote_subq.c.n_votes)
            .outerjoin(vote_subq, Post.id == vote_subq.c.post_id)
            .options(selectinload(Post.community), defer(Post.embedding))
            .where(Post.community_id == community_id)
            .order_by(vote_subq.c.n_votes.desc().nullslast())
            .limit(n)
        )

        result = await db.execute(stmt)
        rows = result.all()

        previews = []
        for row in rows:
            post = row[0]
            n_votes = row[1] or 0
            
            votes_result = await db.execute(
                select(Vote.would_pay).where(Vote.post_id == post.id)
            )
            votes = [v[0] for v in votes_result.fetchall() if v[0] is not None]
            med = float(np.median(votes)) if votes else 0.0
            
            preview = PostPreview(
                post_id        = post.id             ,
                name           = post.name           ,
                contents       = post.contents       ,
                n_votes        = n_votes             ,
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
        raise HTTPException(status_code=500, detail=f'Could not fetch popular community posts: {e}')


async def fetch_median_ascending_community_posts(community_id: int, n: int, db: AsyncSession) -> List[PostPreview]:
    try:
        vote_subq = (
            select(Vote.post_id, func.count(Vote.id).label('n_votes'))
            .group_by(Vote.post_id)
            .subquery()
        )

        stmt = (
            select(Post, vote_subq.c.n_votes)
            .outerjoin(vote_subq, Post.id == vote_subq.c.post_id)
            .options(selectinload(Post.community), defer(Post.embedding))
            .where(Post.community_id == community_id)
            .limit(n)
        )

        result = await db.execute(stmt)
        rows = result.all()

        post_with_median = []
        for row in rows:
            post = row[0]
            n_votes = row[1] or 0
            
            votes_result = await db.execute(
                select(Vote.would_pay).where(Vote.post_id == post.id)
            )
            votes = [v[0] for v in votes_result.fetchall() if v[0] is not None]
            med = float(np.median(votes)) if votes else 0.0
            
            post_with_median.append((post, n_votes, med))

        post_with_median.sort(key=lambda x: x[2])

        previews = []
        for post, n_votes, med in post_with_median[:n]:
            preview = PostPreview(
                post_id        = post.id             ,
                name           = post.name           ,
                contents       = post.contents       ,
                n_votes        = n_votes             ,
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
        raise HTTPException(status_code=500, detail=f'Could not fetch median ascending community posts: {e}')


async def fetch_median_descending_community_posts(community_id: int, n: int, db: AsyncSession) -> List[PostPreview]:
    try:
        vote_subq = (
            select(Vote.post_id, func.count(Vote.id).label('n_votes'))
            .group_by(Vote.post_id)
            .subquery()
        )

        stmt = (
            select(Post, vote_subq.c.n_votes)
            .outerjoin(vote_subq, Post.id == vote_subq.c.post_id)
            .options(selectinload(Post.community), defer(Post.embedding))
            .where(Post.community_id == community_id)
            .limit(n)
        )

        result = await db.execute(stmt)
        rows = result.all()

        post_with_median = []
        for row in rows:
            post = row[0]
            n_votes = row[1] or 0
            
            votes_result = await db.execute(
                select(Vote.would_pay).where(Vote.post_id == post.id)
            )
            votes = [v[0] for v in votes_result.fetchall() if v[0] is not None]
            med = float(np.median(votes)) if votes else 0.0
            
            post_with_median.append((post, n_votes, med))

        post_with_median.sort(key=lambda x: x[2], reverse=True)

        previews = []
        for post, n_votes, med in post_with_median[:n]:
            preview = PostPreview(
                post_id        = post.id             ,
                name           = post.name           ,
                contents       = post.contents       ,
                n_votes        = n_votes             ,
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
        raise HTTPException(status_code=500, detail=f'Could not fetch median descending community posts: {e}')


async def get_user_conversations(
    n: int,
    offset: int,
    db: AsyncSession,
    user_id: int
):
    try:
        result = await db.execute(
            select(Conversation)
            .join(ConversationParticipant)
            .options(
                selectinload(Conversation.participants),
            )
            .where(ConversationParticipant.user_id == user_id)
            .order_by(Conversation.created_at.desc())
            .limit(n)
            .offset(offset)
        )
        conversations = result.scalars().all()
    
        formatted = []
        for conv in conversations:
            participants = conv.participants
            other_user = None
            for p in participants:
                if p.id != user_id:
                    other_user = {"id": p.id, "username": p.username}
                    break
            
            last_msg_result = await db.execute(
                select(Message)
                .where(Message.conversation_id == conv.id)
                .order_by(Message.created_at.desc())
                .limit(1)
            )
            last_msg = last_msg_result.scalars().first()
            
            last_message = None
            if last_msg:
                last_message = {
                    "id": last_msg.id,
                    "content": last_msg.content,
                    "created_at": last_msg.created_at.isoformat() if last_msg.created_at else None
                }
            formatted.append({
                "id": conv.id,
                "other_user": other_user,
                "last_message": last_message,
            })
        return formatted

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not get conversations: {e}')


async def create_conversation(
    target_user_id: int,
    db: AsyncSession,
    current_user_id: int
):
    try:
        if target_user_id == current_user_id:
            raise HTTPException(status_code=400, detail="Cannot create conversation with yourself")
    
        stmt = (
            select(Conversation)
            .join(ConversationParticipant)
            .where(ConversationParticipant.user_id == current_user_id)
        )
        result = await db.execute(stmt)
        conversations = result.scalars().all()
        
        for conv in conversations:
            result = await db.execute(
                select(ConversationParticipant)
                .where(ConversationParticipant.conversation_id == conv.id)
            )
            participants = result.scalars().all()
            participant_ids = [p.user_id for p in participants]
            if target_user_id in participant_ids and current_user_id in participant_ids:
                return conv
    
        new_conv = Conversation()
        db.add(new_conv)
        await db.flush()
    
        p1 = ConversationParticipant(conversation_id=new_conv.id, user_id=current_user_id)
        db.add(p1)
        await db.flush()
        
        p2 = ConversationParticipant(conversation_id=new_conv.id, user_id=target_user_id)
        db.add(p2)
        
        return new_conv

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not create conversation: {e}')


async def get_messages(
    conversation_id: int,
    n: int,
    offset: int,
    db: AsyncSession,
    user_id: int,
):
    try:
        result = await db.execute(
            select(Message)
            .where(Message.conversation_id == conversation_id)
            .order_by(Message.created_at.asc())
            .limit(n)
            .offset(offset)
        )
        messages = result.scalars().all()

        formatted = []
        for msg in messages:
            formatted.append({
                "id": msg.id,
                "content": msg.content,
                "author_id": msg.author_id,
                "is_me": msg.author_id == user_id,
                "created_at": msg.created_at.isoformat() if msg.created_at else None,
            })

        return formatted

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not get messages: {e}')


async def save_message(
    conversation_id: int,
    content: str,
    db: AsyncSession,
    user_id: int,
):
    try:
        new_msg = Message(
            content=content,
            conversation_id=conversation_id,
            author_id=user_id
        )
        db.add(new_msg)
        return new_msg

    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Could not add message: {e}')


async def delete_user(
    db: AsyncSession,
    user_id: int,
):
    try:
        user = await db.get(User, user_id)
        if not user:
            raise HTTPException(status_code=404, detail='User not found')
        
        await db.execute(
            update(UserAuth)
            .where(UserAuth.user_id == user_id)
            .values(user_id=None)
        )
        
        await db.delete(user)

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Could not delete user: {e}')


async def accept_analysis(
    req: SubmitAnalysisRequest,
    task_id: int,
    db: AsyncSession,
):
    try:
        result = await db.execute(
            select(PostAnalysisRequest)
            .where(PostAnalysisRequest.id == task_id)
        )
        task = result.scalars().first()

        if not task:
            raise HTTPException(status_code=404, detail='task not found')

        task_processing_start = task.created_at
        user_id = task.user_id
        post_id = task.post_id

        await db.delete(task)

        analysis = PostAnalysis(
            user_id    = user_id,
            post_id    = post_id,
            Y          = req.Y,
            Z          = req.Z,
            U          = req.U,
            additional = req.additional,
            started_working = task_processing_start
        )

        db.add(analysis)
    
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Could not save analysis: {e}')


async def fetch_analysis_request(
    db: AsyncSession
):
    subquery = (
        select(PostAnalysisRequest.id)
        .where(PostAnalysisRequest.processing == False)
        .order_by(PostAnalysisRequest.created_at.asc())
        .limit(1)
        # .with_for_update(skip_locked=True)
    ).scalar_subquery()

    stmt = (
        update(PostAnalysisRequest)
        .where(PostAnalysisRequest.id == subquery)
        .values(processing=True)
        .returning(PostAnalysisRequest) 
    )

    try:
        result = await db.execute(stmt)
        latest = result.scalar() 
        
        await db.commit()
        return latest 

    except Exception:
        await db.rollback()
        raise


async def request_analysis(post_id: int, user_id: int, full_analysis: bool, db: AsyncSession):
    try:
        result = await db.execute(
            select(User)
            .where(User.id == user_id)
        )
        user = result.scalars().first()
        if not user.entrep:
            raise HTTPException(status_code=401, detail='Forbidden')

        pending_count = await db.execute(
            select(func.count())
            .select_from(PostAnalysisRequest)
            .where(PostAnalysisRequest.user_id == user_id)
        )
        count = pending_count.scalar()
        if count >= 3:
            raise HTTPException(status_code=400, detail='Maximum 3 pending analyses allowed')

        request = PostAnalysisRequest(
            user_id=user_id,
            post_id=post_id,
            full_analysis=full_analysis,
        )
        db.add(request)

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f'Could not request analysis: {e}')


async def get_post_analysis(post_id: int, db: AsyncSession):
    try:
        result = await db.execute(
            select(PostAnalysis)
            .where(PostAnalysis.post_id == post_id)
        )
        analysis = result.scalars().first()

        if not analysis:
            raise HTTPException(status_code=404, detail='Analysis not found')

        return {
            'Y': analysis.Y,
            'Z': analysis.Z,
            'U': analysis.U,
            'additional': analysis.additional,
            'created_at': analysis.created_at,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not get analysis: {e}')


async def get_analysis_status(post_id: int, db: AsyncSession):
    try:
        result = await db.execute(
            select(PostAnalysisRequest)
            .where(PostAnalysisRequest.post_id == post_id)
        )
        request = result.scalars().first()

        if request:
            return {'status': 'pending', 'processing': request.processing}

        result = await db.execute(
            select(PostAnalysis)
            .where(PostAnalysis.post_id == post_id)
        )
        if result.scalars().first():
            return {'status': 'completed'}

        return {'status': 'not_requested'}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not get analysis status: {e}')


async def list_analyses(
    n: int,
    offset: int,
    user_id: int,
    db: AsyncSession,
):
    try:
        result = await db.execute(
            select(PostAnalysis, Post.name)
            .join(Post, Post.id == PostAnalysis.post_id)
            .where(PostAnalysis.user_id == user_id)
            .order_by(PostAnalysis.created_at.desc())
            .offset(offset)
            .limit(n)
        )
        analyses = result.all()

        short = []
        for analysis_obj, post_name in analyses:
            data = analysis_obj.model_dump()
            data["post_name"] = post_name
            short.append(AnalysisShort(**data))

        return short
        
    except HTTPException as e:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not list analyses: {e}')
