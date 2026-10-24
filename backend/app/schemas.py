"""Wire schemas shared by WebSocket events and REST responses.

These pydantic models are the single source for the web (openapi-typescript) and
mobile (fixtures in mobile/test/fixtures) contracts. See docs/API.md.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

HealthState = Literal["normal", "watch", "alarm"]
Confidence = Literal["low", "medium", "high"]
Provenance = Literal["measured", "published", "assumed", "synthetic", "fitted"]


class Contribution(BaseModel):
    var: str
    pct: float
    dir: Literal["high", "low"]


class Forecast(BaseModel):
    p50: float
    p10: float
    p90: float
    unit: str
    vs_golden_pct: float
    confidence: Confidence
    provenance: Provenance = "synthetic"


class Health(BaseModel):
    score: float = Field(ge=0, le=100)
    state: HealthState
    t2: float | None = None
    t2_limit: float | None = None
    spe: float | None = None
    spe_limit: float | None = None
    top_contributors: list[Contribution] = Field(default_factory=list)
    since_h: float | None = None


class EventBase(BaseModel):
    reactor_id: str
    ts: int  # epoch ms
    t_h: float
    progress: float
    batch_id: int


class TickEvent(EventBase):
    type: Literal["tick"] = "tick"
    sensors: dict[str, float | None]
    derived: dict[str, float | None]
    forecast: Forecast | None = None
    health: Health | None = None


class AlarmEvent(EventBase):
    type: Literal["alarm"] = "alarm"
    state: HealthState
    previous_state: HealthState
    severity: Literal["info", "warning", "critical"]
    contributors: list[Contribution] = Field(default_factory=list)
    ponr_hours: float | None = None


class InsightCard(BaseModel):
    title: str
    summary: str
    action: str
    expected_effect: str
    confidence: Confidence
    ponr_hours: float | None = None
    evidence: list[str] = Field(default_factory=list)


class InsightEvent(EventBase):
    type: Literal["insight"] = "insight"
    card: InsightCard
    source: Literal["agent", "template"]


class AckEvent(EventBase):
    type: Literal["ack"] = "ack"
    by: str


class ReactorSummary(BaseModel):
    id: str
    batch_id: int
    strategy: str
    is_fault_batch: bool
    running: bool
    speed_h_per_s: float
    t_h: float
    t_end_h: float
    progress: float
    state: HealthState
    acknowledged: bool
    last_tick: TickEvent | None = None
    last_insight: InsightEvent | None = None


class ControlRequest(BaseModel):
    action: Literal["start", "pause", "seek", "speed", "swap", "restart"]
    progress: float | None = Field(default=None, ge=0, le=1)
    speed_h_per_s: float | None = Field(default=None, gt=0, le=50)
    batch_id: int | None = Field(default=None, ge=1, le=100)


class AckRequest(BaseModel):
    by: str = "operator"


class BatchInfo(BaseModel):
    batch_id: int
    strategy: str
    is_fault_batch: bool
    t_end_h: float
    rows: int
    yield_total_kg: float | None
    final_penicillin_gl: float


class SensorSpec(BaseModel):
    key: str
    label: str
    unit: str
    provenance: Provenance
    note: str = ""


class SetpointOption(BaseModel):
    rpm: float
    aeration: float
    power_kw: float
    do_pct: float
    feasible: bool


class EnergyRecommendation(BaseModel):
    reactor_id: str
    mode: Literal["energy", "rescue"]
    t_h: float
    action: str
    current: SetpointOption
    recommended: SetpointOption
    power_saving_kw: float
    energy_delta_pct: float
    kwh_saved_rest_of_batch: float
    co2_saved_kg: float
    inr_saved: float
    target_do_pct: float
    options: list[SetpointOption]
    assumptions: list[str]
    provenance: Provenance = "assumed"


class RecommendRequest(BaseModel):
    reactor_id: str
    mode: Literal["energy", "rescue"] = "energy"
