import os
import logging
import secrets
from fastapi import Depends, HTTPException, APIRouter, Request 
from fastapi.responses import JSONResponse, RedirectResponse, HTMLResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from authx import AuthX, AuthXConfig, TokenPayload
from pwdlib import PasswordHash
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import Optional
from uuid import uuid4
from datetime import datetime, timezone
from schemas import *
from postgres_conn import User, UserAuth, get_db, Integration
from valkey_conn import valkey_client
from authlib.integrations.starlette_client import OAuth
import httpx
# from utils import *


oauth = OAuth()

JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "qwertyuiop")
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET", "")
GOOGLE_REDIRECT_URI = os.getenv("GOOGLE_REDIRECT_URI", "")


oauth.register(
    name="google",
    client_id=GOOGLE_CLIENT_ID,
    client_secret=GOOGLE_CLIENT_SECRET,
    server_metadata_url="https://accounts.google.com/.well-known/openid-configuration",
    client_kwargs={
        "scope": "openid email profile https://www.googleapis.com/auth/drive.readonly"
    },
    authorize_params={
        "access_type": "offline",
        "prompt": "consent"
    }
)


config = AuthXConfig(
    JWT_SECRET_KEY=JWT_SECRET_KEY,
    JWT_TOKEN_LOCATION=["headers"],
    JWT_ALGORITHM="HS256",
    JWT_ACCESS_TOKEN_EXPIRES=60 * 15,
    JWT_REFRESH_TOKEN_EXPIRES=60 * 60 * 24 * 7,
)

auth = AuthX(config=config)


async def get_anonymous_id_from_token(
    payload: TokenPayload = Depends(auth.access_token_required)
) -> str:
    """Validate token and return anonymous_id (for registration endpoints).
    This is stateless - just validates the JWT signature."""
    sub = payload.sub
    
    if sub.isdigit():
        raise HTTPException(status_code=400, detail="Already registered")
    
    return sub


async def get_user_id_from_token(
    payload: TokenPayload = Depends(auth.access_token_required),
    db: AsyncSession = Depends(get_db)
) -> int:
    """Get user_id from token, handling both authenticated and anonymous tokens."""
    sub = payload.sub
    
    if sub.isdigit():
        return int(sub)
    else:
        result = await db.execute(select(UserAuth).where(UserAuth.anonymous_id == sub))
        user_auth = result.scalars().first()
        if not user_auth or not user_auth.user_id:
            raise HTTPException(status_code=401, detail="User not found")
        return user_auth.user_id


async def ai_token_required(
    payload: TokenPayload = Depends(auth.access_token_required),
):
    sub = payload

password_hasher = PasswordHash.recommended()

router = APIRouter(prefix="/api/auth", tags=["auth"])
security = HTTPBearer(auto_error=False)


def hash_password(password: str) -> str:
    hash = password_hasher.hash(password)
    logging.warning(hash)
    return hash


def verify_password(password: str, hashed_password: str) -> bool:
    return password_hasher.verify(password, hashed_password)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str


# async def get_current_user(
#     credentials: HTTPAuthorizationCredentials = Depends(security),
#     db: AsyncSession = Depends(get_db),
# ) -> User:
#     token = credentials.credentials
#     try:
#         payload = auth.token_decode(token)
#         user_id = payload.get("sub")
#         if not user_id:
#             raise HTTPException(status_code=401, detail="Invalid token")

#         result = await db.execute(select(User).where(User.id == int(user_id)))
#         user = result.scalars().first()

#         if not user:
#             raise HTTPException(status_code=401, detail="User not found")

#         return user
#     except Exception as e:
#         logging.error(f"Token validation error: {e}")
#         raise HTTPException(status_code=401, detail="Invalid or expired token")


def create_tokens(user_id: int | None = None, anonymous_id: str | None = None) -> dict[str, str]:
    """Create tokens. Use user_id for authenticated users, anonymous_id for anonymous."""
    
    if user_id:
        token_uid = str(user_id)
    elif anonymous_id:
        token_uid = anonymous_id
    else:
        raise ValueError("Either user_id or anonymous_id must be provided")
    
    access_token = auth.create_access_token(uid=token_uid)
    refresh_token = auth.create_refresh_token(uid=token_uid)

    logging.warning(access_token)

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
    }


def create_user_tokens(user_id: int) -> tuple[str, str]:
    """Create authenticated tokens with user_id (after registration)"""
    access_token = auth.create_access_token(uid=str(user_id))
    refresh_token = auth.create_refresh_token(uid=str(user_id))
    return (access_token, refresh_token)


def validate_refresh() -> bool:
    pass


def revoke_old_refresh() -> None:
    pass


@router.post("/login", response_model=TokenResponse)
async def login(req: AuthRequest, db: AsyncSession = Depends(get_db)):
    query_conditions = []
    if req.username:
        query_conditions.append(UserAuth.username == req.username)
    if req.email:
        query_conditions.append(UserAuth.email == req.email)
    if req.phone:
        query_conditions.append(UserAuth.phone == str(req.phone))
    
    if not query_conditions:
        raise HTTPException(
            status_code=400, detail="Username, email, or phone required"
        )


    result = await db.execute(select(UserAuth).where(*query_conditions))
    user_auth = result.scalars().first()

    if not user_auth or not verify_password(req.password, user_auth.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    result = await db.execute(select(User).where(User.id == user_auth.user_id))
    user = result.scalars().first()

    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")

    access_token = auth.create_access_token(uid=str(user.id))
    refresh_token = auth.create_refresh_token(uid=str(user.id))

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


async def revoke_all_user_refresh_tokens(user_id: str, db: AsyncSession):
    try:
        await db.execute(
            update(models.RefreshToken)
            .where(models.RefreshToken.user_id == user_id)
            .values(is_revoked=True)
        )
        await db.commit()
        logger.warning(f"All refresh tokens revoked for user {user_id} due to token reuse attempt")
    except SQLAlchemyError as e:
        await db.rollback()
        logger.error(f"Failed to revoke all tokens for user {user_id}: {e}")
        raise


@router.post("/refresh", response_model=TokenResponse)
async def refresh(
    req: RefreshRequest,
    db: AsyncSession = Depends(get_db),
):
    try:
        payload = auth.token_decode(req.refresh_token)
        user_id = payload.get("sub")
        token_jti = payload.get("jti")  # уникальный идентификатор токена

        if not user_id or not token_jti:
            raise HTTPException(401, "Invalid token payload")

        # 2. Ищем текущий refresh token в базе
        result = await db.execute(
            select(models.RefreshToken)
            .where(
                models.RefreshToken.jti == token_jti,
                models.RefreshToken.user_id == user_id
            )
        )
        db_token = result.scalars().first()

        # 3. Проверяем существование и состояние
        if not db_token:
            # Токен не найден → возможно украден или подделан
            await revoke_all_user_refresh_tokens(user_id, db)
            raise HTTPException(401, "Invalid refresh token")

        if db_token.is_revoked:
            # Reuse попытка → компрометация → отзываем ВСЕ токены пользователя
            await revoke_all_user_refresh_tokens(user_id, db)
            raise HTTPException(401, "Token reuse detected — session terminated")

        # 4. Помечаем текущий токен как использованный (ротация)
        db_token.is_revoked = True

        # 5. Генерируем новую пару токенов
        new_access_token = auth.create_access_token(uid=user_id)
        new_refresh_token = auth.create_refresh_token(uid=user_id)

        # 6. Сохраняем новый refresh token
        new_db_token = models.RefreshToken(
            jti=auth.get_jti(new_refresh_token),  # если у тебя есть такая функция
            token=new_refresh_token,              # или хранишь хэш — лучше хэш
            user_id=user_id,
            expires_at=auth.get_refresh_expires_at(),  # опционально
            is_revoked=False
        )
        db.add(new_db_token)

        await db.commit()

        return schemas.TokenResponse(
            access_token=new_access_token,
            refresh_token=new_refresh_token
        )
    except Exception as e:
        logging.error(f"Refresh token error: {e}")
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")


@router.get("/google/start")
async def google_start(request: Request, entrep: bool = False):

    anonymous_id = request.query_params.get("anonymous_id", "")
    logging.warning(f"Google OAuth start - anonymous_id from query: {anonymous_id}, entrep: {entrep}")
    
    state = f"{anonymous_id}|entrep={entrep}" if anonymous_id else f"entrep={entrep}"
    
    redirect_uri = "https://serveyourcommunity.ftp.sh/api/auth/google/callback"
    logging.warning(f"Google OAuth redirect_uri: {redirect_uri}")

    return await oauth.google.authorize_redirect(
        request,
        redirect_uri = redirect_uri,
        state = state
    )


@router.get("/google/callback")
async def google_callback(
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    try:
        logging.warning(f"QUERY: {dict(request.query_params)}")
        
        all_query = dict(request.query_params)
        state_param = all_query.get('state', '')
        
        anonymous_id = None
        entrep = False
        if state_param:
            parts = state_param.split('|')
            for part in parts:
                if part.startswith('entrep='):
                    entrep = part.split('=')[1].lower() == 'true'
                else:
                    anonymous_id = part
        
        logging.warning(f"Full query: {all_query}")
        logging.warning(f"State param: '{state_param}', Anonymous ID: '{anonymous_id}', entrep: {entrep}")
        
        token = await oauth.google.authorize_access_token(request)
        google_access_token = token["access_token"]
        google_refresh_token = token.get("refresh_token")

        async with httpx.AsyncClient() as client:
            r = await client.get(
                "https://www.googleapis.com/oauth2/v2/userinfo",
                headers={"Authorization": f"Bearer {google_access_token}"}
            )
            r.raise_for_status()
            user_info = r.json()

        email = user_info["email"]
        google_id = user_info["id"]
        given_name = user_info.get('given_name')
        family_name = user_info.get('family_name')
        picture = user_info.get('picture')

        logging.warning(f"Google OAuth: email={email}, given_name={given_name}, family_name={family_name}")

        # Check by anonymous_id first (if provided in OAuth state)
        existing_user = None
        if anonymous_id:
            result = await db.execute(select(UserAuth).where(UserAuth.anonymous_id == anonymous_id))
            existing_auth_by_anon = result.scalars().first()
            if existing_auth_by_anon and existing_auth_by_anon.user_id:
                result = await db.execute(select(User).where(User.id == existing_auth_by_anon.user_id))
                existing_user = result.scalars().first()
                if existing_user:
                    logging.warning(f"Found existing user by anonymous_id: {existing_user.id}")
        
        # If not found by anonymous_id, check by email
        if not existing_user:
            result = await db.execute(select(User).where(User.email == email))
            existing_user = result.scalars().first()

        # Also check UserAuth by email as fallback
        result = await db.execute(
            select(UserAuth).where(UserAuth.email == email)
        )
        existing_auth_by_email = result.scalars().first()

        # Also check UserAuth by anonymous_id
        existing_auth_by_anon = None
        if anonymous_id:
            result = await db.execute(
                select(UserAuth).where(UserAuth.anonymous_id == anonymous_id)
            )
            existing_auth_by_anon = result.scalars().first()
        else:
            existing_auth_by_anon = None

        user_id: int
        if existing_user:
            # Use existing user
            user_id = existing_user.id
            logging.warning(f"Existing user found: id={user_id}, first_name={existing_user.first_name}, username={existing_user.username}")
            # Update user profile with Google data (always prefer real data over placeholders)
            needs_update = False
            placeholder_names = {"New User", "User", None, ""}
            if existing_user.first_name in placeholder_names and given_name:
                existing_user.first_name = given_name
                needs_update = True
            if existing_user.last_name in placeholder_names and family_name:
                existing_user.last_name = family_name
                needs_update = True
            if existing_user.username in placeholder_names or (existing_user.username and existing_user.username.startswith("user_")):
                if email:
                    try:
                        existing_user.username = email.split('@')[0]
                    except:
                        existing_user.username = f"user_{existing_user.id}"
                    needs_update = True
            # Only set email if not already set OR if current email is placeholder
            if existing_user.email in placeholder_names and email:
                # Check if email is already used by another user
                result = await db.execute(select(User).where(User.email == email, User.id != existing_user.id))
                other_user_with_email = result.scalars().first()
                if not other_user_with_email:
                    existing_user.email = email
                    needs_update = True
            if entrep and not existing_user.entrep:
                existing_user.entrep = True
                needs_update = True
            if needs_update:
                await db.commit()
        elif existing_auth_by_anon and existing_auth_by_anon.user_id:
            # Found existing user by anonymous_id in UserAuth
            user_id = existing_auth_by_anon.user_id
            result = await db.execute(select(User).where(User.id == user_id))
            existing_user = result.scalars().first()
            if existing_user:
                # Only set email if not already used by another user
                if not existing_user.email:
                    result = await db.execute(select(User).where(User.email == email, User.id != user_id))
                    other_user_with_email = result.scalars().first()
                    if not other_user_with_email:
                        existing_user.email = email
                if not existing_user.first_name and given_name:
                    existing_user.first_name = given_name
                if not existing_user.last_name and family_name:
                    existing_user.last_name = family_name
                if not existing_user.username and email:
                    existing_user.username = email.split('@')[0] if '@' in email else f"user_{user_id}"
                await db.commit()
                logging.warning(f"Updated existing user by anonymous_id: {user_id}")
        elif existing_auth_by_email and existing_auth_by_email.user_id:
            # User has UserAuth but no email in User table - use existing user
            user_id = existing_auth_by_email.user_id
            result = await db.execute(select(User).where(User.id == user_id))
            existing_user = result.scalars().first()
            if existing_user:
                # Only set email if not already used by another user
                if not existing_user.email:
                    result = await db.execute(select(User).where(User.email == email, User.id != user_id))
                    other_user_with_email = result.scalars().first()
                    if not other_user_with_email:
                        existing_user.email = email
                if not existing_user.first_name and given_name:
                    existing_user.first_name = given_name
                if not existing_user.last_name and family_name:
                    existing_user.last_name = family_name
                await db.commit()
        else:
            # Create new user
            username_from_email = None
            if email and '@' in email:
                username_from_email = email.split('@')[0]
            
            new_user = User(
                email=email,
                username=username_from_email or f"user_{email[:8]}" if email else "new_user",
                first_name=given_name if given_name else "User",
                last_name=family_name,
                entrep=entrep,
            )
            db.add(new_user)
            await db.flush()
            await db.commit()
            await db.refresh(new_user)
            user_id = new_user.id
            logging.warning(f"Created new user: id={user_id}")

        # Create or update UserAuth record for Google login
        # First check if there's an existing UserAuth with the same email (from anonymous login)
        result = await db.execute(
            select(UserAuth).where(UserAuth.email == email)
        )
        existing_auth_by_email = result.scalars().first()
        
        if existing_auth_by_email and existing_auth_by_email.google is None:
            # User had anonymous account, link Google to it
            existing_auth_by_email.google = google_id
            existing_auth_by_email.user_id = user_id
            await db.commit()
            # Also update the User record if it was created newly
            if not existing_user:
                # Delete the newly created user since we're using existing one
                await db.delete(new_user)
                user_id = existing_auth_by_email.user_id
        else:
            # Check if UserAuth with google exists
            result = await db.execute(
                select(UserAuth).where(UserAuth.google == google_id)
            )
            existing_auth = result.scalars().first()

            if existing_auth:
                # Update existing UserAuth with user_id if not set
                if not existing_auth.user_id:
                    existing_auth.user_id = user_id
                    existing_auth.email = email
                    await db.commit()
            else:
                # Create new UserAuth for Google user
                user_auth = UserAuth(
                    user_id=user_id,
                    google=google_id,
                    email=email,
                    password_hash="",  # No password for Google users
                )
                db.add(user_auth)
            await db.commit()

        # Check integration
        result = await db.execute(
            select(Integration).where(
                Integration.user_id == user_id,
                Integration.provider == "google",
                Integration.account_id == google_id
            )
        )
        existing_integration = result.scalars().first()

        if existing_integration:
            existing_integration.access_token = google_access_token
            existing_integration.refresh_token = google_refresh_token
            existing_integration.expires_at = None
            await db.commit()
        else:
            integration = Integration(
                user_id=user_id,
                provider="google",
                account_id=google_id,
                access_token=google_access_token,
                refresh_token=google_refresh_token,
                expires_at=None,
                scopes="drive.readonly"
            )
            db.add(integration)
            await db.commit()

        # App tokens
        app_access_token, app_refresh_token = create_user_tokens(user_id)

        # Redirect to Flutter app's auth handler with tokens
        success_url = f"https://serveyourcommunity.ftp.sh/auth?access_token={app_access_token}&refresh_token={app_refresh_token}&user_id={user_id}"
        
        return RedirectResponse(url=success_url)

    except Exception as e:
        logging.error(f"Google OAuth callback error: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Google OAuth integration failed: {e}"
        )


@router.get("/oauth/callback", response_class=HTMLResponse)
async def oauth_callback(
    access_token: str,
    refresh_token: str,
    user_id: int
):
    """OAuth callback - stores tokens and shows success message"""
    
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Logging in... | Serve App</title>
        <style>
            body {{
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background: #1a1a1a;
                color: white;
                display: flex;
                align-items: center;
                justify-content: center;
                min-height: 100vh;
                margin: 0;
            }}
            .container {{ text-align: center; }}
            .spinner {{
                border: 4px solid #333;
                border-top: 4px solid #4ade80;
                border-radius: 50%;
                width: 40px;
                height: 40px;
                animation: spin 1s linear infinite;
                margin: 0 auto 20px;
            }}
            @keyframes spin {{ 0% {{ transform: rotate(0deg); }} 100% {{ transform: rotate(360deg); }} }}
        </style>
        <script>
            // Store tokens in localStorage
            localStorage.setItem('auth_token', '{access_token}');
            localStorage.setItem('refresh_token', '{refresh_token}');
            localStorage.setItem('user_id', '{user_id}');
            
            // Redirect to home
            setTimeout(() => {{
                window.location.href = '/#/home';
            }}, 500);
        </script>
    </head>
    <body>
        <div class="container">
            <div class="spinner"></div>
            <p>Logging you in...</p>
        </div>
    </body>
    </html>
    """
    
    return html

def generate_code() -> str:
    ALPHABET = "QWERTYUOP23456789ASDFGHJKL"
    code = "".join(secrets.choice(ALPHABET) for _ in range(6))
    return code


@router.post('/send_codes/email')
async def send_2fa_codes_em(
    req: SendCodesEmailRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail=f'User not found')
    code = generate_code()
    message = f"Hello, {user.username}, your email verfication code is:\n{code}\nIt expires in 10 minutes. Please do not expose it to anyone"
    await valkey_client.save_code_with_timeout(user_id, code)
    await send_email(user.email, message)


@router.post('/send_codes/phone')
async def send_2fa_codes_ph(
    req: SendCodesPhoneRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    code = generate_code()


@router.post('/check_codes')
async def check_2fa_codes(
    req: CheckCodeRequest,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_user_id_from_token)
):
    pass
