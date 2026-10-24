from __future__ import annotations

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
    assert r.last_insight.card.title == "Dissolved oxygen running low"


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
