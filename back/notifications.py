import os, logging
from fastapi import Depends, HTTPException, APIRouter, WebSocket
from typing import List, Optional
from postgres_conn import *
from schemas import *


class ConnectionManager:
    def __init__(self):
        pass

    async def connect(self, ws: WebSocket):
        pass

    async def disconnect(self):
        pass

    async def send(self):
        pass

cm = ConnectionManager()


router = APIRouter(prefix='/api/notifications', tags=['notifications'])
# TODO dig more into this theme, requires another infrastructure component

@router.websocket('/ws/{user_id}')
async def websocket_notifications(ws: WebSocket, user_id: int):
    await cm.connect(ws)
    pass


@router.post('/send_notification')
async def send_notification(
    req: NotificationRequest
):
    await sm.send()
    pass

    return {'status': 'sent'}
