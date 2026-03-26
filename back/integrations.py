import os, logging, aiohttp

logging.basicConfig(level=logging.DEBUG)
from fastapi import Depends, HTTPException, APIRouter
from auth import auth, create_user_tokens, get_user_id_from_token
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from schemas import *
from typing import Optional
from uuid import uuid4
from utils import *
from postgres_conn import User, UserAuth, get_db
from dotenv import load_dotenv
from os import environ as env

load_dotenv()

router = APIRouter(prefix='/api/integrations', tags=['integrations'])

INTEGRATIONS_BASE = env.get('INTEGRATIONS_BASE', 'http://integrations:3000')

@router.get('/reddit/check-community/{name}')
async def check_reddit_community_existence_ep(
    name: str
):
    try:
        async with aiohttp.ClientSession(base_url=INTEGRATIONS_BASE) as client:
            async with client.get(f'/check-subreddit/{name}') as resp:
                resp.raise_for_status()
                data = await resp.json()
                exists = bool(data.get('exists', False))
                return {'subreddit': exists}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not check subreddit existence: {e}')


@router.get('/reddit/get-subscribers/{name}')
async def get_reddit_subscribers_ep(
    name: str
):
    try:
        async with aiohttp.ClientSession(base_url=INTEGRATIONS_BASE) as client:
            async with client.get(f'/get-subreddit-participants/{name}') as resp:
                resp.raise_for_status()
                data = await resp.json()
                subs = int(data.get('subscribers', -1))
                return {'subs': subs}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not get subreddit subscribers: {e}')

    
@router.get('/reddit/get-description/{name}')
async def get_reddit_description_ep(
    name: str
):
    try:
        async with aiohttp.ClientSession(base_url=INTEGRATIONS_BASE) as client:
            async with client.get(f'/get-subreddit-description/{name}') as resp:
                resp.raise_for_status()
                data = await resp.json()
                desc = data.get('description', '')
                return {'description': desc}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not get subreddit description: {e}')
