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

router = APIRouter(prefix="/chats", tags=["chats"])

