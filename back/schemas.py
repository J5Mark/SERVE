from pydantic import BaseModel, Field, EmailStr
from pydantic_extra_types.phone_numbers import PhoneNumber
from typing import Optional, List
from datetime import datetime


class AuthRequest(BaseModel):
    device_id: str
    username: Optional[str]
    password: str
    email: Optional[EmailStr]
    phone: Optional[PhoneNumber]


class DeviceLoginRequest(BaseModel):
    device_id: str


class RegisterRequest(BaseModel):
    device_id: str
    username: str
    first_name: str
    last_name: str | None
    phone_number: PhoneNumber | None
    email: EmailStr | None
    password: str

    entrep: bool = Field(default=False)
    admin: bool = False

    
class Profile(BaseModel):
    username: str
    first_name: str
    last_name: str
    created_at: str 
    entrep: bool
    businesses: Optional[List]
    posts: Optional[List]


class CreateCommunityRequest(BaseModel):
    name: str = Field(min_length=4, max_length=25)
    description: str = Field(min_length=10)
    reddit_link: Optional[str]
    creator_id: str
    slug: str   


class DeleteCommunityRequest(BaseModel):
    community_id: int


class CreateBusinessRequest(BaseModel):
    name: str = Field(max_length=20)
    bio: str
    community_ids: List[int]    


class EditBusinessRequest(BaseModel):
    bio: str | None = None
    community_ids: List[int] | None = None


class VerifyBusinessRequest(BaseModel):
    business_id: int
    type: str = Field(max_length=5)


class CreatePostRequest(BaseModel):
    name: str
    contents: str
    community_id: int


class EditPostRequest(BaseModel):
    post_id: int
    contents: str


class VoteOnPostRequest(BaseModel):
    post_id: int
    would_pay: int
