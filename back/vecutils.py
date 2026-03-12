from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import and_, delete
from sqlalchemy import select, func, update, desc, asc
from sqlalchemy.orm import selectinload
from pgvector.sqlalchemy import Vector
from typing import List
from langdetect import detect
import numpy as np
import aiohttp

import logging
from schemas import *
from postgres_conn import *
from auth import hash_password
from os import environ as env


# place for all the LLM-powered utils


async def embed_text(text: str | List[str]) -> List: # WARNING creating a session on function call may be an antipattern, better, if requests will be made in a sequence to create one session and use it in all requests
    async with aiohttp.ClientSession(base_url=env.get('LLM_BASE_URL', 'http://ollama-service:11434/')) as session:
        async with session.post('api/embed',
                               json={
                                   'model': env.get('LLM_MODEL', 'qwen3:8b'),
                                   'input': text,
                               }, timeout=30) as resp:
            await resp.raise_for_status()
            data = await resp.json()
            return data['embeddings']


async def sentiment_check() -> bool:
    pass
