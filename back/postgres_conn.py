from sqlmodel import SQLModel, Field, Relationship, Column, Integer, String, JSON, func, select, UniqueConstraint, ARRAY, UUID, BigInteger, Boolean, ForeignKey
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.dialects.postgresql import TSVECTOR
from pgvector.sqlalchemy import Vector
from sqlalchemy import DateTime, event, text, Index, PrimaryKeyConstraint
from datetime import datetime
from typing import List, Optional
from enum import Enum

from uuid import uuid4
import os
from os import environ as env
from dotenv import load_dotenv

load_dotenv()


class UserAuth(SQLModel, table=True):
    __tablename__ = "auth_users"

    # Primary key - use auto-incrementing ID
    id: int | None = Field(default=None, primary_key=True, sa_type=BigInteger)
    
    # User reference (filled when user registers/links auth)
    user_id: int | None = Field(foreign_key='users.id', default=None, sa_type=BigInteger)
    
    # Anonymous session UUID (for unauthenticated users)
    anonymous_id: str | None = Field(default=None, index=True)
    
    # Auth methods
    username: str | None = Field(default=None, index=True)
    password_hash: str = Field(sa_column=Column(String))
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
    __table_args__ = (
        UniqueConstraint('community_id', 'user_id', name='uq_participant'),    
    )
    id: int | None = Field(default=None, sa_type=BigInteger, primary_key=True)
    
    community_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey("communities.id", ondelete="CASCADE"),
        )
    )
    user_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey('users.id', ondelete='CASCADE'),
        )
    )


class BusinessOperationsLink(SQLModel, table=True):
    __table_args__ = (
        UniqueConstraint('community_id', 'business_id', name='uq_operationslink'),
    )
    id: int | None = Field(default=None, sa_type=BigInteger, primary_key=True)
    
    community_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey("communities.id", ondelete="CASCADE"),
        )
    )
    business_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey("businesses.id", ondelete="CASCADE"),
        )
    )


class ConversationParticipant(SQLModel, table=True):
    __table_args__ = (
        PrimaryKeyConstraint('conversation_id', 'user_id'),
    )
    conversation_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey('conversations.id', ondelete='CASCADE'),
        )
    )
    user_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey('users.id', ondelete='CASCADE'),
            primary_key=True
        )
    )


class User(SQLModel, table=True):
    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("email", "username", name='uq_user'), 
    )

    id: int = Field(primary_key=True, sa_type=BigInteger)

    username: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone_number: Optional[str] = Field(index=True, unique=True)
    email: Optional[str] = Field(index=True, unique=True)
    admin: bool = Field(default=False)
    balance: int = Field(default = 0)
    image: bool = Field(default=False)

    businesses: list["Business"] = Relationship(
        back_populates="user",
        sa_relationship_kwargs={"cascade": "all, delete-orphan"}
    )
    posts: List["Post"] = Relationship(
        back_populates="user",
        sa_relationship_kwargs={"cascade": "all, delete-orphan"}
    )

    verifications: list["Verification"] = Relationship(
        back_populates="user",
        sa_relationship_kwargs={"cascade": "all, delete-orphan"}
    )

    integrations: List["Integration"] = Relationship(
        back_populates="user",
        sa_relationship_kwargs={'cascade': 'all, delete-orphan'}
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
    
    entrep: bool = Field(default=False, sa_column=Column(Boolean, default=False, nullable=False))
    suspended: bool = Field(default=False, sa_column=Column(Boolean, default=False, nullable=False))
    conversations: List["Conversation"] = Relationship(
        back_populates='participants',
        link_model=ConversationParticipant
    )
    sent_messages: List["Message"] = Relationship(back_populates='author')


class Community(SQLModel, table=True):
    __tablename__ = 'communities'
        
    id: int = Field(primary_key=True, sa_type=BigInteger)
    
    name: str = Field(index=True)
    description: str = Field()
    reddit_link: Optional[str] = Field(default=None, index=True)
    image: bool = Field(default=False)
    creator_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False
        )
    )    

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
    

    posts: List['Post'] = Relationship(
        back_populates = 'community'
    )
    businesses: List['Business'] = Relationship(
        back_populates='communities',
        link_model=BusinessOperationsLink
    )
    language: str = Field(nullable=False, max_length=32, index=True, default="english")
    search_vector: Optional[str] = Field(
        sa_column=Column(
            TSVECTOR
        )
    )

    embedding: List[float] | None = Field(
        sa_column=Column(Vector(768)),
        default = None
    ) # TODO recompute the vector each week (?) I guess


class Vote(SQLModel, table=True):
    __tablename__ = 'votes'
    __table_args__ = (
        UniqueConstraint("voter_id", "post_id", name='uq_vote'), 
    )
    
    id: int = Field(primary_key=True, sa_type=BigInteger)
    post_id: int = Field(
    sa_column=Column(
        BigInteger,
        ForeignKey("posts.id", ondelete="CASCADE"),
        nullable=False
        )
    )
    post: "Post" = Relationship(back_populates='votes')
    would_pay: float | None = Field(default=None, nullable=True)
    competition: str | None = Field(default=None, nullable=True)
    problems: str | None = Field(default=None, nullable=True)
    voter_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False
        )
    )

    embedding: List[float] | None = Field(
        sa_column = Column(Vector(768)),
        default = None
    )


class Post(SQLModel, table=True):
    __tablename__ = 'posts'
    
    id: int = Field(primary_key=True, sa_type=BigInteger)

    name: str = Field()
    contents: str = Field()
    image: bool = Field(default=False)

    votes: List[Vote] = Relationship(back_populates='post')
    created_at: datetime = Field(
        sa_column=Column(
            DateTime(timezone=True),
            server_default=func.now(),
            nullable=False,
        )
    )

    community_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey("communities.id", ondelete="CASCADE"),
            nullable=False
        )
    )
    community: Community = Relationship(
        back_populates = 'posts'
    )
    user_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey('users.id', ondelete='CASCADE'),
            nullable=False
        )
    )
    user: User = Relationship(
        back_populates='posts'
    )

    language: str = Field(nullable=False, max_length=32, index=True, default="english")
    search_vector: Optional[str] = Field(
        sa_column=Column(
            TSVECTOR
        )
    )

    embedding: List[float] = Field(
        sa_column = Column(Vector(768))
    )


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
    cont_goal: str | None
    reaction_time: int | None
    image: bool = Field(default=False)

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

    embedding: List[float] = Field(
        sa_column = Column(Vector(768))
    )


class Connection(SQLModel, table=True):
    __tablename__ = 'connections'

    id: int = Field(primary_key=True, sa_type=BigInteger)

    requester_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey('users.id', ondelete='CASCADE')
        )
    )
    contact_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey('users.id', ondelete='SET NULL')
        )
    )

    created_at: datetime = Field(
        sa_column=Column(DateTime(timezone=True), server_default=func.now())
    )


class Conversation(SQLModel, table=True):
    __tablename__ = 'conversations'

    id: int = Field(primary_key=True, sa_type=BigInteger)

    created_at: datetime = Field(
        sa_column=Column(DateTime(timezone=False), server_default=func.now())
    )

    participants: List[User] = Relationship(
        back_populates='conversations',
        link_model=ConversationParticipant
    )
    messages: List['Message'] = Relationship(
        back_populates='conversation'
    )
    

class Message(SQLModel, table=True):
    __tablename__='messages'

    id: int = Field(primary_key=True, sa_type=BigInteger)
    content: str = Field(sa_column=Column(String))
    conversation_id: int = Field(
        sa_column = Column(
            BigInteger,
            ForeignKey('conversations.id', ondelete='CASCADE'),
        )
    )
    author_id: int = Field(
        sa_column = Column(
            BigInteger,
            ForeignKey('users.id', ondelete='CASCADE')
        )
    )
    created_at: datetime = Field(
        sa_column=Column(
            DateTime(timezone=True),
            server_default=func.now(),
            nullable=False,
        )
    )
    conversation: Conversation = Relationship(back_populates='messages')
    author: User = Relationship(back_populates='sent_messages')


class Integration(SQLModel, table=True):
    __tablename__ = 'integrations'
    __table_args__ = (
        UniqueConstraint(
            "provider",
            "account_id",
            name="uq_provider_account"
        ),
    )

    id: int = Field(primary_key=True, sa_type=BigInteger)

    user_id: int = Field(default=None, primary_key=True)

    provider: str = Field(index=True)
    account_id: str = Field(index=True)

    access_token: str = Field(sa_column=Column(String))
    refresh_token: Optional[str] = None

    expires_at: Optional[datetime] = None
    scope: Optional[str] = None

    created_at: datetime = Field(
        sa_column=Column(
            DateTime(timezone=False),
            server_default=func.now(),
            nullable=False
        )
    )

    user_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey('users.id', ondelete='CASCADE')
        )
    )
    user: Optional["User"] = Relationship(back_populates="integrations")


class RedFlagIntent(SQLModel, table=True):
    id: int = Field(primary_key=True, sa_type=BigInteger)

    label: str = Field(sa_column=Column(String))
    embedding: List[float] = Field(sa_column=Column(Vector(768)))

    
class PostAnalysisRequest(SQLModel, table=True):
    __tablename__ = 'post_analysis_requests'

    id: int = Field(primary_key=True, sa_type=BigInteger)
    processing: bool = Field(default=False)
    full_analysis: bool = Field(default=True)

    user_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey('users.id', ondelete='CASCADE'),
        )
    )

    post_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey('posts.id', ondelete='CASCADE')
        )
    )

    created_at: datetime = Field(
        sa_column=Column(
            DateTime(timezone=False),
            server_default=func.now(),
            nullable=False,
            index=True
        )
    )


class PostAnalysis(SQLModel, table=True):
    __tablename__ = 'post_analysies'

    id: int = Field(primary_key=True, sa_type=BigInteger)

    user_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey('users.id', ondelete='CASCADE'),
        )
    )

    post_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey('posts.id', ondelete='CASCADE'),
        )
    )

    Y: str | None = None
    Z: str | None = None
    U: str | None = None
    additional: str | None = None

    started_working: datetime = Field(
        sa_column=Column(
            DateTime(timezone=False),
            server_default=func.now(),
            nullable=False
        )
    )

    created_at: datetime = Field(
        sa_column=Column(
            DateTime(timezone=False),
            server_default=func.now(),
            nullable=False
        )
    )


class Feedback(SQLModel, table=True):
    __tablename__ = 'feedbacks'

    id: int = Field(primary_key=True, sa_type=BigInteger)

    user_id: int = Field(
        sa_column=Column(
            BigInteger,
            ForeignKey('users.id', ondelete='CASCADE')
        )
    )
    contents: str = Field(sa_column=Column(String))

    created_at: datetime = Field(
        sa_column=Column(
            DateTime(timezone=False),
            server_default=func.now(),
            nullable=False
        )
    )    

# class RefreshToken(SQLModel, table=True):
#     __tablename__ = 'refresh_tokens'

#     id: int = Field(primary_key=True, sa_type=BigInteger)

#     is_revoked: bool = Field(default=False)
#     jti: str = Field(sa_column=Column(String))
#     token: str = Field(sa_column=Column(String))
#     created_at: datetime = Field(
#         sa_column=Column(
#             DateTime(timezone=False),
#             server_default=func.now(),
#             nullable=False
#         )
#     )
#     expires_at: datetime = Field()
#     user_id: int = Field(
#         sa_column=Column(
#             BigInteger,
#             ForeignKey('user.id', ondelete='CASCADE'),
#         )
#     )
    
    
###

def get_database_url():
    return f"postgresql+asyncpg://{os.getenv('POSTGRES_USERNAME')}:{os.getenv('POSTGRES_PASSWORD')}@{os.getenv('POSTGRES_HOST')}:{os.getenv('POSTGRES_PORT')}/postgres"

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


def create_post_search_trigger(conn):
    conn.execute(text(
        "DROP TRIGGER IF EXISTS update_post_search_vector ON posts"
    ))
    conn.execute(text(
        "DROP FUNCTION IF EXISTS post_search_vector_trigger()"
    ))

    conn.execute(text("""
        CREATE OR REPLACE FUNCTION post_search_vector_trigger()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.search_vector :=
                to_tsvector(
                    COALESCE(NEW.language, 'english')::regconfig,
                    COALESCE(NEW.name || ' ' || NEW.contents, '')
                );
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
    """))

    conn.execute(text("""
        CREATE TRIGGER update_post_search_vector
        BEFORE INSERT OR UPDATE OF name, contents, language
        ON posts
        FOR EACH ROW
        EXECUTE FUNCTION post_search_vector_trigger()
    """))


def create_community_search_trigger(conn):
    conn.execute(text(
                     "DROP TRIGGER IF EXISTS update_community_search_vector ON communities"
                 ))
    conn.execute(text(
                     "DROP FUNCTION IF EXISTS community_search_vector_trigger()"
                 ))

    conn.execute(text("""
        CREATE OR REPLACE FUNCTION community_search_vector_trigger()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.search_vector :=
                    to_tsvector(
                        COALESCE(NEW.language, 'english')::regconfig,
                        COALESCE(NEW.name || ' ' || NEW.description, '')
                    );
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
        """))

    conn.execute(text("""
            CREATE TRIGGER update_community_search_vector
            BEFORE INSERT OR UPDATE OF name, description, language
            ON communities
            FOR EACH ROW
            EXECUTE FUNCTION community_search_vector_trigger()            
        """))


def install_pgvector(conn):
    result = conn.execute(text(
                     "SELECT extname FROM pg_extension WHERE extname = 'vector';"
                 ))
    extension_exists = result.first()

    if not extension_exists:
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector;"))
        conn.commit()


async def init_db():
    async with engine.begin() as conn:
        # Drop all tables first to ensure clean schema
        # await conn.run_sync(SQLModel.metadata.drop_all)
        await conn.run_sync(install_pgvector)
        # await conn.run_sync(SQLModel.metadata.create_all)
        await conn.run_sync(create_post_search_trigger)
        await conn.run_sync(create_community_search_trigger)
        
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
