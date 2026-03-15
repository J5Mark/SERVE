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


class SimpleRegisterRequest(BaseModel):
    username: str | None = None
    first_name: str | None = None
    last_name: str | None = None
    email: EmailStr | None = None
    password: str | None = None


class UpdateUserRequest(BaseModel):
    username: str | None = None
    first_name: str | None = None
    last_name: str | None = None
    phone_number: PhoneNumber | None = None
    email: EmailStr | None = None


class Profile(BaseModel):
    username: str
    first_name: str
    last_name: str
    created_at: str
    entrep: bool
    businesses: Optional[List]
    posts: Optional[List]


class UserResponse(BaseModel):
    id: int
    device_id: Optional[str] = None
    username: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone_number: Optional[str] = None
    email: Optional[str] = None
    admin: bool = False
    balance: int = 0
    entrep: bool = False
    suspended: bool = False
    created_at: Optional[datetime] = None
    communities: List = []
    businesses: List = []
    posts: List = []

    class Config:
        from_attributes = True


class CreateCommunityRequest(BaseModel):
    name: str = Field(min_length=4, max_length=25)
    description: str = Field(min_length=10)
    reddit_link: Optional[str]


class DeleteCommunityRequest(BaseModel):
    community_id: int


class CreateBusinessRequest(BaseModel):
    name: str = Field(max_length=20)
    bio: str
    community_ids: List[int]
    cont_goal: str | None = None
    reaction_time: int | None = None


class EditBusinessRequest(BaseModel):
    bio: str | None = None
    community_ids: List[int] | None = None
    cont_goal: str | None = None
    reaction_time: int | None = None


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
    would_pay: float
    competition: str | None
    problems: str | None


class BusinessResponse(BaseModel):
    id: int
    name: str
    bio: str
    user_id: int
    created_at: datetime
    community_ids: List[int] = []
    verifications: dict = {}
    cont_goal: str | None = None
    response_time: int | None = None

    class Config:
        from_attributes = True


class CommunityResponse(BaseModel):
    community_id: int
    participants: int
    name: str
    description: str
    reddit_link: Optional[str]
    is_moderator: bool = False
    mods: List[int] = []


class BusinessContact(BaseModel):
    user_id: int
    username: str
    phone_number: str | None = None

    business_name: str
    business_bio: str

    cont_goal: str
    reaction_time: int
    verification_stats: dict | None = None  # seen_count | used_count | coop_count


class GetContactsRequest(BaseModel):
    n: int
    community_id: int
    post_id: int


class SearchPostRequest(BaseModel):
    query: str # no analogue for place_id since we want to look for posts in many communities
    n: int
    

class ConnectRequest(BaseModel):
    contact_ids: list[int]


class GetCommunityPostsRequest(BaseModel):
    community_id: int
    n: int
    offset: int
    sorting: str    


class EditCommunityRequest(BaseModel):
    community_id: int
    description: str
    

class ListCommunitiesRequest(BaseModel):
    n: int
    offset: int
    sorting: str


class SearchCommunitiesRequest(BaseModel):
    query: str
    n: int


class JoinCommunityRequest(BaseModel):
    community_id: int


class RecordPaymentRequest(BaseModel):
    pass


class ChangeBalanceRequest(BaseModel):
    pass


class PostPreview(BaseModel):
    post_id: int
    name: str
    contents: str
    n_votes: int
    median: float
    created_at: datetime
    community_name: str
    community_id: int
    
    model_config = {"from_attributes": True}


class CommunityPreview(BaseModel):
    id: int
    name: str
    description: str
    participant_count: int
    post_count: int
    joined: bool = False
    
    model_config = {"from_attributes": True}


class ChangeModeratorsRequest(BaseModel):
    community_id: int
    add: int | None = None
    remove: int | None = None


class SendMessage(BaseModel):
    content: str


class MessageResponse(BaseModel):
    id: int
    content: str
    author_id: int
    author_username: str
    created_at: datetime
    me: bool

    class Config:
        from_attributes=True

