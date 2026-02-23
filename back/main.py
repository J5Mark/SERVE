from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
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
from postgres_conn import *


app = FastAPI()

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
auth_.handle_errors(app)

### ENDPOINTS


@app.get("/health")
async def health():
    return {"status": "ok"}


### STARTUP AND SHUTDOWN EVENTS


@app.on_event("startup")
async def startup_event():
    try:
        await init_db()
        print("startup event over")

    except Exception as err:
        print(f"Could not init db. Error:\n\n{err}")


@app.on_event("shutdown")
async def shutdown_event():
    try:
        pass

    except Exception as err:
        pass


if __name__ == "__main__":
    try:
        uvicorn.run("main:app", host="0.0.0.0", port=1000, reload=False)

    except Exception as e:
        event.Event("The app could not start", {"level": "error", "error": str(e)})
