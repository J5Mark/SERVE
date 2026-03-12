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

# place for all the LLM-powered utils


async def embed_text(text: str) -> List:
    pass

