"""Engine B: fault detection with false-alarm control.

Layer 1 (scientific reference): batch-dynamic PCA (MSPC) on golden-normalised
monitored variables; Hotelling T2 and SPE with empirical 99% limits from
validation normal batches. Baseline alarm = any point over a limit.

Layer 2 (Kairos): combined ratio r = max(T2/T2_lim, SPE/SPE_lim), EWMA-smoothed,
then a persistence rule (k consecutive rows over the alarm threshold) and
hysteresis on exit. Threshold and k are tuned on validation normal batches only.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

import numpy as np
import numpy.typing as npt
from sklearn.decomposition import PCA

Array = npt.NDArray[np.float64]
State = Literal["normal", "watch", "alarm"]
Z_CLIP = 8.0  # bound single-variable influence on T2/SPE
WARMUP_H = 10.0  # inoculation transient: no alarms before this batch time


@dataclass
class Mspc:
    variables: list[str]
    pca: PCA
    t2_limit: float = 1.0
    spe_limit: float = 1.0

    @classmethod
    def fit(cls, z_train: Array, variables: list[str], var_explained: float = 0.9) -> Mspc:
        pca = PCA(n_components=var_explained, svd_solver="full", random_state=0)
        pca.fit(np.clip(np.nan_to_num(z_train), -Z_CLIP, Z_CLIP))
        return cls(variables, pca)

    def stats(self, z: Array) -> tuple[Array, Array]:
        x = np.clip(np.nan_to_num(z), -Z_CLIP, Z_CLIP)
        scores = self.pca.transform(x)
        t2 = np.sum(scores**2 / self.pca.explained_variance_, axis=1)
        resid = x - self.pca.inverse_transform(scores)
        spe = np.sum(resid**2, axis=1)
        return t2, spe

    def set_limits(self, z_val: Array, q: float = 0.99) -> None:
        t2, spe = self.stats(z_val)
        self.t2_limit = float(np.quantile(t2, q))
        self.spe_limit = float(np.quantile(spe, q))

    def ratio(self, z: Array) -> tuple[Array, Array, Array]:
        t2, spe = self.stats(z)
        return np.maximum(t2 / self.t2_limit, spe / self.spe_limit), t2, spe

    def contributions(self, z_row: Array) -> Array:
        """Per-variable share (sums to 1) mixing T2 and SPE contributions by their ratios."""
        x = np.clip(np.nan_to_num(z_row), -Z_CLIP, Z_CLIP)
        score = self.pca.transform(x[None, :])[0]
        recon = self.pca.inverse_transform(score[None, :])[0]
        spe_c = (x - recon) ** 2
        t2_c = np.abs(((score / self.pca.explained_variance_) @ self.pca.components_) * x)
        t2, spe = self.stats(x[None, :])
        w_t2, w_spe = float(t2[0] / self.t2_limit), float(spe[0] / self.spe_limit)
        mix = w_t2 * t2_c / max(t2_c.sum(), 1e-12) + w_spe * spe_c / max(spe_c.sum(), 1e-12)
        return np.asarray(mix / max(mix.sum(), 1e-12), dtype=float)


@dataclass
class AlarmLogic:
    """EWMA + persistence + hysteresis over the combined MSPC ratio."""

    ewma_lambda: float = 0.2
    watch_threshold: float = 1.0
    alarm_threshold: float = 3.0
    persistence: int = 10
    exit_threshold: float = 0.8
    exit_persistence: int = 10

    def smooth(self, r: Array) -> Array:
        out = np.empty_like(r)
        acc = 0.0
        for i, v in enumerate(np.nan_to_num(r)):
            acc = self.ewma_lambda * v + (1 - self.ewma_lambda) * acc if i else v
            out[i] = acc
        return out

    def states(self, r: Array) -> list[State]:
        s = self.smooth(r)
        states: list[State] = []
        state: State = "normal"
        above_alarm = above_watch = below_exit = 0
        for v in s:
            above_alarm = above_alarm + 1 if v > self.alarm_threshold else 0
            above_watch = above_watch + 1 if v > self.watch_threshold else 0
            below_exit = below_exit + 1 if v < self.exit_threshold else 0
            if state != "alarm" and above_alarm >= self.persistence:
                state = "alarm"
            elif state == "normal" and above_watch >= self.persistence:
                state = "watch"
            elif state != "normal" and below_exit >= self.exit_persistence:
                state = "normal"
            # Hysteresis: alarm and watch persist until the ratio stays below the exit
            # threshold for exit_persistence rows.
            states.append(state)
        return states


def health_score(r_smooth: Array) -> Array:
    """0-100, higher is healthier: 70 at the 99% limit (r = 1), ~37 at r = 2."""
    return np.asarray(100.0 / (1.0 + 0.43 * np.clip(r_smooth, 0, None) ** 2), dtype=float)


def warmup_mask(time_h: Array) -> Array:
    return np.asarray(time_h >= WARMUP_H, dtype=bool)


def first_alarm_index(states: list[State], kind: str = "alarm") -> int | None:
    for i, s in enumerate(states):
        if s == kind:
            return i
    return None


def baseline_alarms(r: Array) -> Array:
    """MSPC baseline: alarm whenever either statistic exceeds its 99% limit."""
    return np.asarray(np.nan_to_num(r) > 1.0, dtype=bool)
