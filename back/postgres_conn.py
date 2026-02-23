from sqlmodel import SQLModel, Field, Relationship, Column, Integer, String, JSON, func, select, UniqueConstraint, ARRAY, UUID, BigInteger, Boolean, ForeignKey
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.dialects.postgresql import TSVECTOR
from sqlalchemy import DateTime, event, text, Index
from datetime import datetime
from typing import List, Optional
from enum import Enum

from uuid import uuid4
from os import environ as env


class UserAuth(SQLModel, table=True):
    __tablename__ = "auth_users"

    user_id: int = Field(foreign_key='users.id', default=None, sa_type=BigInteger)
    device_id: str = Field(primary_key=True)

    username: str | None = Field(default=None, index=True)
    password_hash: str
    email: str | None = Field(default=None, index=True)
    google: str | None = Field(default=None, index=True)
    phone: str | None = Field(default=None, index=True)

    
class Moderator(SQLModel, table=True):
    __tablename__ = 'moderators'
    
    id: int | None = Field(default=None, sa_type=BigInteger, primary_key=True)
    community_id: int | None = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey("communities.id", ondelete="CASCADE"),
            nullable=True
        )
    )
    moderates: "Community" = Relationship(
        back_populates='mods'
    )
    user_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey("users.id", ondelete="CASCADE"),
        )
    )

class ParticipantsLink(SQLModel, table=True):
    community_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey("communities.id", ondelete="CASCADE"),
            primary_key=True
        )
    )
    user_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True
        )
    )


class BusinessOperationsLink(SQLModel, table=True):
    community_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey("communities.id", ondelete="CASCADE"),
            primary_key=True
        )
    )
    business_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey("businesses.id", ondelete="CASCADE"),
            primary_key=True
        )
    )


class User(SQLModel, table=True):
    __tablename__ = "users"

    id: int = Field(primary_key=True, sa_type=BigInteger)

    device_id: str = Field(index=True)
    username: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone_number: Optional[str] = None
    email: Optional[str] = None
    admin: bool = Field(default=False)

    businesses: list["Business"] = Relationship(
        back_populates="user",
        sa_relationship_kwargs={"cascade": "all, delete-orphan"}
    )
    # posts: List["Post"] = Relationship(
    #     back_populates="user",
    #     sa_relationship_kwargs={"cascade": "all, delete-orphan"}
    # )

    verifications: list["Verification"] = Relationship(
        back_populates="user",
        sa_relationship_kwargs={"cascade": "all, delete-orphan"}
    )

    created_at: datetime = Field(
        sa_column=Column(
            DateTime(timezone=True),
            server_default=func.now(),
            nullable=False
        )
    )

    communities: List["Community"] = Relationship(
        back_populates="participants",
        link_model=ParticipantsLink
    )
    
    enterp: bool = Field(default=False, sa_column=Column(Boolean, default=False, nullable=False))
    suspended: bool = Field(default=False, sa_column=Column(Boolean, default=False, nullable=False))


class Community(SQLModel, table=True):
    __tablename__ = 'communities'
        
    id: int = Field(primary_key=True, sa_type=BigInteger)
    
    name: str = Field(index=True)
    description: str = Field()
    reddit_link: Optional[str] = Field(default=None, index=True)
    creator_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False
        )
    )    
    slug: str = Field(index=True)

    mods: List[Moderator] = Relationship(
        back_populates = 'moderates'
    )
    participants: List[User] = Relationship(
        back_populates = 'communities',
        link_model = ParticipantsLink
    )

    created_at: datetime = Field(
        sa_column=Column(
            DateTime(timezone=True),
            server_default=func.now(),
            nullable=False
        )
    )
    

    # posts: List['Post'] = Relationship(
    #     back_populates = 'community'
    # )
    businesses: List['Business'] = Relationship(
        back_populates='communities',
        link_model=BusinessOperationsLink
    )


class Vote(SQLModel, table=True):
    __tablename__ = 'votes'
    
    id: int = Field(primary_key=True, sa_type=BigInteger)
#     post_id: int = Field(
#     sa_column=Column(
#         BigInteger,
#         ForeignKey("posts.id", ondelete="CASCADE"),
#         nullable=False
#         )
#     )
#     post: "Post" = Relationship(back_populates='votes')
#     would_pay: float = Field()
#     voter_id: int = Field(
#         sa_column=Column(
#             BigInteger,
#             ForeignKey("users.id", ondelete="CASCADE"),
#             nullable=False
#         )
#     )

class Post(SQLModel, table=True):
    __tablename__ = 'posts'
    
    id: int = Field(primary_key=True, sa_type=BigInteger)

#     name: str = Field()
#     contents: str = Field()

#     votes: List[Vote] = Relationship(back_populates='post')
#     created_at: datetime = Field(
#         sa_column=Column(
#             DateTime(timezone=True),
#             server_default=func.now(),
#             nullable=False,
#         )
#     )

#     community_id: int = Field(
#         sa_column=Column(
#             BigInteger,
#             ForeignKey("communities.id", ondelete="CASCADE"),
#             nullable=False
#         )
#     )
#     community: Community = Relationship(
#         back_populates = 'posts'
#     )
#     user_id: int = Field(
#         sa_column=Column(
#             BigInteger,
#             ForeignKey('users.id', ondelete='CASCADE'),
#             nullable=False
#         )
#     )
#     user: User = Relationship(
#         back_populates='posts'
#     )


class Verification(SQLModel, table=True):
    __tablename__ = "verifications"

    id: int | None = Field(primary_key=True, default=None, sa_type=BigInteger)

    user_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey('users.id', ondelete='CASCADE'),
            nullable=False,
        )
    )
    user: User = Relationship(
        back_populates='verifications'
    )
    business_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey('businesses.id', ondelete='CASCADE'),
            nullable=False
        )
    )
    business: "Business" = Relationship(
        back_populates='verifications'
    )
    type: str = Field(max_length=5) # use | coop | seen


class Business(SQLModel, table=True):
    __tablename__ = 'businesses'
    __table_args__ = (
        UniqueConstraint("user_id", "name", name='uq_business'), 
    )
    
    id: int = Field(primary_key=True, sa_type=BigInteger)

    name: str = Field(index=True)
    bio: str = Field()

    communities: List[Community] = Relationship(
        back_populates='businesses',
        link_model=BusinessOperationsLink,
    )
    user_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False
        )
    )
    user: User = Relationship(back_populates='businesses')

    created_at: datetime = Field(
        sa_column=Column(
            DateTime(timezone=True),
            server_default=func.now(),
            nullable=False,
        )
    )
    verifications: List[Verification] = Relationship(
        back_populates='business'
    )

###

def get_database_url():
    return f"postgresql+asyncpg://{env['POSTGRES_USERNAME']}:{env['POSTGRES_PASSWORD']}@{env['POSTGRES_HOST']}:{env['POSTGRES_PORT']}/postgres"

def get_engine():
    return create_async_engine(
        get_database_url(),
        echo=True,
    )

engine = get_engine()

async_session = async_sessionmaker(
    engine,
    expire_on_commit=False,
    autoflush=False,
    autocommit=False,
    class_=AsyncSession
)

async def get_db():
    """Dependency for getting database session"""
    async with async_session() as db:
        try:
            yield db
            await db.commit()
        except Exception:
            await db.rollback()
            raise



# def create_search_trigger(conn):
#     conn.execute(text(
#         "DROP TRIGGER IF EXISTS update_post_search_vector ON posts"
#     ))
#     conn.execute(text(
#         "DROP FUNCTION IF EXISTS post_search_vector_trigger()"
#     ))

#     conn.execute(text("""
#         CREATE OR REPLACE FUNCTION post_search_vector_trigger()
#         RETURNS TRIGGER AS $$
#         BEGIN
#             NEW.search_vector :=
#                 to_tsvector(
#                     COALESCE(NEW.language, 'english')::regconfig,
#                     COALESCE(NEW.theme || ' ' || NEW.contents, '')
#                 );
#             RETURN NEW;
#         END;
#         $$ LANGUAGE plpgsql;
#     """))

#     conn.execute(text("""
#         CREATE TRIGGER update_post_search_vector
#         BEFORE INSERT OR UPDATE OF theme, contents, language
#         ON posts
#         FOR EACH ROW
#         EXECUTE FUNCTION post_search_vector_trigger()
#     """))


async def init_db():
    async with engine.begin() as conn:
        # Drop all tables first to ensure clean schema
        await conn.run_sync(SQLModel.metadata.drop_all)
        await conn.run_sync(SQLModel.metadata.create_all)
        # await conn.run_sync(create_search_trigger)
        
        # Add performance indexes for post queries
        # await conn.execute(text("""
        #     CREATE INDEX IF NOT EXISTS idx_posts_commun_created 
        #     ON posts(community_id, created_at DESC)
        # """))
        
        # await conn.execute(text("""
        #     CREATE INDEX IF NOT EXISTS idx_posts_user_created 
        #     ON posts(user_id, created_at DESC)
        # """))
        
        print('Database reinitialized with current schema and performance indexes')

target_metadata = SQLModel.metadata
