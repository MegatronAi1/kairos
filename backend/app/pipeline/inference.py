"""Per-tick inference: build a TickEvent from a batch row and run the engines.

Engines plug in through the `Engines` protocol so the replay slice works before
the ML models exist (NullEngines) and the trained engines drop in later.
"""

from __future__ import annotations

import math
import time
from typing import Protocol

from app.replay.store import TYPICAL_BATCH_H, Batch
from app.schemas import Forecast, Health, TickEvent

# Sensor keys sent to clients: canonical key -> source column. Frozen (docs/API.md).
SENSOR_KEYS: dict[str, str] = {
    "do_pct": "do_pct_sat",
    "do_mgl": "do_mgl",
    "ph": "ph",
    "temp_c": "temp_c",
    "rpm": "rpm",
    "aeration": "aeration_lph",
    "feed": "feed_lph",
    "pressure_bar": "pressure_bar",
    "co2_offgas_pct": "co2_offgas_pct",
    "o2_offgas_pct": "o2_offgas_pct",
    "volume_l": "volume_l",
    "base_lph": "base_lph",
    "acid_lph": "acid_lph",
    "cooling_lph": "cooling_lph",
    "heating_lph": "heating_lph",
    "paa_lph": "paa_lph",
    "oil_lph": "oil_lph",
}

DERIVED_KEYS: dict[str, str] = {
    "our": "our_mg_l_h",
    "cer": "cer_mg_l_h",
    "kla": "kla_h",
    "otr": "otr_mg_l_h",
    "power_kw": "power_kw",
    "agitator_kw": "agitator_kw",
    "compressor_kw": "compressor_kw",
    "kwh_cum": "kwh_cum",
}


class Engines(Protocol):
    def forecast(self, batch: Batch, idx: int) -> Forecast | None: ...

    def health(self, batch: Batch, idx: int) -> Health | None: ...


class NullEngines:
    """Placeholder until trained engines are loaded: every batch reads healthy."""

    def forecast(self, batch: Batch, idx: int) -> Forecast | None:
        return None

    def health(self, batch: Batch, idx: int) -> Health | None:
        return Health(score=100.0, state="normal")


def _clean(v: float) -> float | None:
    return None if math.isnan(v) or math.isinf(v) else round(v, 4)


def progress_of(t_h: float) -> float:
    return min(1.0, t_h / TYPICAL_BATCH_H)


class InferencePipeline:
    def __init__(self, engines: Engines) -> None:
        self.engines = engines

    def tick(self, reactor_id: str, batch: Batch, idx: int) -> TickEvent:
        cols = batch.columns
        t_h = float(cols["time_h"][idx])
        sensors = {k: _clean(float(cols[src][idx])) for k, src in SENSOR_KEYS.items()}
        derived = {k: _clean(float(cols[src][idx])) for k, src in DERIVED_KEYS.items()}
        return TickEvent(
            reactor_id=reactor_id,
            ts=int(time.time() * 1000),
            t_h=round(t_h, 3),
            progress=round(progress_of(t_h), 4),
            batch_id=batch.batch_id,
            sensors=sensors,
            derived=derived,
            forecast=self.engines.forecast(batch, idx),
            health=self.engines.health(batch, idx),
        )
