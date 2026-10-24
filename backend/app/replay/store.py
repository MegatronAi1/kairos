"""In-memory batch store: raw process columns plus precomputed derived signals per batch."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import cast

import numpy as np
import numpy.typing as npt
import pandas as pd

from kairos_ml.data.load import find_statistics_csv, load_process_frame
from kairos_ml.features.derived import compute_derived

Array = npt.NDArray[np.float64]

# Typical normal batch length (median of batches 1-90, docs/DATA_PROFILE.md).
TYPICAL_BATCH_H = 230.0

STRATEGIES = {
    "recipe": "Recipe-driven",
    "operator": "Operator-controlled",
    "pat": "Raman PAT-controlled",
    "fault": "Fault batch",
}


def strategy_of(batch_id: int) -> str:
    if batch_id >= 91:
        return "fault"
    if batch_id >= 61:
        return "pat"
    if batch_id >= 31:
        return "operator"
    return "recipe"


@dataclass
class Batch:
    batch_id: int
    columns: dict[str, Array]  # raw canonical keys + derived keys, aligned rows
    yield_total_kg: float | None

    @property
    def time_h(self) -> Array:
        return self.columns["time_h"]

    @property
    def t_end_h(self) -> float:
        return float(self.time_h[-1])

    @property
    def rows(self) -> int:
        return int(self.time_h.shape[0])

    @property
    def strategy(self) -> str:
        return strategy_of(self.batch_id)

    @property
    def is_fault_batch(self) -> bool:
        return self.batch_id >= 91

    def index_at(self, t_h: float) -> int:
        """Last row with time <= t_h (clamped)."""
        i = int(np.searchsorted(self.time_h, t_h, side="right")) - 1
        return max(0, min(i, self.rows - 1))


class BatchStore:
    def __init__(self, batches: dict[int, Batch]) -> None:
        self.batches = batches

    @classmethod
    def load(cls, data_dir: Path | None = None) -> BatchStore:
        df = load_process_frame()
        yields = _load_yields()
        batches: dict[int, Batch] = {}
        for bid, g in df.groupby("batch_id", sort=True):
            g = g.sort_values("time_h")
            cols = {c: g[c].to_numpy(dtype=float) for c in g.columns}
            d = compute_derived(
                temp_k=cols["temp_k"],
                o2_offgas_frac=cols["o2_offgas_frac"],
                do_mgl=cols["do_mgl"],
                pressure_bar=cols["pressure_bar"],
                our_gmin=cols["our_gmin"],
                cer_gh=cols["cer_gh"],
                volume_l=cols["volume_l"],
                rpm=cols["rpm"],
                aeration=cols["aeration_lph"],
            )
            cols.update(d.__dict__)
            dt = np.diff(cols["time_h"], prepend=0.0)
            cols["kwh_cum"] = np.cumsum(cols["power_kw"] * dt)
            b_id = int(cast(int, bid))
            batches[b_id] = Batch(b_id, cols, yields.get(b_id))
        return cls(batches)

    def get(self, batch_id: int) -> Batch:
        return self.batches[batch_id]


def _load_yields() -> dict[int, float]:
    path = find_statistics_csv()
    if path is None:
        return {}
    stats = pd.read_csv(path)
    ref = next(c for c in stats.columns if c.lower().startswith("batch"))
    total = next(c for c in stats.columns if "yield_total" in c.lower())
    # Values are labelled kg but match final P*V in grams (docs/DECISIONS.md).
    return {int(r): float(v) / 1000.0 for r, v in zip(stats[ref], stats[total], strict=True)}
