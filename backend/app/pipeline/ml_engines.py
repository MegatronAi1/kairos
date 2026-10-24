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
from app.schemas import Contribution, EnergyRecommendation, Forecast, Health, SetpointOption
from kairos_ml.bundle import BatchScores, KairosModels
from kairos_ml.constants import load_constants
from kairos_ml.data.load import load_process_frame
from kairos_ml.dataset import BatchData, build_batches
from kairos_ml.engines.energy import EnergyEngine, Option
from kairos_ml.engines.ponr import PonrResult

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
        self.energy = EnergyEngine()
        self._ponr_cache: dict[tuple[int, int, float | None], PonrResult] = {}
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

    def ponr(self, batch: Batch, idx: int, reference_h: float | None = None) -> PonrResult | None:
        """Point of no return and recovery curve if the fault were fixed now or later."""
        rescue = self.models.rescue
        data = self.batches.get(batch.batch_id)
        if rescue is None or data is None:
            return None
        ref = None if reference_h is None else round(reference_h, 1)
        key = (batch.batch_id, idx // 5, ref)  # one estimate per batch-hour and anchor
        if key not in self._ponr_cache:
            self._ponr_cache[key] = rescue.evaluate(data, float(batch.time_h[idx]), reference_h=ref)
        return self._ponr_cache[key]

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


def _opt(o: Option) -> SetpointOption:
    return SetpointOption(
        rpm=o.rpm,
        aeration=o.aeration,
        power_kw=round(o.power_kw, 1),
        do_pct=round(o.do_pct, 1),
        feasible=o.feasible,
    )


def _action(cur: Option, best: Option, mode: str) -> str:
    parts = []
    if abs(best.aeration - cur.aeration) >= 1:
        verb = "Lower" if best.aeration < cur.aeration else "Raise"
        parts.append(f"{verb} aeration {cur.aeration:.0f} to {best.aeration:.0f} m³/min")
    if abs(best.rpm - cur.rpm) >= 1:
        verb = "lower" if best.rpm < cur.rpm else "raise"
        parts.append(f"{verb} agitation {cur.rpm:.0f} to {best.rpm:.0f} rpm")
    if not parts:
        return (
            "Keep current agitation and aeration"
            if mode == "energy"
            else "Hold settings; oxygen is at its best"
        )
    text = ", ".join(parts)
    return text[0].upper() + text[1:]


def recommend(
    engines: MlEngines, reactor_id: str, batch_id: int, idx: int, mode: str
) -> EnergyRecommendation:
    raw = engines.batches[batch_id].raw
    row = raw.iloc[idx]
    rec = engines.energy.recommend(row, "rescue" if mode == "rescue" else "energy")
    consts = load_constants()
    saving_kw = rec.current.power_kw - rec.best.power_kw
    remaining_h = max(0.0, float(raw["time_h"].iloc[-1]) - float(row["time_h"]))
    kwh = saving_kw * remaining_h
    return EnergyRecommendation(
        reactor_id=reactor_id,
        mode="rescue" if mode == "rescue" else "energy",
        t_h=round(float(row["time_h"]), 2),
        action=_action(rec.current, rec.best, mode),
        current=_opt(rec.current),
        recommended=_opt(rec.best),
        power_saving_kw=round(saving_kw, 1),
        energy_delta_pct=round(-100.0 * saving_kw / max(rec.current.power_kw, 1e-9), 1),
        kwh_saved_rest_of_batch=round(kwh, 0),
        co2_saved_kg=round(kwh * consts["grid_emission_factor_india"].value, 0),
        inr_saved=round(kwh * consts["electricity_tariff_india"].value, 0),
        target_do_pct=engines.energy.target_do,
        options=[_opt(o) for o in rec.options],
        assumptions=[
            "kLa from van't Riet (1979) with assumed vessel geometry (published correlation, assumed geometry)",
            "Compressor specific energy 1.5 kW per m³/min (assumed)",
            "Quasi-steady oxygen balance anchored on measured DO (model estimate)",
            f"Critical DO {100 * consts['critical_do_fraction'].value:.0f}% sat plus {engines.energy.margin:.0f}% margin (assumed)",
            "Grid factor and tariff for CO2 and INR are assumed until verified",
        ],
    )
