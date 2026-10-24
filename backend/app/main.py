"""FastAPI app factory. The lifespan loads data and engines, then starts the replay."""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.agent.templates import template_card
from app.api import routes_batches, routes_meta, routes_reactors, ws
from app.config import Settings, get_settings
from app.core.logging import configure_logging, log
from app.pipeline.events import EventBus
from app.pipeline.inference import Engines, InferencePipeline, NullEngines
from app.replay.engine import ReplayEngine
from app.replay.scenarios import get_scenario
from app.replay.store import BatchStore
from app.schemas import AlarmEvent, InsightEvent
from app.state import AppState

API_PREFIX = "/api/v1"


def build_state(settings: Settings, engines: Engines | None = None) -> AppState:
    store = BatchStore.load(settings.data_dir)
    bus = EventBus()
    engine = ReplayEngine(store, InferencePipeline(engines or NullEngines()), bus, settings.tick_hz)
    engine.load_scenario(get_scenario(settings.scenario), settings.default_speed_h_per_s)

    async def on_transition(alarm: AlarmEvent) -> None:
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


def create_app(settings: Settings | None = None, *, autostart: bool = True) -> FastAPI:
    settings = settings or get_settings()
    configure_logging()

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        state = build_state(settings)
        app.state.kairos = state
        log.info("startup", batches=len(state.store.batches), reactors=list(state.engine.reactors))
        if autostart:
            state.engine.start()
        yield
        await state.engine.stop()

    app = FastAPI(title="Kairos API", version=routes_meta.VERSION, lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    for module in (routes_meta, routes_reactors, routes_batches):
        app.include_router(module.router, prefix=API_PREFIX)
    app.include_router(ws.router)
    return app


app = create_app()
