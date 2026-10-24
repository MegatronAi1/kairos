"""In-process pub/sub. Each subscriber gets a bounded queue; slow consumers drop oldest ticks."""

from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator
from typing import Any

Event = dict[str, Any]


class EventBus:
    def __init__(self, maxsize: int = 256) -> None:
        self._subscribers: set[asyncio.Queue[Event]] = set()
        self._maxsize = maxsize

    def publish(self, event: Event) -> None:
        for q in self._subscribers:
            if q.full() and event.get("type") == "tick":
                try:
                    q.get_nowait()
                except asyncio.QueueEmpty:
                    pass
            try:
                q.put_nowait(event)
            except asyncio.QueueFull:
                pass  # never block the replay loop on a slow client

    async def subscribe(self) -> AsyncIterator[Event]:
        q: asyncio.Queue[Event] = asyncio.Queue(self._maxsize)
        self._subscribers.add(q)
        try:
            while True:
                yield await q.get()
        finally:
            self._subscribers.discard(q)
