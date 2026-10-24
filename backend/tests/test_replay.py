from __future__ import annotations

from app.schemas import Health
from app.state import AppState


async def test_step_advances_and_emits_tick(state: AppState) -> None:
    r = state.engine.reactors["R1"]
    tick = await state.engine.step(r, 1.0)
    assert tick.t_h == 1.0
    assert tick.reactor_id == "R1"
    assert tick.sensors["do_pct"] == 1.0
    assert tick.forecast is not None


async def test_fault_batch_transitions_to_alarm_with_insight(state: AppState) -> None:
    r = state.engine.reactors["R2"]
    for _ in range(12):
        await state.engine.step(r, 0.5)
    states = [a.state for a in r.history]
    assert states == ["watch", "alarm"]
    assert r.state == "alarm"
    assert r.last_insight is not None
    assert r.last_insight.card.title == "Oxygen transfer dropping"


async def test_normal_batch_never_alarms(state: AppState) -> None:
    r = state.engine.reactors["R1"]
    for _ in range(40):
        await state.engine.step(r, 0.5)
    assert r.history == []
    assert not r.running  # reached end of batch


async def test_seek_and_swap_reset_state(state: AppState) -> None:
    r = state.engine.reactors["R2"]
    for _ in range(12):
        await state.engine.step(r, 0.5)
    await state.engine.control("R2", "seek", progress=0.0)
    assert r.state == "normal" and r.history == []
    await state.engine.control("R2", "swap", batch_id=2)
    assert r.batch.batch_id == 2 and r.t_h == 0.0


async def test_ack_publishes_event(state: AppState) -> None:
    ack = state.engine.acknowledge("R2", "tester")
    assert ack.by == "tester"
    assert state.engine.reactors["R2"].acknowledged


async def test_alarm_latches_until_acknowledged(state: AppState) -> None:
    r = state.engine.reactors["R2"]
    for _ in range(12):
        await state.engine.step(r, 0.5)
    assert r.state == "alarm"
    # Force the engine to report normal: the alarm must stay latched.
    state.engine.pipeline.engines.health = lambda b, i: Health(score=95, state="normal")  # type: ignore[method-assign]
    await state.engine.step(r, 0.5)
    assert r.state == "alarm"
    state.engine.acknowledge("R2", "tester")
    await state.engine.step(r, 0.5)
    assert r.state == "normal"


def test_template_recognises_oxygen_pattern() -> None:
    from app.agent.templates import template_card
    from app.schemas import AlarmEvent, Contribution

    card = template_card(
        AlarmEvent(
            reactor_id="R2",
            ts=0,
            t_h=22,
            progress=0.1,
            batch_id=99,
            state="alarm",
            previous_state="normal",
            severity="critical",
            contributors=[
                Contribution(var="co2_offgas_pct", pct=42, dir="high"),
                Contribution(var="o2_offgas_pct", pct=42, dir="low"),
            ],
        )
    )
    assert card.title == "Oxygen transfer dropping"


async def test_loop_restarts_finished_batch(state: AppState) -> None:
    r = state.engine.reactors["R1"]
    while r.running:
        await state.engine.step(r, 5.0)
    assert r.ended_at is not None
    await state.engine.next_batch(r)
    assert r.running and r.t_h == 0.0 and r.cycle == 1 and r.ended_at is None


async def test_simulated_fault_alarms_then_returns_home(state: AppState) -> None:
    r = state.engine.reactors["R1"]
    await state.engine.simulate_fault("R1", 91, 20.0)
    assert r.batch.batch_id == 91 and r.t_h == 18.0
    for _ in range(12):
        await state.engine.step(r, 0.5)
    assert r.state == "alarm"
    await state.engine.next_batch(r)
    assert r.batch.batch_id == 1 and r.state == "normal"
