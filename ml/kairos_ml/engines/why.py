"""Engine C: explainability.

The yield model is an equal-weight ensemble of LightGBM and ridge, so attributions
are exactly additive: 0.5 x TreeSHAP(tree) + 0.5 x linear contribution (coef x
standardised deviation). Interactions come from SHAP interaction values on the
tree half only (the linear half has none by construction).
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import numpy.typing as npt
import pandas as pd
import shap

from kairos_ml.engines.yield_model import YieldModel

Array = npt.NDArray[np.float64]

LABELS: dict[str, str] = {
    "t_h": "batch time",
    "progress": "batch progress",
    "p_lab": "lab penicillin",
    "x_lab": "lab biomass",
    "p_lab_rate": "penicillin production rate",
    "p_now_kg": "penicillin made so far",
    "prior_kg": "mechanistic projection",
    "harvested_kg": "penicillin harvested so far",
    "volume_l": "broth volume",
    "our_gmin_cum": "cumulative oxygen uptake",
    "cer_gh_cum": "cumulative CO2 evolution",
    "feed_lph_cum": "cumulative sugar fed",
    "do_mgl_mean6h": "dissolved oxygen (6 h mean)",
    "ph_mean6h": "pH (6 h mean)",
    "temp_k_mean6h": "temperature (6 h mean)",
    "co2_offgas_pct_mean6h": "off-gas CO2 (6 h mean)",
    "control_ref": "operator control",
    "pat_ref": "Raman PAT control",
}


def label(name: str) -> str:
    return LABELS.get(name, name.replace("_", " "))


@dataclass
class Driver:
    feature: str
    label: str
    importance: float  # mean |attribution| in kg
    share: float


@dataclass
class Interaction:
    a: str
    b: str
    strength: float  # mean |interaction| in kg
    sentence: str


class WhyEngine:
    def __init__(self, model: YieldModel) -> None:
        self.model = model
        self.explainer = shap.TreeExplainer(model.model)
        ridge = model.linear[-1]
        scaler = model.linear[0]
        self._coef = np.asarray(ridge.coef_, dtype=float)
        self._mean = np.asarray(scaler.mean_, dtype=float)
        self._scale = np.asarray(scaler.scale_, dtype=float)

    def attributions(self, x: pd.DataFrame) -> Array:
        """Per-row, per-feature contribution (kg) to the ensemble prediction."""
        xf = x[self.model.feature_names]
        tree = np.asarray(self.explainer.shap_values(xf), dtype=float)
        lin = self._coef * (xf.fillna(0.0).to_numpy(dtype=float) - self._mean) / self._scale
        return np.asarray(0.5 * tree + 0.5 * lin, dtype=float)

    def drivers(self, x: pd.DataFrame, top: int = 8) -> list[Driver]:
        imp = np.mean(np.abs(self.attributions(x)), axis=0)
        total = float(imp.sum()) or 1.0
        order = np.argsort(-imp)[:top]
        names = self.model.feature_names
        return [
            Driver(names[i], label(names[i]), float(imp[i]), float(imp[i] / total)) for i in order
        ]

    def interactions(
        self, x: pd.DataFrame, top: int = 5, sample: int = 1500, seed: int = 0
    ) -> list[Interaction]:
        xf = x[self.model.feature_names]
        if len(xf) > sample:
            xf = xf.sample(sample, random_state=seed)
        iv = np.asarray(self.explainer.shap_interaction_values(xf), dtype=float)
        strength = 0.5 * np.mean(np.abs(iv), axis=0) * 2  # off-diagonal is split in half
        np.fill_diagonal(strength, 0.0)
        names = self.model.feature_names
        pairs = []
        n = len(names)
        for i in range(n):
            for j in range(i + 1, n):
                pairs.append((strength[i, j], i, j))
        pairs.sort(reverse=True)
        out = []
        for s, i, j in pairs[:top]:
            out.append(Interaction(names[i], names[j], float(s), self._sentence(xf, iv, i, j)))
        return out

    def _sentence(self, xf: pd.DataFrame, iv: Array, i: int, j: int) -> str:
        """Plain-language direction: does a high value of A help more when B is high or low?"""
        names = self.model.feature_names
        a, b = xf.iloc[:, i].to_numpy(dtype=float), xf.iloc[:, j].to_numpy(dtype=float)
        inter = iv[:, i, j] + iv[:, j, i]
        hi_b = b >= np.nanmedian(b)
        hi_a = a >= np.nanmedian(a)
        effect_hi = float(np.mean(inter[hi_a & hi_b])) if np.any(hi_a & hi_b) else 0.0
        effect_lo = float(np.mean(inter[hi_a & ~hi_b])) if np.any(hi_a & ~hi_b) else 0.0
        better = "high" if effect_hi > effect_lo else "low"
        return (
            f"High {label(names[i])} lifts predicted yield more when {label(names[j])} is {better} "
            f"(interaction about {abs(effect_hi - effect_lo) * 0.5:.0f} kg)."
        )

    def local(self, row: pd.DataFrame, top: int = 5) -> list[tuple[str, float]]:
        """What is pushing this batch's forecast up or down right now (kg)."""
        att = self.attributions(row)[0]
        order = np.argsort(-np.abs(att))[:top]
        return [(self.model.feature_names[i], float(att[i])) for i in order]
