import os
import logging
from fastapi import Depends, HTTPException, APIRouter, UploadFile, File
from fastapi.responses import StreamingResponse, HTMLResponse

logging.basicConfig(level=logging.DEBUG)
from auth import auth, get_user_id_from_token
from authx import TokenPayload
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload, defer
from schemas import *
from typing import Optional
from uuid import uuid4
from utils import *
from postgres_conn import User, UserAuth, get_db, Community, Post, PostAnalysis, PostAnalysisRequest
from minio_conn import (
    upload_post_image, fetch_post_image, delete_post_image,
)

router = APIRouter(prefix='/api/post', tags=['posts'])

@router.post('/c')
async def create_post_ep(
    req: CreatePostRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    await moderate(db, req.contents, req.name)
    
    post = await create_post(req, user_id, db)
    await db.commit()
    await db.refresh(post)

    return {'id': post.id}


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
            selectinload(Post.community),
            defer(Post.embedding),
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
        <meta property="og:url" content="https://serveyourcommunity.ftp.sh/post/g/{post.id}">
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
            
            <a href="https://serveyourcommunity.ftp.sh/#/home" class="btn">Open in App</a>
            <a href="https://serveyourcommunity.ftp.sh/#/post/{post.id}" class="btn btn-secondary">View on Web</a>
            
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
                    window.location.href = 'https://serveyourcommunity.ftp.sh/#/post/{post.id}';
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
    await moderate(db, req.contents)
    
    await edit_post(req, db)
    await db.commit()

    return {'post': 'edited'}


@router.post('/vote')
async def vote_on_post_ep(
    req: VoteOnPostRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    await moderate(db, req.competition, req.problems)
    
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


@router.post('/analyze/{post_id}')
async def request_analysis_ep(
    post_id: int,
    full_analysis: bool = True,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    await request_analysis(post_id, user_id, full_analysis, db)
    await db.commit()
    return {'status': 'requested', 'post_id': post_id}


@router.get('/analysis/{post_id}')
async def get_analysis_ep(
    post_id: int,
    db: AsyncSession = Depends(get_db),
):
    result = await get_post_analysis(post_id, db)
    return result


@router.get('/analysis_status/{post_id}')
async def get_analysis_status_ep(
    post_id: int,
    db: AsyncSession = Depends(get_db),
):
    result = await get_analysis_status(post_id, db)
    return result


@router.get('/analyses/my/{n}/{offset}')
async def list_analyses_ep(
    n: int,
    offset: int,
    user_id: int = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
):
    analyses = await list_analyses(n, offset, user_id, db) # TODO
    return analyses


@router.post('/image/{post_id}')
async def upload_post_image_ep(
    post_id: int,
    image: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    result = await db.execute(select(Post).where(Post.id == post_id))
    post = result.scalars().first()
    if not post or post.user_id != user_id:
        raise HTTPException(status_code=403, detail="Cannot upload image for this post")
    
    image_bytes = await image.read()
    await upload_post_image(post_id, image_bytes)
    
    logging.info(f"Setting image=True for post {post_id}")
    post.image = True
    await db.commit()
    logging.info(f"Successfully uploaded image for post {post_id}")
    
    return {"status": "uploaded", "post_id": post_id}


@router.get('/image/{post_id}')
async def get_post_image_ep(post_id: int):
    try:
        return await fetch_post_image(post_id)
    except Exception as e:
        logging.error(f"Error fetching post image: {e}")
        raise HTTPException(status_code=404, detail="Image not found")


@router.delete('/image/{post_id}')
async def delete_post_image_ep(
    post_id: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    result = await db.execute(select(Post).where(Post.id == post_id))
    post = result.scalars().first()
    if not post or post.user_id != user_id:
        raise HTTPException(status_code=403, detail="Cannot delete image for this post")
    
    await delete_post_image(post_id)
    post.image = False
    await db.commit()
    return {"status": "deleted"}
