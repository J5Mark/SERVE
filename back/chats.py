import os
import logging

logging.basicConfig(level=logging.DEBUG)
from fastapi import Depends, HTTPException, APIRouter, WebSocket
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


class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[int, WebSocket] = {}

    async def connect(self, ws: WebSocket, user_id: int):
        await ws.accept()
        self.active_connections[user_id] = ws

    def disconnect(self, user_id: int):
        if user_id in self.active_connections:
            del self.active_connections[user_id]

    async def send_pm(self, message: MessageResponse, user_id: int):
        if user_id in self.active_connections:
            await self.active_connections[user_id].send_json(message.model_dump())

    async def get_conversation_participants(self, conversation_id: int, db: AsyncSession) -> List[int]:
        result = await db.execute(
            select(ConversationParticipant.user_id)
            .where(ConversationParticipant.conversation_id == conversation_id)
        )
        return [row[0] for row in result.fetchall()]

    async def broadcast_conversation(self, message: MessageResponse, conversation_id: int, exclude_user_id: Optional[int] = None):
        for participant_user_id in await self.get_conversation_participants(conversation_id):
            if exclude_user_id and participant_user_id == exclude_user_id:
                continue
            await self.send_pm(message, participant_user_id)


manager = ConnectionManager()


@router.get('/')
async def get_user_conversations_ep(
    n: int,
    offset: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    convos = await get_user_conversations(n, offset, db, user_id)
    return convos


@router.post('/{target_user_id}/create')
async def create_conversation_ep(
    target_user_id: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    pass

    return {'chat': 'created'}


@router.websocket('/ws/chat/{conversation_id}')
async def websocket_chat(
    ws: WebSocket,
    conversation_id: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    pass
