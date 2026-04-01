import os, logging
from fastapi import Depends, HTTPException, APIRouter, WebSocket
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from postgres_conn import *
from schemas import *
from utils import *
from auth import *
from firebase_admin import messaging


# class ConnectionManager:
#     def __init__(self):
#         pass

#     async def connect(self, ws: WebSocket):
#         pass

#     async def disconnect(self):
#         pass

#     async def send(self):
#         pass

# cm = ConnectionManager()


router = APIRouter(prefix='/api/notifications', tags=['notifications'])


@router.post('/register_device')
async def register_device_ep(
    req: RegisterDeviceNotifications,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token),
):
    await add_device_token(req.fcm_token, user_id, db)
    return {'device': 'registered'}    
    

def send_push(device_token: str, title: str, body: str, data: dict = None):
    payload = {
        'title': title,
        'body': body,
    }
    if data:
        payload.update(data)
    
    message = messaging.Message(
        notification = messaging.Notification(title = title, body = body),
        token=device_token
    )
    
    response = messaging.send(message)
    logging.info('Successfully sent push notification')


async def notify_conversation_participants(
    conversation_id: int,
    author_id: int,
    title: str,
    body: str,
    db: AsyncSession,
):
    # Get all participants except author
    result = await db.execute(
        select(ConversationParticipant.user_id)
        .where(
            ConversationParticipant.conversation_id == conversation_id,
            ConversationParticipant.user_id != author_id,
        )
    )
    participant_ids = result.scalars().all()
    if not participant_ids:
        return

    # Get device tokens for those participants
    result = await db.execute(
        select(DeviceToken.fcm_token)
        .where(DeviceToken.user_id.in_(participant_ids))
    )
    tokens = result.scalars().all()
    if not tokens:
        return

    # Send push to each token
    for token in tokens:
        try:
            send_push(token, title, body, data={'type': 'chat', 'id': str(conversation_id)})
        except Exception as e:
            logging.error(f"Failed to send push to token {token}: {e}")

#
# 
# @router.websocket('/ws/{user_id}')
# async def websocket_notifications(ws: WebSocket, user_id: int):
#     await cm.connect(ws)
#     pass


# @router.post('/send_notification')
# async def send_notification(
#     req: NotificationRequest
# ):
#     await sm.send()
#     pass

#     return {'status': 'sent'}
