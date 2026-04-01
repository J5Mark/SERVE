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
from postgres_conn import User, UserAuth, get_db, Community, Message
from notifications import notify_conversation_participants

router = APIRouter(prefix="/api/chats", tags=["chats"])


class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, conversation_id: int):
        await websocket.accept()
        if conversation_id not in self.active_connections:
            self.active_connections[conversation_id] = []
        self.active_connections[conversation_id].append(websocket)

    def disconnect(self, websocket: WebSocket, conversation_id: int):
        if conversation_id in self.active_connections:
            self.active_connections[conversation_id].remove(websocket)

    async def broadcast(self, message: dict, conversation_id: int):
        if conversation_id in self.active_connections:
            for connection in self.active_connections[conversation_id]:
                await connection.send_json(message)


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
    try:
        new_conv = await create_conversation(target_user_id, db, user_id)
        await db.commit()
        await db.refresh(new_conv)
        return {"conversation_id": new_conv.id}
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Could not create conversation: {e}")


@router.websocket('/ws/chat/{conversation_id}')
async def websocket_chat(
    ws: WebSocket,
    conversation_id: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    await manager.connect(ws, conversation_id)
    
    try:
        while True:
            data = await ws.receive_json()
            content = data.get("content")

            if content:
                new_msg = Message(
                    content=content,
                    conversation_id=conversation_id,
                    author_id=user_id
                )
                db.add(new_msg)
                await db.commit()
                await db.refresh(new_msg)

                payload = {
                    "id": new_msg.id,
                    "content": new_msg.content,
                    "author_id": new_msg.author_id,
                    "created_at": new_msg.created_at.isoformat()
                }
                await manager.broadcast(payload, conversation_id)
                # Send push notification to other participants
                await notify_conversation_participants(
                    conversation_id,
                    user_id,
                    "New message",
                    content[:100] + '...' if len(content) > 100 else content,
                    db,
                )

    except WebSocketDisconnect:
        manager.disconnect(ws, conversation_id)


@router.get('/{conversation_id}/{n}/{offset}')
async def get_messages_ep(
    conversation_id: int,
    n: int,
    offset: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    messages = await get_messages(conversation_id, n, offset, db, user_id)
    return messages


@router.post('/{conversation_id}')
async def send_message_ep(
    conversation_id: int,
    req: SendMessage,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    new_msg = await save_message(conversation_id, req.content, db, user_id)
    await db.commit()
    await db.refresh(new_msg)
    # Send push notification to other participants
    await notify_conversation_participants(
        conversation_id,
        user_id,
        "New message",
        req.content[:100] + '...' if len(req.content) > 100 else req.content,
        db,
    )
    
    return {
        "id": new_msg.id,
        "content": new_msg.content,
        "author_id": new_msg.author_id,
        "is_me": True,
        "created_at": new_msg.created_at.isoformat() if new_msg.created_at else None,
    }
