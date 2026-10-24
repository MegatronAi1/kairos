"""Per-batch feature frames and yield targets shared by training, evaluation and the backend."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd

from kairos_ml.features.engineering import MONITORED, add_derived, batch_features
from kairos_ml.features.golden import GoldenTrajectory


def total_yield_kg(batch: pd.DataFrame) -> float:
    """Total penicillin produced: mid-batch harvests (P x removed broth) + final P x V."""
    b = batch.sort_values("time_h")
    removed_l = (-b["dumped_lph"]).clip(lower=0) * np.diff(b["time_h"].to_numpy(), prepend=0.0)
    harvested = float((b["penicillin_gl"] * removed_l).sum()) / 1000.0
    final = float(b["penicillin_gl"].iloc[-1] * b["volume_l"].iloc[-1]) / 1000.0
    return harvested + final


@dataclass
class BatchData:
    batch_id: int
    raw: pd.DataFrame  # canonical + derived columns, sorted by time, index 0..n-1
    features: pd.DataFrame  # aligned with raw
    zscores: pd.DataFrame  # pointwise golden z of MONITORED, aligned with raw
    yield_kg: float


def build_batches(df: pd.DataFrame, golden: GoldenTrajectory) -> dict[int, BatchData]:
    out: dict[int, BatchData] = {}
    for bid, g in df.groupby("batch_id", sort=True):
        raw = add_derived(g.sort_values("time_h").reset_index(drop=True))
        b = int(str(bid))
        feats = batch_features(raw, golden)
        # Operating mode is known when the batch starts (recipe / operator / PAT control).
        feats["control_ref"] = raw["control_ref"].to_numpy(dtype=float)
        feats["pat_ref"] = raw["pat_ref"].to_numpy(dtype=float)
        out[b] = BatchData(
            batch_id=b,
            raw=raw,
            features=feats,
            zscores=golden.zscores(raw),
            yield_kg=total_yield_kg(raw),
        )
    return out


def fit_golden(df: pd.DataFrame, train_ids: list[int]) -> GoldenTrajectory:
    return GoldenTrajectory.fit(df[df["batch_id"].isin(train_ids)], MONITORED)
