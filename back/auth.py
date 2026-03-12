import os
import logging
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
from authlib.integrations.starlette_client import OAuth
import httpx
from utils import *


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


async def get_user_id_from_token(
    payload: TokenPayload = Depends(auth.access_token_required),
    db: AsyncSession = Depends(get_db)
) -> int:
    """Get user_id from token, handling both authenticated and anonymous tokens."""
    sub = payload.sub
    
    if sub.isdigit():
        # Authenticated token - contains user_id
        return int(sub)
    else:
        # Anonymous token - contains device_id, look up user
        result = await db.execute(select(User).where(User.device_id == sub))
        user = result.scalars().first()
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        return user.id

password_hasher = PasswordHash.recommended()

router = APIRouter(prefix="/auth", tags=["auth"])
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


def create_tokens(user_id: int | None, device_id: str) -> dict[str, str]:
    now = datetime.now(timezone.utc)

    common_claims = {
        "uid": user_id,
        "device_id": device_id,
        "iat": now,
    }

    # Use device_id for anonymous tokens (before registration)
    token_uid = device_id
    
    access_token = auth.create_access_token(
        uid=token_uid,
        # data=common_claims,
    )

    refresh_token = auth.create_refresh_token(
        uid=token_uid,
        # data=common_claims,
    )

    return (
        access_token,
        refresh_token,
    )


def create_user_tokens(user_id: int) -> tuple[str, str]:
    """Create authenticated tokens with user_id (after registration)"""
    access_token = auth.create_access_token(uid=str(user_id))
    refresh_token = auth.create_refresh_token(uid=str(user_id))
    return (access_token, refresh_token)


def validate_refresh() -> bool:
    pass


def revoke_old_refresh() -> None:
    pass


@router.post("/devicelogin")
async def device_login(req: DeviceLoginRequest, db: AsyncSession = Depends(get_db)):
    # check if exists in auth users
    # if doesn't exist, create a record
    # then create access and refresh tokens
    result = await db.execute(select(User).where(User.device_id == req.device_id))
    ex_user = result.scalars().first()
    if not ex_user:
        # create record
        try:
            ex_user = User(device_id=req.device_id)
            db.add(ex_user)
            await db.flush()
            # probably set up a cronjob later that would delete 'empty' User-s
            await db.commit()
            await db.refresh(ex_user)

        except Exception as e:
            logging.error(f"Could not record new auth:\n\n{e}")
            raise HTTPException(status_code=500, detail=f"Error: {e}")

    # create tokens
    access, refresh = create_tokens(user_id=ex_user.id, device_id=ex_user.device_id)
    logging.debug(access)

    return {
        "access_token": access,
        "refresh_token": refresh,
    }


@router.post("/login", response_model=TokenResponse)
async def login(req: AuthRequest, db: AsyncSession = Depends(get_db)):
    query_conditions = []
    if req.username:
        query_conditions.append(UserAuth.username == req.username)
    if req.email:
        query_conditions.append(UserAuth.email == req.email)
    if req.phone:
        query_conditions.append(UserAuth.phone == str(req.phone))

    query_conditions.append(UserAuth.device_id == req.device_id)
    
    if not query_conditions:
        raise HTTPException(
            status_code=400, detail="Username, email, or phone required"
        )

    # validate
    if not red_flags_check(f'{req.email} {req.username}'):
        raise HTTPException(
            status_code=401, detail='Moderation not passed'
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


@router.post("/refresh", response_model=TokenResponse)
async def refresh(req: RefreshRequest):
    try:
        payload = auth.token_decode(req.refresh_token)
        user_id = payload.get("sub")

        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid refresh token")

        access_token = auth.create_access_token(uid=user_id)
        refresh_token = auth.create_refresh_token(uid=user_id)

        return TokenResponse(access_token=access_token, refresh_token=refresh_token)
    except Exception as e:
        logging.error(f"Refresh token error: {e}")
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")


@router.get("/google/start")
async def google_start(request: Request):

    redirect_uri = request.url_for("google_callback")

    return await oauth.google.authorize_redirect(
        request,
        redirect_uri = "https://serve-back.ftp.sh/auth/google/callback"
    )


@router.get("/google/callback")
async def google_callback(
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    try:
        logging.warning(f"QUERY: {dict(request.query_params)}")
        
        token = await oauth.google.authorize_access_token(request)
        google_access_token = token["access_token"]
        google_refresh_token = token.get("refresh_token")

        # User info
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

        # Ensure user exists
        result = await db.execute(select(User).where(User.email == email))
        existing_user = result.scalars().first()

        user_id: int
        if existing_user:
            user_id = existing_user.id
            # Update user profile with Google data if fields are empty
            needs_update = False
            if not existing_user.first_name and given_name:
                existing_user.first_name = given_name
                needs_update = True
            if not existing_user.last_name and family_name:
                existing_user.last_name = family_name
                needs_update = True
            if not existing_user.username and email:
                existing_user.username = email[:email.index('@')]
                needs_update = True
            if needs_update:
                await db.commit()
        else:
            new_user = User(
                email=email,
                username=email[:email.index('@')],
                first_name=given_name,
                last_name=family_name,
            )
            db.add(new_user)
            await db.flush()
            await db.commit()
            await db.refresh(new_user)
            user_id = new_user.id

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

        # Redirect to web page with success + button to open app
        success_url = f"https://serve-back.ftp.sh/auth/google/success?access_token={app_access_token}&refresh_token={app_refresh_token}&user_id={user_id}"
        
        return RedirectResponse(url=success_url)

    except Exception as e:
        logging.error(f"Google OAuth callback error: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Google OAuth integration failed: {e}"
        )


@router.get("/google/success", response_class=HTMLResponse)
async def google_success(
    access_token: str,
    refresh_token: str,
    user_id: int
):
    """Web page shown after Google OAuth - has button to open app"""
    
    # Use Universal Link (works on iOS/Android when app is installed)
    deep_link_url = f"https://serve-back.ftp.sh/auth?access_token={access_token}&refresh_token={refresh_token}&user_id={user_id}"
    
    # Fallback to custom scheme (works on Android with intent-filter)
    fallback_url = f"serve-app://auth?access_token={access_token}&refresh_token={refresh_token}&user_id={user_id}"
    
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Success! | Serve App</title>
        <style>
            body {{
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background: #1a1a1a;
                color: white;
                margin: 0;
                padding: 20px;
                text-align: center;
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                min-height: 100vh;
            }}
            .container {{
                max-width: 400px;
            }}
            .checkmark {{
                font-size: 64px;
                margin-bottom: 20px;
            }}
            h1 {{
                font-size: 28px;
                margin-bottom: 10px;
                color: #4ade80;
            }}
            p {{
                color: #aaa;
                margin-bottom: 30px;
            }}
            .btn {{
                display: inline-block;
                background: #4ade80;
                color: #000;
                padding: 16px 32px;
                border-radius: 12px;
                text-decoration: none;
                font-weight: bold;
                font-size: 18px;
                margin: 10px;
                cursor: pointer;
                border: none;
            }}
            .btn:hover {{
                background: #22c55e;
            }}
            .btn-secondary {{
                background: #444;
                color: white;
            }}
            .btn-secondary:hover {{
                background: #555;
            }}
            .footer {{
                margin-top: 40px;
                color: #666;
                font-size: 12px;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="checkmark">✅</div>
            <h1>Success!</h1>
            <p>Your Google account has been linked.</p>
            
            <button class="btn" id="openAppBtn">Open Serve App</button>
            <br>
            <a href="https://serve-back.ftp.sh" class="btn btn-secondary">Continue on Web</a>
            
            <div class="footer">
                <p>If the app doesn't open, make sure the app is installed.</p>
            </div>
        </div>
        
        <script>
            const universalLink = '{deep_link_url}';
            const fallbackLink = '{fallback_url}';
            const btn = document.getElementById('openAppBtn');
            
            btn.addEventListener('click', function() {{
                // Try Universal Link first (works on iOS/Android with app)
                window.location.href = universalLink;
                
                // After delay, try fallback (Android custom scheme)
                setTimeout(function() {{
                    window.location.href = fallbackLink;
                }}, 1500);
            }});
            
            // Try Universal Link immediately on page load
            setTimeout(function() {{
                window.location.href = universalLink;
            }}, 500);
        </script>
    </body>
    </html>
    """
    
    return html

@router.post('/send_codes')
async def send_2fa_codes():
    pass


@router.post('/check_codes')
async def check_2fa_codes():
    pass
