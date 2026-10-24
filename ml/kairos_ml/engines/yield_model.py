"""Engine A: early final-yield predictor (hybrid) with split-conformal intervals.

- Mechanistic prior: current produced penicillin (lab P x V + harvested) plus the
  recent lab production rate extrapolated to the nominal batch end (`prior_kg`).
- ML: equal-weight ensemble of LightGBM and ridge regression on a compact set of
  physically meaningful causal features (the prior is one of them), trained on
  checkpoints sampled through each training batch. The compact set and the
  ensemble were chosen on validation batches (docs/DECISIONS.md): with 60
  training batches, wider feature sets overfit.
- Uncertainty: split conformal on validation batches, per progress band, so the
  interval narrows as the batch matures. Coverage is reported on test batches.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal

import lightgbm as lgb
import numpy as np
import numpy.typing as npt
import pandas as pd
from sklearn.linear_model import RidgeCV
from sklearn.pipeline import Pipeline, make_pipeline
from sklearn.preprocessing import StandardScaler

from kairos_ml.dataset import BatchData

Array = npt.NDArray[np.float64]
BANDS: tuple[float, ...] = (0.0, 0.25, 0.4, 0.6, 2.0)
CHECKPOINT_EVERY_ROWS = 5  # 1 h
MIN_PROGRESS = 0.08

FEATURES: list[str] = [
    "t_h",
    "progress",
    "p_lab",
    "x_lab",
    "p_lab_rate",
    "p_now_kg",
    "prior_kg",
    "harvested_kg",
    "volume_l",
    "our_gmin_cum",
    "cer_gh_cum",
    "feed_lph_cum",
    "do_mgl_mean6h",
    "ph_mean6h",
    "temp_k_mean6h",
    "co2_offgas_pct_mean6h",
    "control_ref",
    "pat_ref",
]


def checkpoint_table(batches: list[BatchData], every: int = CHECKPOINT_EVERY_ROWS) -> pd.DataFrame:
    frames = []
    for b in batches:
        f = b.features.iloc[::every]
        f = f[f["progress"] >= MIN_PROGRESS]
        frames.append(f.assign(batch_id=b.batch_id, target_kg=b.yield_kg))
    return pd.concat(frames, ignore_index=True)


def band_of(progress: Array) -> npt.NDArray[np.int64]:
    return np.clip(np.searchsorted(BANDS, progress, side="right") - 1, 0, len(BANDS) - 2)


def conformal_quantile(scores: Array, alpha: float) -> float:
    n = len(scores)
    if n == 0:
        return float("nan")
    level = min(1.0, np.ceil((n + 1) * (1 - alpha)) / n)
    return float(np.quantile(scores, level, method="higher"))


@dataclass
class YieldModel:
    feature_names: list[str]
    model: lgb.LGBMRegressor
    linear: Pipeline
    golden_yield_kg: float
    # half-widths per progress band, keyed by nominal coverage (0.8, 0.9)
    q: dict[float, list[float]] = field(default_factory=dict)
    unit: str = "kg"

    @classmethod
    def fit(cls, train: list[BatchData], val: list[BatchData], seed: int = 7) -> YieldModel:
        tab = checkpoint_table(train)
        names = list(FEATURES)
        model = lgb.LGBMRegressor(
            n_estimators=600,
            learning_rate=0.03,
            num_leaves=15,
            min_child_samples=40,
            subsample=0.8,
            subsample_freq=1,
            colsample_bytree=0.7,
            reg_lambda=1.0,
            random_state=seed,
            verbose=-1,
        )
        model.fit(tab[names], tab["target_kg"])
        linear = make_pipeline(StandardScaler(), RidgeCV(alphas=np.logspace(-2, 4, 30)))
        linear.fit(tab[names].fillna(0.0), tab["target_kg"])
        golden = float(np.median([b.yield_kg for b in train]))
        ym = cls(names, model, linear, golden)
        ym.calibrate(val)
        return ym

    def calibrate(self, val: list[BatchData]) -> None:
        tab = checkpoint_table(val)
        resid = np.abs(tab["target_kg"].to_numpy() - self.predict_p50(tab))
        bands = band_of(tab["progress"].to_numpy())
        self.q = {
            cov: [conformal_quantile(resid[bands == k], 1 - cov) for k in range(len(BANDS) - 1)]
            for cov in (0.8, 0.9)
        }

    def predict_p50(self, features: pd.DataFrame) -> Array:
        x = features[self.feature_names]
        tree = np.asarray(self.model.predict(x), dtype=float)
        lin = np.asarray(self.linear.predict(x.fillna(0.0)), dtype=float)
        return np.clip(0.5 * tree + 0.5 * lin, 0.0, None)

    def interval(self, features: pd.DataFrame, coverage: float = 0.8) -> tuple[Array, Array, Array]:
        p50 = self.predict_p50(features)
        half = np.asarray(self.q[coverage])[band_of(features["progress"].to_numpy())]
        return p50, np.clip(p50 - half, 0.0, None), p50 + half

    def confidence(self, p50: float, lo: float, hi: float) -> Literal["low", "medium", "high"]:
        rel = (hi - lo) / max(self.golden_yield_kg, 1e-9)
        return "high" if rel < 0.25 else ("medium" if rel < 0.5 else "low")

    def importances(self) -> dict[str, float]:
        gain = self.model.booster_.feature_importance(importance_type="gain")
        total = float(gain.sum()) or 1.0
        return {n: float(g) / total for n, g in zip(self.feature_names, gain, strict=True)}
