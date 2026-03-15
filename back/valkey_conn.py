import os
import json
import asyncio
from typing import List, Optional
import redis.asyncio as redis
from uuid import uuid4
from os import environ as env
from dotenv import load_dotenv

load_dotenv()


# def get_valkey_url():
#     return f"redis://{env.get('VALKEY_HOST', 'localhost')}:{env.get('VALKEY_PORT', '6379')}"


class ValkeyClient:
    def __init__(self):
        self.redis: Optional[redis.Redis] = None
    
    async def connect(self): # Documentation suggests doing simply await redis(...) on __init__ is fine
        self.redis = redis.Redis(host=env.get('VALKEY_HOST', 'valkey'), decode_responses=True)
    
    async def close(self):
        if self.redis:
            await self.redis.aclose()
    
    async def enqueue_embedding_task(self, text: str) -> str:
        task_id = str(uuid4())
        task = {
            "id": task_id,
            "text": text,
        }
        await self.redis.lpush("embedding:tasks", json.dumps(task))
        return task_id
    
    async def enqueue_embedding_batch(self, texts: List[str]) -> List[str]:
        task_ids = []
        pipeline = self.redis.pipeline()
        for text in texts:
            task_id = str(uuid4())
            task_ids.append(task_id)
            task = {
                "id": task_id,
                "text": text,
            }
            pipeline.lpush("embedding:tasks", json.dumps(task))
        await pipeline.execute()
        return task_ids
    
    async def set_task_result(self, task_id: str, embedding: List[float], error: Optional[str] = None):
        result = {
            "status": "failed" if error else "done",
            "embedding": embedding,
            "error": error,
        }
        await self.redis.setex(f"embedding:result:{task_id}", 300, json.dumps(result))
    
    async def get_task_result(self, task_id: str) -> Optional[dict]:
        result = await self.redis.get(f"embedding:result:{task_id}")
        if result:
            await self.redis.delete(f"embedding:result:{task_id}")
            return json.loads(result)
        return None
    
    async def pop_tasks_batch(self, batch_size: int = 32) -> List[dict]:
        tasks = []
        for _ in range(batch_size):
            task_json = await self.redis.rpop("embedding:tasks")
            if task_json:
                tasks.append(json.loads(task_json))
            else:
                break
        return tasks
    
    async def pop_tasks_with_timeout(self, timeout: float = 1.0) -> List[dict]:
        tasks = []
        start = asyncio.get_event_loop().time()
        while True:
            task_json = await self.redis.rpop("embedding:tasks")
            if task_json:
                tasks.append(json.loads(task_json))
            elapsed = asyncio.get_event_loop().time() - start
            if not task_json or elapsed >= timeout or len(tasks) >= 32:
                break
            await asyncio.sleep(0.01)
        return tasks


valkey_client = ValkeyClient()


async def init_valkey():
    await valkey_client.connect()


async def close_valkey():
    await valkey_client.close()
