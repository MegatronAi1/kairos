"""Feedback from operators and managers, appended to a JSON-lines file (no admin UI)."""

from __future__ import annotations

import asyncio
import time
import uuid
from typing import Literal

import orjson
from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.core.logging import log
from app.core.security import require_token
from app.state import AppState, get_state

router = APIRouter(prefix="/feedback", tags=["feedback"], dependencies=[Depends(require_token)])

_lock = asyncio.Lock()


class FeedbackIn(BaseModel):
    category: Literal["bug", "idea", "data", "other"] = "other"
    rating: int | None = Field(default=None, ge=1, le=5)
    message: str = Field(min_length=1, max_length=2000)
    source: Literal["web", "pager"] = "web"
    reactor_id: str | None = Field(default=None, max_length=32)
    page: str | None = Field(default=None, max_length=200)
    user: str | None = Field(default=None, max_length=120)


class FeedbackAck(BaseModel):
    id: str
    received_at: int


@router.post("", response_model=FeedbackAck, status_code=201)
async def submit(body: FeedbackIn, state: AppState = Depends(get_state)) -> FeedbackAck:
    ack = FeedbackAck(id=uuid.uuid4().hex[:12], received_at=int(time.time() * 1000))
    record = {**ack.model_dump(), **body.model_dump()}
    path = state.settings.var_dir / "feedback.jsonl"
    async with _lock:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("ab") as f:
            f.write(orjson.dumps(record) + b"\n")
    log.info("feedback_received", id=ack.id, category=body.category, source=body.source)
    return ack
