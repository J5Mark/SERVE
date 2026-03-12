from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import and_, delete
from sqlalchemy import select, func, update, desc, asc
from sqlalchemy.orm import selectinload
from pgvector.sqlalchemy import Vector
from typing import List
import numpy as np
import aiohttp

import logging
from schemas import *
from postgres_conn import *
from os import environ as env
from red_flags import REDFLAG_TEXTS


# place for all the LLM-powered utils


async def embed_text(text: str | List[str]) -> List:
    logging.info(f"embed_text: START - texts={len(text) if isinstance(text, list) else 1}")
    url = env.get('LLM_BASE_URL', 'http://ollama-service:11434')
    model = env.get('LLM_MODEL', 'embeddinggemma')
    logging.info(f"embed_text: url={url}, model={model}")
    
    connector = aiohttp.TCPConnector()
    session = aiohttp.ClientSession(connector=connector)
    try:
        full_url = f"{url}/api/embed"
        logging.info(f"embed_text: POST to {full_url}")
        
        async with session.post(full_url,
                               json={
                                   'model': model,
                                   'input': text,
                               }, timeout=aiohttp.ClientTimeout(total=30)) as resp:
            resp.raise_for_status()
            
            data = await resp.json()
            logging.info(f"vector length: {len(data['embeddings'][0])}")
            return data['embeddings']
    finally:
        await session.close()
        logging.info("embed_text: session closed")


# TODO : make a batching worker that would get tasks from different places in the app and return them in proper places after processing

# Wrapper for embed_text + the worker when it comes
async def get_embeddings(texts: List[str], toworker: bool = False):
    logging.warning(f"get_embeddings: received texts type={type(texts)}, len={len(texts) if texts else 0}")
    logging.warning(f"get_embeddings: texts={texts}")
    try:
        if not toworker:
            emb = await embed_text(texts)
            return emb
        else:
            raise NotImplementedError

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not get embedding: {e}')


async def insert_redflag_intentions(db: AsyncSession):
    logging.info(f"insert_redflag_intentions: processing {len(REDFLAG_TEXTS)} redflag intentions")
    embeddings = await get_embeddings([rf[1] for rf in REDFLAG_TEXTS])
    logging.info(f'Embeddings retrieved, size: {len(embeddings[0]) if embeddings else 0}')

    try:
        for label, emb in zip([rf[0] for rf in REDFLAG_TEXTS], embeddings):
            flag = RedFlagIntent(
                label = label,
                embedding = emb
            )
            db.add(flag)
        logging.info(f"Added {len(REDFLAG_TEXTS)} redflag intentions to session")
            
    except Exception as e:
        logging.error(f"Error inserting redflag intentions: {e}")
        raise


async def search_sentiment(query_vector: List, limit: int, db: AsyncSession):
    similarity_threshold = 0.5
    
    try:
        result = await db.execute(
            select(RedFlagIntent.label)
            .where(RedFlagIntent.embedding.cosine_distance(query_vector) < (1 - similarity_threshold))
            .order_by(RedFlagIntent.embedding.cosine_distance(query_vector))
            .limit(limit)
        )

        return result.scalar_one_or_none()
        
    except Exception as e:
        logging.error(f'Could not search sentiment: {e}')
        raise HTTPException(status_code=500, detail=f'Could not search sentiment: {e}')


async def sentiment_check(db: AsyncSession, *args) -> bool:
    flat_args = []
    for arg in args:
        if isinstance(arg, (list, tuple)):
            flat_args.extend(str(a) for a in arg)
        else:
            flat_args.append(str(arg))
    embs = await get_embeddings(flat_args)

    lebels = []
    for e in embs:
        l = await search_sentiment(e, 1, db)
        logging.warning(f'sentiment check: {l}')
        if l:
            return False

    return True
