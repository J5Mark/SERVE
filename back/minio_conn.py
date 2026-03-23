from miniopy_async import Minio
import asyncio
from os import environ as env


async def init_minio():
    client = Minio(
        env.get('MINIO_PATH', 'http://minio:9000'),
        access_key=env.get('MINIO_ACCESS_KEY'),
        secret_key=env.get('MINIO_SECRET_KEY'),
        secure=False,
    )
    

async def upload_user_avatar():
    path_to_file = ''
    
    return path_to_file


async def upload_community_avatar():
    path_to_file = ''
    
    return path_to_file


async def upload_business_avatar():
    path_to_file = ''
    
    return path_to_file


async def upload_post_image():
    path_to_file = ''
    
    return path_to_file


async def delete_user_avatar():
    path_to_file = ''
    
    return path_to_file


async def delete_community_avatar():
    path_to_file = ''
    
    return path_to_file


async def delete_business_avatar():
    path_to_file = ''
    
    return path_to_file


async def delete_post_image():
    path_to_file = ''
    
    return path_to_file
