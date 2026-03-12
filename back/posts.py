import os
import logging

logging.basicConfig(level=logging.DEBUG)
from fastapi import Depends, HTTPException, APIRouter
from fastapi.responses import HTMLResponse
from auth import auth, get_user_id_from_token
from authx import TokenPayload
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from schemas import *
from typing import Optional
from uuid import uuid4
from utils import *
from postgres_conn import User, UserAuth, get_db, Community, Post

router = APIRouter(prefix='/post', tags=['posts'])

@router.post('/c')
async def create_post_ep(
    req: CreatePostRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    await moderate(req.contents, req.name)
    
    await create_post(req, user_id, db)
    await db.commit()

    return {'post': 'created'}


@router.get('/g/{post_id}')
async def get_post_ep(
    post_id: int,
    db: AsyncSession = Depends(get_db),
):
    post = await get_post(post_id, db)
    return post


@router.get('/share/{post_id}', response_class=HTMLResponse)
async def share_post_ep(
    post_id: int,
    db: AsyncSession = Depends(get_db),
):

    result = await db.execute(
        select(Post)
        .where(Post.id == post_id)
        .options(
            selectinload(Post.community)
        )
    )
    post = result.scalars().first()

    if not post:
        raise HTTPException(status_code=404, detail='Post not found')

    community_name = post.community.name if post.community else "Community"
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta property="og:title" content="{post.name}">
        <meta property="og:description" content="{post.contents[:150]}">
        <meta property="og:url" content="https://serve-back.ftp.sh/post/g/{post.id}">
        <title>{post.name} | Serve App</title>
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #1a1a1a; color: white; margin: 0; padding: 20px; text-align: center; }}
            .container {{ max-width: 500px; margin: 50px auto; }}
            h1 {{ font-size: 24px; margin-bottom: 10px; }}
            .community {{ color: #4ade80; margin-bottom: 20px; }}
            .content {{ background: #2a2a2a; padding: 20px; border-radius: 12px; margin-bottom: 20px; text-align: left; }}
            .btn {{ display: inline-block; background: #4ade80; color: #000; padding: 14px 28px; border-radius: 8px; text-decoration: none; font-weight: bold; margin: 5px; }}
            .btn-secondary {{ background: #444; color: white; }}
            .footer {{ margin-top: 30px; color: #888; font-size: 12px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>{post.name}</h1>
            <div class="community">📁 {community_name}</div>
            <div class="content">{post.contents[:200]}{'...' if len(post.contents) > 200 else ''}</div>
            
            <a href="https://serve-back.ftp.sh/auth/deeplink/post/{post.id}" class="btn">Open in App</a>
            <a href="https://serve-back.ftp.sh/post/g/{post.id}" class="btn btn-secondary">View on Web</a>
            
            <div class="footer">
                <p>Redirecting in <span id="countdown">3</span> seconds...</p>
            </div>
        </div>
        <script>
            let count = 3;
            const interval = setInterval(() => {{
                count--;
                document.getElementById('countdown').textContent = count;
                if (count <= 0) {{
                    clearInterval(interval);
                    window.location.href = 'https://serve-back.ftp.sh/post/g/{post.id}';
                }}
            }}, 1000);
        </script>
    </body>
    </html>
    """

    return html


@router.delete('/d/{post_id}')
async def delete_post_ep(
    post_id: int,
    db: AsyncSession = Depends(get_db),
):
    await delete_post(post_id, db)
    await db.commit()
    
    return {'post': 'deleted'}


@router.post('/edit')
async def edit_post_ep(
    req: EditPostRequest,
    db: AsyncSession = Depends(get_db),
):
    await moderate(req.contents)
    
    await edit_post(req, db)
    await db.commit()

    return {'post': 'edited'}


@router.post('/vote')
async def vote_on_post_ep(
    req: VoteOnPostRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    await moderate(req.competition, req.problems)
    
    await vote_on_post(req, user_id, db)
    await db.commit()

    return {'vote': 'put'}
    

@router.get('/list_popular/{n}/{offset}')
async def list_posts(
    n: int,
    offset: int,
    db: AsyncSession = Depends(get_db)
):
    posts = await fetch_popular_posts(n, offset, db)
    return posts


@router.get('/list/{n}/{offset}')
async def list_posts_for_user(
    n: int,
    offset: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    posts = await fetch_n_posts_for_user(user_id, n, offset, db)
    return posts


@router.post('/search')
async def search_posts_ep(
    req: SearchPostRequest,
    db: AsyncSession = Depends(get_db),
):
    found_posts = await search_posts(req.query, req.n, db)
    return found_posts


@router.post('/community/posts')
async def get_community_posts(
    req: GetCommunityPostsRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    match req.sorting:
        case 'new':
            posts = await fetch_new_community_posts(req.community_id, req.n, db)

        case 'popular':
            posts = await fetch_popular_community_posts(req.community_id, req.n, db)

        case 'med_asc':
            posts = await fetch_median_ascending_community_posts(req.community_id, req.n, db)

        case 'med_desc':
            posts = await fetch_median_descending_community_posts(req.community_id, req.n, db)

        case _:
            posts = []

    return posts
