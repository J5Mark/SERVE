import os, logging, string, asyncio, aiohttp

logging.basicConfig(level=logging.WARNING)
from fastapi import Depends, HTTPException, APIRouter
from schemas import *
from typing import Optional
from uuid import uuid4
from utils import *
from postgres_conn import *
from authx import AuthX, AuthXConfig, TokenPayload


JWT_SECRET_KEY = os.getenv("AI_JWT_SECRET_KEY", "zxcvbnmasdfg")

config = AuthXConfig(
    JWT_SECRET_KEY=JWT_SECRET_KEY,
    JWT_TOKEN_LOCATION=['headers'],
    JWT_ALGORITHM='HS256',
    JWT_ACCESS_TOKEN_EXPIRES=60*60*2
)

auth = AuthX(config=config)


router = APIRouter(prefix='/api/aiservice', tags=['eps_for_ai_service'])

q = asyncio.Queue(maxsize=int(os.getenv('AI_QUEUE_MAXSIZE', 10)))

async def auth_ai(req_id: int):
    token = auth.create_access_token(
        uid = str(req_id),
        data = {
            "service": "ai"
        }
    )
    return {"access_token": token}


async def start_analysis(task: PostAnalysisRequest, token: str):
    url = os.getenv('AI_SERVICE_BASEURL', 'http://ai-service:3000')
    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{url}/start_analysis",
                json={"task_id": task.id}, 
                headers={"Authorization": f"Bearer {token}"} 
            ) as resp:
                resp.raise_for_status()
    except Exception as e:
        logging.error(f"Failed to trigger AI service for task {task.id}: {e}")
        raise


async def ai_analysis_worker():
    while True:
        try:
            async with async_session() as db:
                t = await fetch_analysis_request(db)
                    
                if not t:
                    await asyncio.sleep(10)
                    continue

                auth_data = await auth_ai(t.id)
                    
                await start_analysis(t, auth_data["access_token"])
                    
                await asyncio.sleep(5) 
            
        except Exception as e:
            logging.error(f"Worker error: {e}")
            await asyncio.sleep(10)


async def get_task_id_from_token(
    payload: TokenPayload = Depends(auth.access_token_required)
) -> int:
    sub = payload.sub
    extra = payload.extra_dict

    if extra.get('service') != 'ai':
        raise HTTPException(status_code=401, detail="Forbidden")

    return int(sub)


@router.get('/task_post')
async def get_post_for_task(
    db: AsyncSession = Depends(get_db),
    task_id: int = Depends(get_task_id_from_token)
):
    result = await db.execute(
        select(PostAnalysisRequest)
        .where(PostAnalysisRequest.id == task_id)
    )
    req = result.scalars().first()

    if not req:
        raise HTTPException(status_code=404, detail='Analysis request not found')

    result = await db.execute(
        select(Post)
        .join(Post.votes)
        .options(
            contains_eager(Post.votes),
            defer(Post.embedding),
            defer(Post.search_vector)
        )
        .where(
            Post.id == req.post_id,
            Post.votes.any(
                (Vote.competition.is_not(None)) &
                (Vote.problems.is_not(None))
            )
        )
    )
    post = result.unique().scalars().first()

    if not post:
        raise HTTPException(status_code=404, detail='Post not found')

    return post
    

@router.post('/submit_analysis')
async def submit_analysis(
    req: SubmitAnalysisRequest,
    db: AsyncSession = Depends(get_db),
    task_id: int = Depends(get_task_id_from_token)
):
    await accept_analysis(
        req,
        task_id,
        db
    )
    await db.commit()

    q.task_done()

    return {'status': 'accepted'}


class ErrorRequest(BaseModel):
    task_id: int
    error: str


@router.post('/submit_error')
async def submit_error(
    req: ErrorRequest,
    db: AsyncSession = Depends(get_db),
    task_id: int = Depends(get_task_id_from_token)
):
    result = await db.execute(
        select(PostAnalysisRequest)
        .where(PostAnalysisRequest.id == task_id)
    )
    task = result.scalars().first()

    if task:
        task.processing = False
        await db.commit()

    logging.error(f"Task {task_id} failed: {req.error}")

    return {'status': 'error_logged'}
