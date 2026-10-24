"""Demo controls: raise a real alarm on demand, without plant hardware.

`POST /demo/trigger-fault` replays an IndPenSim fault batch on a reactor from two
hours before the fault starts. Nothing is faked downstream: the detector, alarm
latching, copilot card, point-of-no-return estimate, WebSocket push and phone
notification all run exactly as for a scheduled fault. The reactor goes back to
its own batch when the fault batch ends.
"""

from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.security import require_token
from app.schemas import ReactorSummary
from app.state import AppState, get_state

router = APIRouter(prefix="/demo", tags=["demo"], dependencies=[Depends(require_token)])

FaultKind = Literal["oxygen", "feed", "temperature"]

# Fault batch and onset (h) per kind; onsets from ml/config/fault_onsets.json.
FAULTS: dict[str, tuple[int, float, str]] = {
    "oxygen": (100, 20.0, "Aeration drops: oxygen transfer falls"),
    "feed": (97, 20.0, "Substrate feed drops"),
    "temperature": (96, 76.4, "Cooling drifts: temperature rises"),
}


class TriggerFault(BaseModel):
    reactor_id: str = "PUN-R1"
    kind: FaultKind = "oxygen"


class TriggerResult(BaseModel):
    reactor: ReactorSummary
    kind: FaultKind
    fault_batch: int
    description: str
    expected_alarm_in_s: float


@router.post("/trigger-fault", response_model=TriggerResult)
async def trigger_fault(body: TriggerFault, state: AppState = Depends(get_state)) -> TriggerResult:
    state.reactor(body.reactor_id)
    batch_id, onset_h, description = FAULTS[body.kind]
    r = await state.engine.simulate_fault(body.reactor_id, batch_id, onset_h)
    # The detector confirms about 2-3 h after onset; replay starts 2 h before it.
    return TriggerResult(
        reactor=r.summary(),
        kind=body.kind,
        fault_batch=batch_id,
        description=description,
        expected_alarm_in_s=round(4.5 / max(r.speed_h_per_s, 1e-6), 1),
    )
