import os, logging, string

logging.basicConfig(level=logging.DEBUG)
from fastapi import Depends, HTTPException, APIRouter
from schemas import *
from typing import Optional
from uuid import uuid4
from utils import *
from postgres_conn import *

router = APIRouter(prefix='/api/aiservice', tags=['eps_for_ai_service'])

@router.get('/')
async def get_votes_on_post():
    pass

 
