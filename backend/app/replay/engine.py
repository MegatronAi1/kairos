"""Async multi-reactor replay: streams batches as if live and publishes events."""

from __future__ import annotations

import asyncio
import contextlib
import time
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field

from app.core.logging import log
from app.pipeline.events import EventBus
from app.pipeline.inference import InferencePipeline, progress_of
from app.replay.store import Batch, BatchStore
from app.schemas import (
    AckEvent,
    AlarmEvent,
    HealthState,
    InsightEvent,
    ReactorSummary,
    TickEvent,
)

InsightHook = Callable[[AlarmEvent], Awaitable[None]]

SEVERITY: dict[HealthState, str] = {"normal": "info", "watch": "warning", "alarm": "critical"}


@dataclass
class Reactor:
    id: str
    batch: Batch
    speed_h_per_s: float
    running: bool = True
    t_h: float = 0.0
    state: HealthState = "normal"
    acknowledged: bool = False
    latched: bool = False  # alarm held although the detector currently reads lower
    detector_state: HealthState = "normal"  # raw detector reading before latching
    last_tick: TickEvent | None = None
    last_insight: InsightEvent | None = None
    history: list[AlarmEvent] = field(default_factory=list)

    def summary(self) -> ReactorSummary:
        return ReactorSummary(
            id=self.id,
            batch_id=self.batch.batch_id,
            strategy=self.batch.strategy,
            is_fault_batch=self.batch.is_fault_batch,
            running=self.running,
            speed_h_per_s=self.speed_h_per_s,
            t_h=self.t_h,
            t_end_h=self.batch.t_end_h,
            progress=progress_of(self.t_h),
            state=self.state,
            acknowledged=self.acknowledged,
            last_tick=self.last_tick,
            last_insight=self.last_insight,
        )

    def reset_state(self) -> None:
        self.state = "normal"
        self.acknowledged = False
        self.latched = False
        self.detector_state = "normal"
        self.last_tick = None
        self.last_insight = None
        self.history.clear()


class ReplayEngine:
    def __init__(
        self,
        store: BatchStore,
        pipeline: InferencePipeline,
        bus: EventBus,
        tick_hz: float,
    ) -> None:
        self.store = store
        self.pipeline = pipeline
        self.bus = bus
        self.tick_hz = tick_hz
        self.reactors: dict[str, Reactor] = {}
        self.on_transition: InsightHook | None = None
        self._task: asyncio.Task[None] | None = None

    # --- lifecycle -----------------------------------------------------------
    def load_scenario(self, slots: dict[str, int], speed_h_per_s: float) -> None:
        self.reactors = {
            rid: Reactor(rid, self.store.get(bid), speed_h_per_s) for rid, bid in slots.items()
        }

    def start(self) -> None:
        if self._task is None:
            self._task = asyncio.create_task(self._run(), name="replay")

    async def stop(self) -> None:
        if self._task is not None:
            self._task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self._task
            self._task = None

    async def _run(self) -> None:
        period = 1.0 / self.tick_hz
        while True:
            started = time.perf_counter()
            for reactor in list(self.reactors.values()):
                if reactor.running:
                    try:
                        await self.step(reactor, reactor.speed_h_per_s * period)
                    except Exception:  # one bad reactor must not stop the others
                        log.exception("replay_step_failed", reactor=reactor.id)
            elapsed = time.perf_counter() - started
            await asyncio.sleep(max(0.0, period - elapsed))

    # --- stepping ------------------------------------------------------------
    async def step(self, reactor: Reactor, dt_h: float) -> TickEvent:
        reactor.t_h = min(reactor.t_h + dt_h, reactor.batch.t_end_h)
        if reactor.t_h >= reactor.batch.t_end_h:
            reactor.running = False
        return await self.emit(reactor)

    async def emit(self, reactor: Reactor) -> TickEvent:
        idx = reactor.batch.index_at(reactor.t_h)
        tick = self.pipeline.tick(reactor.id, reactor.batch, idx)
        reactor.last_tick = tick
        self.bus.publish(tick.model_dump())
        new_state = tick.health.state if tick.health else "normal"
        # Alarms latch until the operator acknowledges them (ISA-18.2 practice): a
        # process that partly adapts to a fault must not silently clear the alarm.
        reactor.detector_state = new_state
        reactor.latched = False
        if reactor.state == "alarm" and new_state != "alarm" and not reactor.acknowledged:
            reactor.latched = True
            new_state = "alarm"
            if tick.health is not None:
                tick.health.state = "alarm"
        if new_state != reactor.state:
            await self._transition(reactor, tick, new_state)
        return tick

    async def _transition(self, reactor: Reactor, tick: TickEvent, new_state: HealthState) -> None:
        alarm = AlarmEvent(
            reactor_id=reactor.id,
            ts=tick.ts,
            t_h=tick.t_h,
            progress=tick.progress,
            batch_id=tick.batch_id,
            state=new_state,
            previous_state=reactor.state,
            severity=SEVERITY[new_state],
            contributors=tick.health.top_contributors if tick.health else [],
            ponr_hours=None,
        )
        reactor.state = new_state
        if new_state == "alarm":
            reactor.acknowledged = False
        reactor.history.append(alarm)
        self.bus.publish(alarm.model_dump())
        log.info("health_transition", reactor=reactor.id, state=new_state, t_h=tick.t_h)
        if self.on_transition is not None:
            await self.on_transition(alarm)

    def publish_insight(self, insight: InsightEvent) -> None:
        reactor = self.reactors.get(insight.reactor_id)
        if reactor is not None:
            reactor.last_insight = insight
        self.bus.publish(insight.model_dump())

    # --- controls ------------------------------------------------------------
    async def control(
        self,
        reactor_id: str,
        action: str,
        *,
        progress: float | None = None,
        speed: float | None = None,
        batch_id: int | None = None,
    ) -> Reactor:
        r = self.reactors[reactor_id]
        if action == "start":
            r.running = r.t_h < r.batch.t_end_h
        elif action == "pause":
            r.running = False
        elif action == "speed" and speed is not None:
            r.speed_h_per_s = speed
        elif action == "seek" and progress is not None:
            r.t_h = min(progress * r.batch.t_end_h, r.batch.t_end_h)
            r.reset_state()
            await self.emit(r)
        elif action == "swap" and batch_id is not None:
            r.batch = self.store.get(batch_id)
            r.t_h = 0.0
            r.reset_state()
            await self.emit(r)
        elif action == "restart":
            r.t_h = 0.0
            r.running = True
            r.reset_state()
            await self.emit(r)
        return r

    def acknowledge(self, reactor_id: str, by: str) -> AckEvent:
        r = self.reactors[reactor_id]
        r.acknowledged = True
        tick = r.last_tick
        ack = AckEvent(
            reactor_id=r.id,
            ts=int(time.time() * 1000),
            t_h=r.t_h,
            progress=progress_of(r.t_h),
            batch_id=r.batch.batch_id,
            by=by,
        )
        if tick is not None:
            ack.t_h = tick.t_h
        self.bus.publish(ack.model_dump())
        return ack
