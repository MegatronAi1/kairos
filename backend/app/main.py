"""FastAPI app factory. The lifespan loads data and engines, then starts the replay."""

from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Literal

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.agent.ratelimit import TokenBucket
from app.agent.service import AgentService
from app.agent.templates import template_card
from app.agent.tools import ToolBox
from app.api import (
    routes_agent,
    routes_batches,
    routes_demo,
    routes_feedback,
    routes_impact,
    routes_meta,
    routes_metrics,
    routes_plants,
    routes_processes,
    routes_reactors,
    ws,
)
from app.config import Settings, get_settings
from app.core.logging import configure_logging, log
from app.pipeline.events import EventBus
from app.pipeline.inference import Engines, InferencePipeline, NullEngines
from app.replay.engine import ReplayEngine
from app.replay.scenarios import get_tenant
from app.replay.store import BatchStore
from app.schemas import AlarmEvent, InsightCard, InsightEvent
from app.state import AppState

API_PREFIX = "/api/v1"


def load_engines() -> Engines:
    try:
        from app.pipeline.ml_engines import MlEngines

        return MlEngines.load()
    except FileNotFoundError:
        log.warning("no_trained_models", hint="run `make train` to enable forecasts and alarms")
        return NullEngines()


def build_agent(settings: Settings, state: AppState) -> AgentService:
    client = None
    if settings.model_chat or settings.model_fast:
        try:
            from app.agent.bedrock import BedrockClient

            client = BedrockClient(settings, TokenBucket(settings.bedrock_max_rps))
        except Exception as e:  # missing credentials must not stop the plant view
            log.warning("agent_disabled", error=type(e).__name__)
    tools = ToolBox(state, settings.artifacts_dir / "metrics")
    return AgentService(client, tools, settings.model_chat, settings.model_fast)


def build_state(settings: Settings, engines: Engines | None = None) -> AppState:
    store = BatchStore.load(settings.data_dir)
    bus = EventBus()
    engine = ReplayEngine(
        store, InferencePipeline(engines or load_engines()), bus, settings.tick_hz
    )
    tenant = get_tenant(settings.scenario)
    engine.load_tenant(tenant, settings.default_speed_h_per_s)
    engine.loop, engine.turnaround_s = settings.replay_loop, settings.turnaround_s

    state = AppState(settings=settings, store=store, bus=bus, engine=engine, tenant=tenant)
    state.agent = build_agent(settings, state)
    pending: set[asyncio.Task[None]] = set()

    def insight(
        alarm: AlarmEvent, card: InsightCard, source: Literal["agent", "template"]
    ) -> InsightEvent:
        return InsightEvent(
            reactor_id=alarm.reactor_id,
            ts=alarm.ts,
            t_h=alarm.t_h,
            progress=alarm.progress,
            batch_id=alarm.batch_id,
            card=card,
            source=source,
        )

    async def agent_card(alarm: AlarmEvent) -> None:
        card = await state.agent.alarm_card(alarm) if state.agent else None
        reactor = engine.reactors.get(alarm.reactor_id)
        # Publish only if the reactor is still in the state this card describes.
        if card is not None and reactor is not None and reactor.state == alarm.state:
            engine.publish_insight(insight(alarm, card, "agent"))

    async def on_transition(alarm: AlarmEvent) -> None:
        # Rule-based card first (instant, always available), agent card follows.
        engine.publish_insight(insight(alarm, template_card(alarm), "template"))
        if alarm.state != "normal":
            task = asyncio.create_task(agent_card(alarm))
            pending.add(task)
            task.add_done_callback(pending.discard)

    engine.on_transition = on_transition
    return state


def create_app(settings: Settings | None = None, *, autostart: bool = True) -> FastAPI:
    settings = settings or get_settings()
    configure_logging()

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        state = build_state(settings)
        app.state.kairos = state
        log.info(
            "startup",
            batches=len(state.store.batches),
            reactors=list(state.engine.reactors),
            agent=bool(state.agent and state.agent.enabled),
        )
        if autostart:
            state.engine.start()
        yield
        await state.engine.stop()

    app = FastAPI(title="Kairos API", version=routes_meta.VERSION, lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    for module in (
        routes_meta,
        routes_reactors,
        routes_batches,
        routes_agent,
        routes_metrics,
        routes_processes,
        routes_plants,
        routes_feedback,
        routes_demo,
        routes_impact,
    ):
        app.include_router(module.router, prefix=API_PREFIX)
    app.include_router(routes_plants.auth_router, prefix=API_PREFIX)
    app.include_router(ws.router)
    return app


app = create_app()
