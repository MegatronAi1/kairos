"""Point of no return and what-if via analog batches (spec 7.5, tier 1).

If the fault is corrected at batch time T, the batch keeps the penicillin it has
already made by T. From T on it behaves like its nearest healthy training batches
at the same batch time (matched on lab biomass and product made so far), scaled by
how much biomass it still has relative to each analog. The spread across analogs
gives the band.

Point of no return: the latest correction time whose recovered yield (median)
still reaches `recovery_fraction` of what a normal batch in this state would
deliver, i.e. of the outcome if the correction were applied right now.

This is a model estimate built from data, not a mechanistic simulation; the UI
labels it so.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import numpy.typing as npt

from kairos_ml.dataset import BatchData
from kairos_ml.features.golden import time_index

Array = npt.NDArray[np.float64]


@dataclass
class Recovery:
    fix_h: float
    p10: float
    p50: float
    p90: float


@dataclass
class PonrResult:
    now_h: float
    ponr_h: float | None  # None: still recoverable at the end of the horizon
    hours_left: float | None
    passed: bool
    target_kg: float
    curve: list[Recovery]


@dataclass
class AnalogRescue:
    times: Array  # shared time grid (rows of 0.2 h)
    p_now: Array  # (n_batches, n_times) penicillin made so far (kg), forward-filled
    x_lab: Array  # (n_batches, n_times) lab biomass (g/L)
    yields: Array  # (n_batches,)
    typical_kg: float
    k: int = 8
    recovery_fraction: float = 0.9

    @classmethod
    def fit(
        cls, normal: list[BatchData], k: int = 8, recovery_fraction: float = 0.9
    ) -> AnalogRescue:
        n_t = max(int(time_index([b.raw["time_h"].iloc[-1]])[0]) + 1 for b in normal)
        p = np.full((len(normal), n_t), np.nan)
        x = np.full((len(normal), n_t), np.nan)
        for i, b in enumerate(normal):
            rows = time_index(b.raw["time_h"].to_numpy())
            p[i, rows] = b.features["p_now_kg"].to_numpy()
            x[i, rows] = b.features["x_lab"].to_numpy()
        # Batches that ended early hold their final state.
        p = _ffill(p)
        x = _ffill(x)
        yields = np.array([b.yield_kg for b in normal])
        return cls(
            np.arange(n_t) * 0.2, p, x, yields, float(np.median(yields)), k, recovery_fraction
        )

    def recover(self, batch: BatchData, fix_h: float) -> Recovery:
        t = batch.raw["time_h"].to_numpy()
        i = int(np.clip(np.searchsorted(t, fix_h, side="right") - 1, 0, len(t) - 1))
        col = int(np.clip(time_index([t[i]])[0], 0, self.p_now.shape[1] - 1))
        p_b = float(batch.features["p_now_kg"].iloc[i])
        x_b = float(batch.features["x_lab"].iloc[i])
        pa, xa = self.p_now[:, col], self.x_lab[:, col]
        # Nearest analogs on (biomass, product so far), each scaled by its spread.
        sx = max(float(np.nanstd(xa)), 1e-6)
        sp = max(float(np.nanstd(pa)), 1e-6)
        dist = np.hypot((xa - x_b) / sx, (pa - p_b) / sp)
        idx = np.argsort(dist)[: self.k]
        remaining = np.clip(self.yields[idx] - pa[idx], 0.0, None)
        capacity = np.clip(x_b / np.maximum(xa[idx], 1e-6), 0.0, 1.0)
        total = p_b + remaining * capacity
        lo, mid, hi = np.percentile(total, [10, 50, 90])
        return Recovery(float(t[i]), float(lo), float(mid), float(hi))

    def evaluate(
        self,
        batch: BatchData,
        now_h: float,
        horizon_h: float = 72.0,
        step_h: float = 2.0,
        reference_h: float | None = None,
    ) -> PonrResult:
        """`reference_h`: when the alarm fired. The 90% target is anchored there so the
        countdown does not reset as time passes."""
        start = reference_h if reference_h is not None and reference_h < now_h else now_h
        end = min(now_h + horizon_h, float(batch.raw["time_h"].iloc[-1]))
        fixes = np.arange(start, end + 1e-9, step_h)
        raw = [self.recover(batch, float(f)) for f in fixes]
        # Waiting never improves a faulty batch: enforce a non-increasing curve from the
        # alarm moment on (lab biomass is sampled ~12 h apart, so raw analog matches jitter).
        full, lo, mid, hi = [], np.inf, np.inf, np.inf
        for c in raw:
            lo, mid, hi = min(lo, c.p10), min(mid, c.p50), min(hi, c.p90)
            full.append(Recovery(c.fix_h, lo, mid, hi))
        target = self.recovery_fraction * full[0].p50
        curve = [c for c in full if c.fix_h >= now_h - 1e-9] or full[-1:]
        if curve[0].p50 < target:
            return PonrResult(now_h, now_h, 0.0, True, target, curve)
        # Latest contiguous recoverable fix time from now.
        last = curve[0].fix_h
        for c in curve:
            if c.p50 >= target:
                last = c.fix_h
            else:
                break
        still = last >= curve[-1].fix_h
        return PonrResult(
            now_h, None if still else last, None if still else last - now_h, False, target, curve
        )


def _ffill(a: Array) -> Array:
    out = a.copy()
    for r in range(out.shape[0]):
        row = out[r]
        mask = np.isnan(row)
        idx = np.where(~mask, np.arange(len(row)), 0)
        np.maximum.accumulate(idx, out=idx)
        out[r] = row[idx]
        first = np.argmax(~mask) if (~mask).any() else 0
        out[r, :first] = row[first] if (~mask).any() else 0.0
    return np.nan_to_num(out)
