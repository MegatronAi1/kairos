"""WebSocket stream: `/ws?token=...`, then `{"type":"subscribe","reactors":[...]}`.

An empty or missing reactor list subscribes to all reactors. On subscribe the
server sends a `snapshot` of the current reactor summaries.
"""

from __future__ import annotations

import asyncio
import contextlib
from typing import Any

import orjson
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status

from app.core.logging import log
from app.core.security import websocket_authorised
from app.state import AppState

router = APIRouter()


@router.websocket("/ws")
async def stream(ws: WebSocket) -> None:
    state: AppState = ws.app.state.kairos
    if not websocket_authorised(ws, state.settings):
        await ws.close(code=status.WS_1008_POLICY_VIOLATION)
        return
    await ws.accept()
    wanted: set[str] = set()

    async def reader() -> None:
        nonlocal wanted
        while True:
            msg: dict[str, Any] = orjson.loads(await ws.receive_text())
            if msg.get("type") == "subscribe":
                wanted = set(msg.get("reactors") or [])
                snapshot = {
                    "type": "snapshot",
                    "reactors": [
                        r.summary().model_dump()
                        for r in state.engine.reactors.values()
                        if not wanted or r.id in wanted
                    ],
                }
                await ws.send_text(orjson.dumps(snapshot).decode())
            elif msg.get("type") == "ping":
                await ws.send_text(orjson.dumps({"type": "pong"}).decode())

    reader_task = asyncio.create_task(reader())
    try:
        async for event in state.bus.subscribe():
            if reader_task.done():
                break
            if wanted and event.get("reactor_id") not in wanted:
                continue
            await ws.send_text(orjson.dumps(event).decode())
    except WebSocketDisconnect:
        pass
    except Exception:
        log.exception("ws_stream_failed")
    finally:
        reader_task.cancel()
        with contextlib.suppress(asyncio.CancelledError, WebSocketDisconnect, Exception):
            await reader_task
