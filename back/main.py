from fastapi import FastAPI, Depends, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.middleware.sessions import SessionMiddleware
import asyncio, uuid, json, aiohttp, logging
from datetime import datetime
from collections import defaultdict
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, desc
from sqlalchemy.orm import selectinload
import uvicorn

from schemas import *

# from utils import *
from auth import router as auth_router, auth as auth_, security
from auth import get_user_id_from_token
from users import router as users_router
from communities import router as communities_router
from businesses import router as business_router
from posts import router as posts_router
from chats import router as chats_router
from integrations import router as integrations_router
from payments import router as payments_router
from aiapi import router as ai_router, ai_analysis_worker
from notifications import router as notifications_router
from utils import *
from postgres_conn import get_db, init_db
from vecutils import insert_redflag_intentions, run_embedding_worker
from valkey_conn import init_valkey, close_valkey
from dotenv import load_dotenv
from os import environ as env

load_dotenv()

app = FastAPI()


# App Links - Android assetlinks.json
@app.get("/.well-known/assetlinks.json")
async def assetlinks():
    content = [
        {
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
                "namespace": "android_app",
                "package_name": "com.serve.app",
                "sha256_cert_fingerprints": [env.get('SHA256_ANDROID', '').replace(':', '').lower()]
            }
        }
    ]

    return Response(content=json.dumps(content), media_type="application/json")


# App Links - iOS apple-app-site-association
@app.get("/.well-known/apple-app-site-association")
async def apple_app_site_association():
    return {
        "applinks": {
            "apps": [],
            "details": [
                {
                    "appID": "com.serve.app",
                    "paths": ["/auth*", "/post/*", "/community/*"]
                }
            ]
        }
    }


app.add_middleware(
    SessionMiddleware,
    secret_key=env.get('SESSION_SECRET', 'qwertyuiop'),
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(users_router, dependencies=[Depends(security)])
app.include_router(communities_router, dependencies=[Depends(security)])
app.include_router(business_router, dependencies=[Depends(security)])
app.include_router(posts_router, dependencies=[Depends(security)])
app.include_router(chats_router, dependencies=[Depends(security)])
app.include_router(integrations_router)
app.include_router(ai_router)
app.include_router(notifications_router)
auth_.handle_errors(app)

### ENDPOINTS


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post('/api/feedback')
async def feedback_ep(
    req: FeedbackRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    await add_feedback(req, db, user_id)
    await db.commit()

    return {'feedback': 'saved'}


### STARTUP AND SHUTDOWN EVENTS

async def insert_init(db: AsyncSession):
    await insert_redflag_intentions(db)
    await db.commit()

@app.on_event("startup")
async def startup_event():
    logging.info("Starting up: initializing database...")
    try:
        logging.info("Starting up: connecting to valkey...")
        await init_valkey()
        logging.info("Starting up: initializing file storage...")
        await init_minio()
        logging.info("Starting up: launching embedding worker...")
        asyncio.create_task(run_embedding_worker())
        await init_db()
        logging.info("Database initialized, inserting redflag intentions...")
        async for db in get_db():
            await insert_redflag_intentions(db)
            await db.commit()
        asyncio.create_task(ai_analysis_worker())
        logging.info("Startup event completed successfully")

    except Exception as err:
        logging.error(f"Could not init db. Error:\n\n{err}")


@app.on_event("shutdown")
async def shutdown_event():
    try:
        await close_valkey()

    except Exception as err:
        pass


if __name__ == "__main__":
    try:
        uvicorn.run("main:app", host="0.0.0.0", port=1000, reload=False, proxy_headers=True)

    except Exception as e:
        event.Event("The app could not start", {"level": "error", "error": str(e)})
