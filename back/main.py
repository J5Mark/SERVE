from fastapi import FastAPI, Depends, HTTPException
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
from users import router as users_router
from communities import router as communities_router
from businesses import router as business_router
from posts import router as posts_router
from chats import router as chats_router
from integrations import router as integrations_router
from postgres_conn import *
from vecutils import *
from dotenv import load_dotenv
from os import environ as env

load_dotenv()

app = FastAPI()


# App Links - Android assetlinks.json
@app.get("/.well-known/assetlinks.json")
async def assetlinks():
    return [
        {
            "relation": ["delegate_permission/common.handle_all_links"],
            "target": {
                "namespace": "android_app",
                "package_name": "com.serve.app",
                "sha256_cert_fingerprints": []
            }
        }
    ]


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
auth_.handle_errors(app)

### ENDPOINTS


@app.get("/health")
async def health():
    return {"status": "ok"}


### STARTUP AND SHUTDOWN EVENTS

async def insert_init(db: AsyncSession):
    await insert_redflag_intentions(db)
    await db.commit()

@app.on_event("startup")
async def startup_event():
    logging.info("Starting up: initializing database...")
    try:
        await init_db()
        logging.info("Database initialized, inserting redflag intentions...")
        async for db in get_db():
            await insert_redflag_intentions(db)
            await db.commit()
        logging.info("Startup event completed successfully")

    except Exception as err:
        logging.error(f"Could not init db. Error:\n\n{err}")


@app.on_event("shutdown")
async def shutdown_event():
    try:
        pass

    except Exception as err:
        pass


if __name__ == "__main__":
    try:
        uvicorn.run("main:app", host="0.0.0.0", port=1000, reload=False, proxy_headers=True)

    except Exception as e:
        event.Event("The app could not start", {"level": "error", "error": str(e)})
