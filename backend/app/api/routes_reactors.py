from __future__ import annotations

from fastapi import APIRouter, Depends

from app.core.security import require_token
from app.schemas import AckEvent, AckRequest, AlarmEvent, ControlRequest, ReactorSummary
from app.state import AppState, get_state

router = APIRouter(prefix="/reactors", tags=["reactors"], dependencies=[Depends(require_token)])


@router.get("", response_model=list[ReactorSummary])
def list_reactors(state: AppState = Depends(get_state)) -> list[ReactorSummary]:
    return [r.summary() for r in state.engine.reactors.values()]


@router.get("/{reactor_id}", response_model=ReactorSummary)
def get_reactor(reactor_id: str, state: AppState = Depends(get_state)) -> ReactorSummary:
    return state.reactor(reactor_id).summary()


@router.get("/{reactor_id}/events", response_model=list[AlarmEvent])
def reactor_events(reactor_id: str, state: AppState = Depends(get_state)) -> list[AlarmEvent]:
    return state.reactor(reactor_id).history


@router.post("/{reactor_id}/control", response_model=ReactorSummary)
async def control(
    reactor_id: str, body: ControlRequest, state: AppState = Depends(get_state)
) -> ReactorSummary:
    state.reactor(reactor_id)
    r = await state.engine.control(
        reactor_id,
        body.action,
        progress=body.progress,
        speed=body.speed_h_per_s,
        batch_id=body.batch_id,
    )
    return r.summary()


@router.post("/{reactor_id}/ack", response_model=AckEvent)
def acknowledge(
    reactor_id: str, body: AckRequest | None = None, state: AppState = Depends(get_state)
) -> AckEvent:
    state.reactor(reactor_id)
    return state.engine.acknowledge(reactor_id, (body or AckRequest()).by)
