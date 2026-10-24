"""Trained engines adapter for the replay pipeline.

At startup every batch is scored once (yield interval, MSPC ratio, health, alarm
state per row). Scores are causal (row i uses rows <= i), so serving the
precomputed row during replay is identical to computing it live, and each tick
costs O(1). Contributions are computed on demand when a batch is not normal.
"""

from __future__ import annotations

import numpy as np
import numpy.typing as npt

from app.core.logging import log
from app.replay.store import Batch
from app.schemas import Contribution, Forecast, Health
from kairos_ml.bundle import BatchScores, KairosModels
from kairos_ml.data.load import load_process_frame
from kairos_ml.dataset import BatchData, build_batches

# Monitored model variable -> client sensor key (docs/API.md).
VAR_TO_KEY: dict[str, str] = {
    "do_mgl": "do_pct",
    "ph": "ph",
    "temp_k": "temp_c",
    "co2_offgas_pct": "co2_offgas_pct",
    "o2_offgas_frac": "o2_offgas_pct",
    "our_gmin": "our",
    "cer_gh": "cer",
    "base_lph": "base_lph",
    "acid_lph": "acid_lph",
    "cooling_lph": "cooling_lph",
    "heating_lph": "heating_lph",
}


class MlEngines:
    def __init__(self, models: KairosModels, batches: dict[int, BatchData]) -> None:
        self.models = models
        self.batches = batches
        self.scores: dict[int, BatchScores] = {b: models.score(d) for b, d in batches.items()}
        self.since: dict[int, npt.NDArray[np.float64]] = {
            b: _state_since(s, d) for b, (d, s) in self._pairs()
        }

    def _pairs(self) -> list[tuple[int, tuple[BatchData, BatchScores]]]:
        return [(b, (self.batches[b], self.scores[b])) for b in self.batches]

    @classmethod
    def load(cls) -> MlEngines:
        models = KairosModels.load()
        batches = build_batches(load_process_frame(), models.golden)
        log.info("ml_engines_loaded", batches=len(batches))
        return cls(models, batches)

    def forecast(self, batch: Batch, idx: int) -> Forecast | None:
        s = self.scores.get(batch.batch_id)
        if s is None:
            return None
        ym = self.models.yield_model
        p50, lo, hi = float(s.p50[idx]), float(s.p10[idx]), float(s.p90[idx])
        return Forecast(
            p50=round(p50, 0),
            p10=round(lo, 0),
            p90=round(hi, 0),
            unit=ym.unit,
            vs_golden_pct=round(100.0 * p50 / ym.golden_yield_kg, 1),
            confidence=ym.confidence(p50, lo, hi),
        )

    def health(self, batch: Batch, idx: int) -> Health | None:
        s = self.scores.get(batch.batch_id)
        if s is None:
            return None
        state = s.states[idx]
        mspc = self.models.mspc
        contributors: list[Contribution] = []
        if state != "normal" or s.ratio_smooth[idx] > 1.0:
            z = self.batches[batch.batch_id].zscores.to_numpy()[idx]
            share = mspc.contributions(z)
            for i in np.argsort(-share)[:3]:
                if share[i] < 0.05:
                    break
                var = mspc.variables[i]
                contributors.append(
                    Contribution(
                        var=VAR_TO_KEY.get(var, var),
                        pct=round(100.0 * float(share[i]), 0),
                        dir="low" if z[i] < 0 else "high",
                    )
                )
        since = float(self.since[batch.batch_id][idx])
        return Health(
            score=round(float(s.health[idx]), 1),
            state=state,
            t2=round(float(s.t2[idx]), 2),
            t2_limit=round(mspc.t2_limit, 2),
            spe=round(float(s.spe[idx]), 2),
            spe_limit=round(mspc.spe_limit, 2),
            top_contributors=contributors,
            since_h=None if np.isnan(since) else since,
        )


def _state_since(s: BatchScores, d: BatchData) -> npt.NDArray[np.float64]:
    t = d.raw["time_h"].to_numpy()
    out = np.full(len(t), np.nan)
    start = t[0]
    for i in range(len(t)):
        if i and s.states[i] != s.states[i - 1]:
            start = t[i]
        out[i] = start
    return out
