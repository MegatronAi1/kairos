"""Causal per-row features from cheap online sensors (spec 7.0).

Every feature at row i uses only rows <= i. Offline lab values are forward-filled
from their sample time only (never back-filled). Raman, simulator-only states
(online penicillin, substrate) are excluded.
"""

from __future__ import annotations

import numpy as np
import pandas as pd

from kairos_ml.features.derived import compute_derived
from kairos_ml.features.golden import DT_H, GoldenTrajectory

NOMINAL_BATCH_H = 230.0

# Online sensors and manipulated inputs available on an ordinary plant.
ONLINE: list[str] = [
    "aeration_lph",
    "feed_lph",
    "pressure_bar",
    "acid_lph",
    "base_lph",
    "cooling_lph",
    "heating_lph",
    "water_lph",
    "paa_lph",
    "oil_lph",
    "do_mgl",
    "ph",
    "temp_k",
    "co2_offgas_pct",
    "o2_offgas_frac",
    "our_gmin",
    "cer_gh",
    "volume_l",
]

# Process responses monitored by the fault detector (golden-normalised). Manipulated
# inputs (feed, aeration) are excluded: the detector must see the process react,
# not just notice that an input changed.
MONITORED: list[str] = [
    "acid_lph",
    "base_lph",
    "cooling_lph",
    "heating_lph",
    "do_mgl",
    "ph",
    "temp_k",
    "co2_offgas_pct",
    "o2_offgas_frac",
    "our_gmin",
    "cer_gh",
]

ROLLING: list[str] = [
    "do_mgl",
    "ph",
    "temp_k",
    "co2_offgas_pct",
    "o2_offgas_frac",
    "our_gmin",
    "cer_gh",
    "base_lph",
    "cooling_lph",
]
CUMULATIVE: list[str] = [
    "feed_lph",
    "base_lph",
    "acid_lph",
    "aeration_lph",
    "paa_lph",
    "oil_lph",
    "water_lph",
    "our_gmin",
    "cer_gh",
]
WINDOWS_H = (1, 6)


def _rows(hours: float) -> int:
    return max(1, round(hours / DT_H))


def add_derived(df: pd.DataFrame) -> pd.DataFrame:
    d = compute_derived(
        temp_k=df["temp_k"],
        o2_offgas_frac=df["o2_offgas_frac"],
        do_mgl=df["do_mgl"],
        pressure_bar=df["pressure_bar"],
        our_gmin=df["our_gmin"],
        cer_gh=df["cer_gh"],
        volume_l=df["volume_l"],
        rpm=df["rpm"],
        aeration=df["aeration_lph"],
    )
    out = df.copy()
    for k, v in d.__dict__.items():
        out[k] = v
    out["kwh_cum"] = np.cumsum(
        out["power_kw"].to_numpy() * np.diff(out["time_h"].to_numpy(), prepend=0.0)
    )
    return out


def _slope(s: pd.Series, n: int) -> pd.Series:
    return (s - s.shift(n)) / (n * DT_H)


def lab_features(df: pd.DataFrame) -> pd.DataFrame:
    """Last lab penicillin/biomass, sample age, production rate between the last two
    samples, harvested penicillin so far, and a mechanistic projection of total yield."""
    t = df["time_h"]
    out = pd.DataFrame(index=df.index)
    for col, name in (("penicillin_offline", "p_lab"), ("biomass_offline", "x_lab")):
        s = df[col]
        out[name] = s.ffill().fillna(0.0)
        sampled_t = t.where(s.notna())
        out[f"{name}_age_h"] = (t - sampled_t.ffill()).fillna(t)
    p = df["penicillin_offline"]
    p_t = t.where(p.notna())
    prev_p = p.where(p.notna()).ffill().shift(1).where(p.notna())
    prev_pt = p_t.ffill().shift(1).where(p.notna())
    rate = ((p - prev_p) / (p_t - prev_pt)).replace([np.inf, -np.inf], np.nan)
    out["p_lab_rate"] = rate.ffill().fillna(0.0).clip(lower=0.0)
    removed_l = (-df["dumped_lph"]).clip(lower=0) * np.diff(t.to_numpy(), prepend=0.0)
    out["harvested_kg"] = (out["p_lab"] * removed_l / 1000.0).cumsum()
    v = df["volume_l"]
    out["p_now_kg"] = out["p_lab"] * v / 1000.0 + out["harvested_kg"]
    remaining = (NOMINAL_BATCH_H - t).clip(lower=0.0)
    out["prior_kg"] = out["p_now_kg"] + out["p_lab_rate"] * v / 1000.0 * remaining
    return out


def batch_features(df: pd.DataFrame, golden: GoldenTrajectory) -> pd.DataFrame:
    """Feature table for one batch (rows aligned with df). `df` sorted by time."""
    df = df.reset_index(drop=True)
    feats: dict[str, pd.Series] = {
        "t_h": df["time_h"],
        "progress": (df["time_h"] / NOMINAL_BATCH_H).clip(upper=1.2),
    }
    for c in ONLINE:
        feats[c] = df[c]
    for c in ROLLING:
        for w in WINDOWS_H:
            feats[f"{c}_mean{w}h"] = df[c].rolling(_rows(w), min_periods=1).mean()
        feats[f"{c}_slope3h"] = _slope(df[c], _rows(3)).fillna(0.0)
    dt = np.diff(df["time_h"].to_numpy(), prepend=0.0)
    for c in CUMULATIVE:
        feats[f"{c}_cum"] = (df[c] * dt).cumsum()
    z = golden.zscores(df)
    for c in golden.variables:
        feats[f"z_{c}_6h"] = z[c].rolling(_rows(6), min_periods=1).mean()
    out = pd.DataFrame(feats)
    return pd.concat([out, lab_features(df)], axis=1)


def feature_columns(frame: pd.DataFrame) -> list[str]:
    return [c for c in frame.columns if c not in {"batch_id", "target_kg"}]
