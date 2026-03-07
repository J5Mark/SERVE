import os, logging

logging.basicConfig(level=logging.DEBUG)
from fastapi import Depends, HTTPException, APIRouter
from auth import auth, create_user_tokens, get_user_id_from_token
from authx import TokenPayload
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from schemas import *
from typing import Optional
from uuid import uuid4
from utils import *
from postgres_conn import User, UserAuth, get_db
from polar_sdk import Polar

s = Polar(
    access_token=os.environ.get('POLAR_ACCESS_TOKEN', ''),
    server = os.environ.get('PAYMENT_SERVER')
)

router = APIRouter(prefix='/payments', tags=['payments'])


@router.post('/transaction')
async def commit_transaction():
    pass


@router.post('/record')
async def record_payment_ep(
    req: RecordPaymentrequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    pass


@router.post('/change_balance')
async def change_balance_ep(
    req: ChangeBalanceRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    pass
