"""Demo bearer-token auth. Empty KAIROS_API_TOKEN disables auth (local dev only)."""

from __future__ import annotations

import secrets

from fastapi import Depends, HTTPException, WebSocket, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import Settings, get_settings

_bearer = HTTPBearer(auto_error=False)


def _matches(expected: str, given: str | None) -> bool:
    return not expected or (given is not None and secrets.compare_digest(expected, given))


def require_token(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    settings: Settings = Depends(get_settings),
) -> None:
    if not _matches(settings.api_token, creds.credentials if creds else None):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or missing token")


def websocket_authorised(ws: WebSocket, settings: Settings) -> bool:
    return _matches(settings.api_token, ws.query_params.get("token"))
