from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Literal

import orjson
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sse_starlette.sse import EventSourceResponse

from app.core.security import require_token
from app.schemas import InsightEvent
from app.state import AppState, get_state

router = APIRouter(prefix="/agent", tags=["agent"], dependencies=[Depends(require_token)])


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(max_length=4000)


class ChatRequest(BaseModel):
    messages: list[ChatMessage] = Field(min_length=1, max_length=30)
    reactor_id: str | None = None
    process_id: str | None = None


@router.post("/chat")
async def chat(body: ChatRequest, state: AppState = Depends(get_state)) -> EventSourceResponse:
    """Server-sent events: each `data:` is JSON {type: text|tool|evidence|done|error}."""
    if state.agent is None:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Agent not configured")
    agent = state.agent

    async def events() -> AsyncIterator[dict[str, str]]:
        async for ev in agent.chat(
            [m.model_dump() for m in body.messages], body.reactor_id, body.process_id
        ):
            yield {"data": orjson.dumps(ev).decode()}

    return EventSourceResponse(events(), ping=15)


@router.get("/insights/{reactor_id}", response_model=InsightEvent | None)
def latest_insight(reactor_id: str, state: AppState = Depends(get_state)) -> InsightEvent | None:
    return state.reactor(reactor_id).last_insight


@router.get("/status")
def agent_status(state: AppState = Depends(get_state)) -> dict[str, object]:
    a = state.agent
    return {
        "enabled": bool(a and a.enabled),
        "model_chat": a.model_chat if a else None,
        "model_fast": a.model_fast if a else None,
    }
