"""Engine D: oxygen transfer vs energy, and the setpoint recommender.

Physics counterfactual (published correlations, assumed geometry):
- kLa from agitation and aeration (van't Riet: kLa ~ (Pg/V)^0.4 vs^0.5, so
  kLa ~ N^1.2 x Q^0.5 at fixed geometry); power from the Rushton power number
  plus an assumed compressor specific energy.
- Oxygen balance at quasi-steady state: demand = kLa (C* - C). The live demand is
  inferred from the measured DO and the current kLa, so a candidate setting gives
  C' = C* - (C* - C) kLa / kLa'. The dataset's OUR is in scaled units, so the
  balance is anchored on measured DO rather than on OUR.

A monotone ML model of DO was tried first and rejected: in the data, low aeration
was only used when demand was low, so the model learned that DO barely depends on
kLa (confounding) and recommended the minimum setting everywhere.

Recommendations are step-limited (aeration >= 70% of current, agitation +-10%) and
must keep DO >= critical + margin. Agitation never varies in IndPenSim, so its
effect is physics-only and labelled assumed.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
import numpy.typing as npt
import pandas as pd

from kairos_ml.constants import const
from kairos_ml.features.derived import NOMINAL_VOLUME_M3
from kairos_ml.physics.oxygen_transfer import kla_per_s, superficial_gas_velocity
from kairos_ml.physics.power import (
    agitator_electrical_kw,
    compressor_kw,
    gassed_power_w,
    geometry_from_volume,
)

Array = npt.NDArray[np.float64]

RPM_GRID = np.array([80.0, 90.0, 100.0, 110.0, 120.0])  # Pareto sweep (assumed beyond data)
AERATION_GRID = np.arange(30.0, 75.1, 5.0)  # m3/min, the range seen in the data
DO_MARGIN_PCT = 10.0
MAX_AERATION_CUT = 0.30  # recommendation step limit
MAX_RPM_CHANGE = 0.10


def critical_do_pct() -> float:
    return 100.0 * const("critical_do_fraction")


def kla_h(rpm: npt.ArrayLike, aeration: npt.ArrayLike, volume_l: npt.ArrayLike) -> Array:
    geom = geometry_from_volume(NOMINAL_VOLUME_M3)
    pg = gassed_power_w(np.asarray(rpm, dtype=float), geom.impeller_diameter_m)
    vs = superficial_gas_velocity(np.asarray(aeration, dtype=float) / 60.0, geom.cross_section_m2)
    return (
        np.asarray(kla_per_s(pg, np.asarray(volume_l, dtype=float) / 1000.0, vs), dtype=float)
        * 3600.0
    )


def power_kw(rpm: npt.ArrayLike, aeration: npt.ArrayLike) -> Array:
    geom = geometry_from_volume(NOMINAL_VOLUME_M3)
    agit = agitator_electrical_kw(np.asarray(rpm, dtype=float), geom.impeller_diameter_m)
    return np.asarray(agit + compressor_kw(np.asarray(aeration, dtype=float)), dtype=float)


@dataclass
class Option:
    rpm: float
    aeration: float
    power_kw: float
    do_pct: float
    feasible: bool


@dataclass
class Recommendation:
    mode: str
    current: Option
    best: Option
    options: list[Option] = field(default_factory=list)

    @property
    def power_saving_kw(self) -> float:
        return self.current.power_kw - self.best.power_kw


class EnergyEngine:
    def __init__(self, margin_pct: float = DO_MARGIN_PCT) -> None:
        self.margin = margin_pct

    @property
    def target_do(self) -> float:
        return critical_do_pct() + self.margin

    @staticmethod
    def predict_do(row: pd.Series, rpm: npt.ArrayLike, aeration: npt.ArrayLike) -> Array:
        """DO (% sat) at candidate settings from the live oxygen balance."""
        k_now = float(kla_h([row["rpm"]], [row["aeration_lph"]], [row["volume_l"]])[0])
        k_new = kla_h(rpm, aeration, np.full(np.shape(rpm), float(row["volume_l"])))
        deficit = max(0.0, 100.0 - float(row["do_pct_sat"]))  # % of C* currently consumed
        return np.asarray(100.0 - deficit * k_now / np.maximum(k_new, 1e-9), dtype=float)

    def sweep(self, row: pd.Series) -> pd.DataFrame:
        rpm, aer = np.meshgrid(RPM_GRID, AERATION_GRID, indexing="ij")
        g = pd.DataFrame({"rpm": rpm.ravel(), "aeration": aer.ravel()})
        g["power_kw"] = power_kw(g["rpm"], g["aeration"])
        g["kla_h"] = kla_h(g["rpm"], g["aeration"], np.full(len(g), float(row["volume_l"])))
        g["do_pct"] = self.predict_do(row, g["rpm"].to_numpy(), g["aeration"].to_numpy())
        g["feasible"] = g["do_pct"] >= self.target_do
        rpm0, aer0 = float(row["rpm"]), float(row["aeration_lph"])
        g["allowed"] = (
            g["aeration"] >= max(AERATION_GRID[0], (1 - MAX_AERATION_CUT) * aer0) - 1e-9
        ) & ((g["rpm"] - rpm0).abs() <= MAX_RPM_CHANGE * rpm0 + 1e-9)
        return g

    def _current(self, row: pd.Series) -> Option:
        p = float(power_kw([row["rpm"]], [row["aeration_lph"]])[0])
        do = float(row["do_pct_sat"])
        return Option(float(row["rpm"]), float(row["aeration_lph"]), p, do, do >= self.target_do)

    def recommend(self, row: pd.Series, mode: str = "energy") -> Recommendation:
        """energy: cheapest allowed setting with predicted DO >= target.
        rescue: best oxygen within the allowed steps, least power among near-ties."""
        g = self.sweep(row)
        if mode == "rescue":
            # Rescue never reduces oxygen transfer below the current setting.
            k_now = float(kla_h([row["rpm"]], [row["aeration_lph"]], [row["volume_l"]])[0])
            allowed = g[g["kla_h"] >= k_now - 1e-9]
            if allowed.empty:
                allowed = g.sort_values("kla_h", ascending=False).head(1)
        else:
            allowed = g[g["allowed"]]
        if mode == "rescue":
            top = allowed["do_pct"].max()
            pick = allowed[allowed["do_pct"] >= top - 1.0].sort_values("power_kw").iloc[0]
        else:
            feas = allowed[allowed["feasible"]]
            pool = feas if len(feas) else allowed.sort_values("do_pct", ascending=False).head(1)
            pick = pool.sort_values("power_kw").iloc[0]
        options = [
            Option(float(rpm), float(aer), float(pw), float(do), bool(ok))
            for rpm, aer, pw, do, ok in zip(
                g["rpm"], g["aeration"], g["power_kw"], g["do_pct"], g["feasible"], strict=True
            )
        ]
        best = Option(
            float(pick.rpm),
            float(pick.aeration),
            float(pick.power_kw),
            float(pick.do_pct),
            bool(pick.feasible),
        )
        cur = self._current(row)
        if mode == "energy" and best.power_kw >= cur.power_kw:
            best = cur  # never recommend spending more energy in energy mode
        return Recommendation(mode, cur, best, options)

    def batch_policy(
        self, raw: pd.DataFrame, every: int = 5, start_h: float = 10.0
    ) -> pd.DataFrame:
        """Recommended setting every `every` rows (1 h), held until the next decision."""
        rows = []
        for i in range(0, len(raw), every):
            r = raw.iloc[i]
            if float(r["time_h"]) < start_h:
                continue
            rec = self.recommend(r)
            rows.append(
                {
                    "time_h": float(r["time_h"]),
                    "current_kw": rec.current.power_kw,
                    "best_kw": rec.best.power_kw,
                    "current_do": rec.current.do_pct,
                    "best_do": rec.best.do_pct,
                    "best_rpm": rec.best.rpm,
                    "best_aeration": rec.best.aeration,
                }
            )
        return pd.DataFrame(rows)
