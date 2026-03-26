from miniopy_async import Minio
from fastapi import HTTPException
from fastapi.responses import StreamingResponse
import asyncio, logging, io
from os import environ as env
from typing import Any


logging.info(f"MINIO_PATH env: {env.get('MINIO_PATH', 'minio-service:9000')}")
logging.info(f"MINIO_ACCESS_KEY env: {env.get('MINIO_ACCESS_KEY', 'NOT SET')[:5]}...")


class MinioClient():
    def __init__(self):
        endpoint = env.get('MINIO_PATH', 'minio-service:9000').replace('http://', '').replace('https://', '')
        logging.info(f"Creating Minio client with endpoint: {endpoint}")
        self.client = Minio(
            endpoint,
            access_key=env.get('MINIO_ACCESS_KEY'),
            secret_key=env.get('MINIO_SECRET_KEY'),
            secure=env.get('MINIO_PATH', '').startswith('https'),
        )

    async def __aenter__(self):
        return self.client

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        self.client = None


async def init_minio():
    async with MinioClient() as client:
        my_buckets = ['user-avatars', 'community-avatars', 'business-avatars', 'post-images']
        for b in my_buckets:
            exists = await client.bucket_exists(b)
            if exists:
                logging.info(f'Bucket {b} already exists')
            else:
                logging.info(f'Creating bucket {b}')
                await client.make_bucket(b)
    

async def upload_user_avatar(user_id: int, av: bytes):
    try:
        async with MinioClient() as client:
            logging.info(f"Uploading avatar for user {user_id}, size: {len(av)}")
            result = await client.put_object(
                'user-avatars',
                f'{user_id}',
                io.BytesIO(av),
                length=len(av),
            )    
            logging.info(f"Upload result: {result}")
            path_to_file = f'/user_avatars/{user_id}'
            return path_to_file

    except Exception as e:
        logging.error(f"Failed to upload user avatar: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f'Could not upload user avatar: {e}')


async def upload_community_avatar(community_id: int, av: bytes):
    try:
        async with MinioClient() as client:
            result = await client.put_object(
                'community-avatars',
                f'{community_id}',
                io.BytesIO(av),
                length=len(av),
            )        
            path_to_file = f'/community_avatars/{community_id}'
            return path_to_file

    except Exception as e:
        logging.error(f"Failed to upload community avatar: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f'Could not upload community avatar: {e}')


async def upload_business_avatar(business_id: int, av: bytes):
    try:
        async with MinioClient() as client:
            result = await client.put_object(
                'business-avatars',
                f'{business_id}',
                io.BytesIO(av),
                length=len(av),
            )        
            path_to_file = f'/business_avatars/{business_id}'
            return path_to_file

    except Exception as e:
        logging.error(f"Failed to upload business avatar: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f'Could not upload business avatar: {e}')


async def upload_post_image(post_id: int, im: bytes):
    try:
        async with MinioClient() as client:
            logging.info(f"Uploading image for post {post_id}, size: {len(im)}")
            result = await client.put_object(
                'post-images',
                f'{post_id}',
                io.BytesIO(im),
                length=len(im),
            )        
            logging.info(f"Upload result: {result}")
            path_to_file = f'/post_images/{post_id}'
            return path_to_file

    except Exception as e:
        logging.error(f"Failed to upload post image: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f'Could not upload post image: {e}')


async def fetch_user_avatar(user_id: int):
    try:
        async with MinioClient() as client:
            try:
                result = await client.get_object(
                    'user-avatars',
                    f'{user_id}',
                )
                data = await result.read()
                if not data:
                    raise HTTPException(status_code=404, detail="Avatar not found")
                return StreamingResponse(
                    iter([data]), media_type="image/jpeg"
                )
            except Exception as inner_e:
                if 'Not Found' in str(inner_e) or 'NoSuchKey' in str(inner_e):
                    raise HTTPException(status_code=404, detail="Avatar not found")
                logging.error(f"Error fetching user avatar: {inner_e}")
                raise HTTPException(status_code=404, detail="Avatar not found")
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"MinIO fetch error: {e}")
        raise HTTPException(status_code=500, detail=f"Could not fetch user avatar: {e}")


async def fetch_community_avatar(community_id: int):
    try:
        async with MinioClient() as client:
            try:
                result = await client.get_object(
                    'community-avatars',
                    f'{community_id}',
                )
                data = await result.read()
                if not data:
                    raise HTTPException(status_code=404, detail="Avatar not found")
                return StreamingResponse(
                    iter([data]), media_type="image/jpeg"
                )
            except Exception as inner_e:
                if 'Not Found' in str(inner_e) or 'NoSuchKey' in str(inner_e):
                    raise HTTPException(status_code=404, detail="Avatar not found")
                logging.error(f"Error fetching community avatar: {inner_e}")
                raise HTTPException(status_code=404, detail="Avatar not found")
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error fetching community avatar: {e}")
        raise HTTPException(status_code=500, detail=f'Could not fetch community avatar: {e}')


async def fetch_business_avatar(business_id: int):
    try:
        async with MinioClient() as client:
            try:
                result = await client.get_object(
                    'business-avatars',
                    f'{business_id}',
                )
                data = await result.read()
                if not data:
                    raise HTTPException(status_code=404, detail="Avatar not found")
                return StreamingResponse(
                    iter([data]), media_type="image/jpeg"
                )
            except Exception as inner_e:
                if 'Not Found' in str(inner_e) or 'NoSuchKey' in str(inner_e):
                    raise HTTPException(status_code=404, detail="Avatar not found")
                logging.error(f"Error fetching business avatar: {inner_e}")
                raise HTTPException(status_code=404, detail="Avatar not found")
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error fetching business avatar: {e}")
        raise HTTPException(status_code=500, detail=f'Could not fetch business avatar: {e}')


async def fetch_post_image(post_id: int):
    try:
        async with MinioClient() as client:
            try:
                result = await client.get_object(
                    'post-images',
                    f'{post_id}',
                )
                data = await result.read()
                if not data:
                    raise HTTPException(status_code=404, detail="Image not found")
                return StreamingResponse(
                    iter([data]), media_type="image/jpeg"
                )
            except Exception as inner_e:
                if 'Not Found' in str(inner_e) or 'NoSuchKey' in str(inner_e):
                    raise HTTPException(status_code=404, detail="Image not found")
                logging.error(f"Error fetching post image: {inner_e}")
                raise HTTPException(status_code=404, detail="Image not found")
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error fetching post image: {e}")
        raise HTTPException(status_code=500, detail=f'Could not fetch post image: {e}')



async def delete_user_avatar(user_id: int):
    try:
        async with MinioClient() as client:
            await client.remove_object(
                'user-avatars',
                f'{user_id}'
            )

    except HTTPException as e:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not delete user avatar: {e}')
    


async def delete_community_avatar(community_id: int):
    try:
        async with MinioClient() as client:
            await client.remove_object(
                'community-avatars',
                f'{community_id}'
            )

    except HTTPException as e:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not delete community avatar: {e}')
    


async def delete_business_avatar(business_id: int):
    try:
        async with MinioClient() as client:
            await client.remove_object(
                'business-avatars',
                f'{business_id}'
            )

    except HTTPException as e:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not delete business avatar: {e}')
    


async def delete_post_image(post_id: int):
    try:
        async with MinioClient() as client:
            await client.remove_object(
                'post-images',
                f'{post_id}'
            )

    except HTTPException as e:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Could not delete post image: {e}')    
    
