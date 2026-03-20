from pydantic import BaseModel
from typing import List, Any, Optional


class Vote(BaseModel):
    would_pay: Optional[float] = None
    competition: Optional[str] = None
    problems: Optional[str] = None
    embedding: Optional[List] = None


class Post(BaseModel):
    id: Optional[int] = None
    name: str
    contents: str
    votes: List[Vote] = []
    user_id: Optional[int] = None
    community_id: Optional[int] = None
    created_at: Optional[str] = None
