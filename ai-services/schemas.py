from pydantic import BaseModel
from typing import List, Any


class Vote(BaseModel):
    would_pay: float | None
    competition: str
    problems: str
    embedding: List | Any


class Post(BaseModel):
    name: str
    contents: str
    votes: List[Vote]
