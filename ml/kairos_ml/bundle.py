"""Trained-artifact bundle: everything the backend needs, saved as one joblib file."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import joblib
import numpy as np
import numpy.typing as npt

from kairos_ml.dataset import BatchData
from kairos_ml.engines.fault_detector import AlarmLogic, Mspc, State, health_score, warmup_mask
from kairos_ml.engines.yield_model import YieldModel
from kairos_ml.features.golden import GoldenTrajectory

Array = npt.NDArray[np.float64]
ARTIFACTS_DIR = Path("artifacts")
BUNDLE_PATH = ARTIFACTS_DIR / "models" / "kairos.joblib"


@dataclass
class BatchScores:
    """Causal per-row engine outputs for one batch (row i uses rows <= i only)."""

    p50: Array
    p10: Array
    p90: Array
    ratio: Array  # raw MSPC ratio
    ratio_smooth: Array
    health: Array
    states: list[State]
    t2: Array
    spe: Array


@dataclass
class KairosModels:
    golden: GoldenTrajectory
    yield_model: YieldModel
    mspc: Mspc
    alarm: AlarmLogic
    splits: dict[str, list[int]]
    onsets: dict[int, dict[str, object]]
    meta: dict[str, object] = field(default_factory=dict)

    def save(self, path: Path = BUNDLE_PATH) -> Path:
        path.parent.mkdir(parents=True, exist_ok=True)
        joblib.dump(self, path, compress=3)
        return path

    @staticmethod
    def load(path: Path = BUNDLE_PATH) -> KairosModels:
        obj = joblib.load(path)
        if not isinstance(obj, KairosModels):
            raise TypeError(f"{path} is not a KairosModels bundle")
        return obj

    def score(self, b: BatchData) -> BatchScores:
        p50, lo, hi = self.yield_model.interval(b.features, coverage=0.8)
        ratio, t2, spe = self.mspc.ratio(b.zscores.to_numpy())
        ratio = np.where(warmup_mask(b.raw["time_h"].to_numpy()), ratio, 0.0)
        smooth = self.alarm.smooth(ratio)
        return BatchScores(
            p50=p50,
            p10=lo,
            p90=hi,
            ratio=ratio,
            ratio_smooth=smooth,
            health=health_score(smooth),
            states=self.alarm.states(ratio),
            t2=t2,
            spe=spe,
        )
