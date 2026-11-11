from fastapi import Header, HTTPException
from supabase import create_client
from .config import settings

async def get_user_claims(authorization: str | None = Header(default=None)):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="A Supabase access token is required.")
    token = authorization.split(" ", 1)[1]
    if not settings.supabase_url or not settings.supabase_service_role_key:
        raise HTTPException(status_code=503, detail="Supabase server configuration is missing.")
    try:
        # Ask Supabase Auth to validate the access token; do not trust decoded, unsigned JWT claims.
        client = create_client(settings.supabase_url, settings.supabase_service_role_key)
        response = client.auth.get_user(token)
        if not response or not response.user:
            raise HTTPException(status_code=401, detail="Invalid or expired access token.")
        return {"sub": str(response.user.id), "email": response.user.email}
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired access token.")
