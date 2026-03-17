from fastapi import FastAPI, Depends, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import asyncio, uuid, json, aiohttp, logging, os
from datetime import datetime
import uvicorn
from competition import get_post_analysis


app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

CORE_BASE_URL = os.getenv('CORE_BASEURL', 'http://back:8000')

q = asyncio.Queue(maxsize=15)


async def fetch_post_for_task(task_id: int, token: str) -> dict:
    async with aiohttp.ClientSession() as session:
        async with session.get(
            f"{CORE_BASE_URL}/api/aiservice/task_post",
            headers={"Authorization": f"Bearer {token}"}
        ) as resp:
            resp.raise_for_status()
            data = await resp.json()
            return await resp.json()


async def submit_analysis_result(task_id: int, result: dict, token: str):
    async with aiohttp.ClientSession() as session:
        async with session.post(
            f"{CORE_BASE_URL}/api/aiservice/submit_analysis",
            json=result,
            headers={"Authorization": f"Bearer {token}"}
        ) as resp:
            resp.raise_for_status()
            return await resp.json()


async def submit_error(task_id: int, error: str, token: str):
    async with aiohttp.ClientSession() as session:
        async with session.post(
            f"{CORE_BASE_URL}/api/aiservice/submit_error",
            json={"task_id": task_id, "error": error},
            headers={"Authorization": f"Bearer {token}"}
        ) as resp:
            resp.raise_for_status()
            return await resp.json()


@app.post('/start_analysis')
async def start_analysis(task_id: int, authorization: str = None):
    token = authorization.replace("Bearer ", "") if authorization else None
    await q.put((task_id, token))
    logging.info(f"Task {task_id} queued")
    return {"status": "queued", "task_id": task_id}


async def post_analysis():
    while True:
        try:
            task_id, token = await q.get()
            logging.info(f"Processing task {task_id}")

            if not token:
                logging.error(f"No token for task {task_id}")
                q.task_done()
                continue

            try:
                post_data = await fetch_post_for_task(task_id, token)
                logging.info(f"Got post data for task {task_id}: {post_data.get('id')}")

                result = await get_post_analysis(post_data)

                await submit_analysis_result(task_id, result, token)
                logging.info(f"Submitted analysis for task {task_id}")

            except Exception as e:
                logging.error(f"Error processing task {task_id}: {e}")
                try:
                    await submit_error(task_id, str(e), token)
                except Exception as sub_err:
                    logging.error(f"Failed to submit error for task {task_id}: {sub_err}")

            q.task_done()

        except Exception as e:
            logging.error(f'Error in post analysis worker: {e}')
            await asyncio.sleep(5)


@app.get('/health')
async def health():
    return {'status': 'ok'}


app.on_event('startup')
async def startup_event():
    logging.info('Starting up')
    try:
        asyncio.create_task(post_analysis())
    
    except Exception as e:
        logging.error(f'Could not init app. Error: {e}')


if __name__ == "__main__":
    try:
        uvicorn.run('main:app', host="0.0.0.0", port=3000, reload=False, proxy_headers=True)

    except Exception as e:
        logging.error(f'Could not start app: {e}')
