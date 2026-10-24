from __future__ import annotations

from collections.abc import Iterator

import numpy as np
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.agent.templates import template_card
from app.config import Settings
from app.pipeline.events import EventBus
from app.pipeline.inference import DERIVED_KEYS, SENSOR_KEYS, InferencePipeline
from app.replay.engine import ReplayEngine
from app.replay.store import Batch, BatchStore
from app.schemas import Contribution, Forecast, Health, InsightEvent
from app.state import AppState


def make_batch(batch_id: int, hours: float = 20.0, dt: float = 0.2) -> Batch:
    t = np.round(np.arange(dt, hours + dt / 2, dt), 3)
    cols = {"time_h": t, "penicillin_gl": np.linspace(0, 10, t.size)}
    for src in [*SENSOR_KEYS.values(), *DERIVED_KEYS.values()]:
        cols.setdefault(src, np.full(t.size, 1.0))
    return Batch(batch_id, cols, yield_total_kg=1000.0)


class ScriptedEngines:
    """Alarm on fault batches (>= 91) once t >= 5 h; watch from 3 h."""

    def forecast(self, batch: Batch, idx: int) -> Forecast | None:
        return Forecast(p50=20, p10=18, p90=22, unit="g/L", vs_golden_pct=95, confidence="medium")

    def health(self, batch: Batch, idx: int) -> Health | None:
        t = float(batch.time_h[idx])
        if batch.batch_id < 91 or t < 3:
            return Health(score=95, state="normal")
        state = "alarm" if t >= 5 else "watch"
        return Health(
            score=30 if state == "alarm" else 60,
            state=state,
            top_contributors=[Contribution(var="do_pct", pct=60, dir="low")],
        )


@pytest.fixture
def state() -> AppState:
    settings = Settings(api_token="", tick_hz=50, default_speed_h_per_s=1.0)
    store = BatchStore({1: make_batch(1), 91: make_batch(91), 2: make_batch(2, hours=10)})
    bus = EventBus()
    engine = ReplayEngine(store, InferencePipeline(ScriptedEngines()), bus, settings.tick_hz)
    engine.load_scenario({"R1": 1, "R2": 91}, settings.default_speed_h_per_s)

    async def on_transition(alarm):  # type: ignore[no-untyped-def]
        engine.publish_insight(
            InsightEvent(
                reactor_id=alarm.reactor_id,
                ts=alarm.ts,
                t_h=alarm.t_h,
                progress=alarm.progress,
                batch_id=alarm.batch_id,
                card=template_card(alarm),
                source="template",
            )
        )

    engine.on_transition = on_transition
    return AppState(settings=settings, store=store, bus=bus, engine=engine)


@pytest.fixture
def client(state: AppState) -> Iterator[TestClient]:
    from app.api import (
        routes_batches,
        routes_demo,
        routes_feedback,
        routes_meta,
        routes_metrics,
        routes_plants,
        routes_processes,
        routes_reactors,
        ws,
    )
    from app.main import API_PREFIX

    app = FastAPI()
    for module in (
        routes_meta,
        routes_reactors,
        routes_batches,
        routes_metrics,
        routes_processes,
        routes_plants,
        routes_feedback,
        routes_demo,
    ):
        app.include_router(module.router, prefix=API_PREFIX)
    app.include_router(routes_plants.auth_router, prefix=API_PREFIX)
    app.include_router(ws.router)
    app.state.kairos = state
    from app.config import get_settings

    app.dependency_overrides[get_settings] = lambda: state.settings
    with TestClient(app) as c:
        yield c
