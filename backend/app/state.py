"""Process-wide service container stored on `app.state.kairos`."""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING

from fastapi import HTTPException, Request, status

from app.config import Settings
from app.pipeline.events import EventBus
from app.replay.engine import Reactor, ReplayEngine
from app.replay.scenarios import DEMO_TENANT, Tenant
from app.replay.store import BatchStore

if TYPE_CHECKING:
    from app.agent.service import AgentService


@dataclass
class AppState:
    settings: Settings
    store: BatchStore
    bus: EventBus
    engine: ReplayEngine
    agent: AgentService | None = None
    tenant: Tenant = DEMO_TENANT

    def reactor(self, reactor_id: str) -> Reactor:
        r = self.engine.reactors.get(reactor_id)
        if r is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, f"Unknown reactor {reactor_id}")
        return r


def get_state(request: Request) -> AppState:
    state: AppState = request.app.state.kairos
    return state
