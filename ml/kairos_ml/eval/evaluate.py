"""Evaluation: every number on the Evidence page and in the deck comes from here.

Writes artifacts/metrics/{yield,faults,drivers}.json deterministically.
"""

from __future__ import annotations

import json
from collections.abc import Sequence
from pathlib import Path
from typing import Any

import numpy as np
import numpy.typing as npt
import pandas as pd

from kairos_ml.bundle import ARTIFACTS_DIR, KairosModels
from kairos_ml.dataset import BatchData
from kairos_ml.engines.fault_detector import AlarmLogic, warmup_mask
from kairos_ml.engines.why import WhyEngine, label
from kairos_ml.engines.yield_model import checkpoint_table

Array = npt.NDArray[np.float64]
METRICS_DIR = ARTIFACTS_DIR / "metrics"
CHECKPOINTS = (0.2, 0.3, 0.5, 0.7)
PROVENANCE = "synthetic (IndPenSim simulator)"


def _row_at(b: BatchData, progress: float) -> pd.DataFrame:
    i = int(np.argmin(np.abs(b.features["progress"].to_numpy() - progress)))
    return b.features.iloc[[i]]


def _errors(pred: Array, y: Array) -> dict[str, float]:
    err = pred - y
    ss_res = float(np.sum(err**2))
    ss_tot = float(np.sum((y - y.mean()) ** 2)) or 1.0
    return {
        "mae": float(np.mean(np.abs(err))),
        "rmse": float(np.sqrt(np.mean(err**2))),
        "mape_pct": float(100 * np.mean(np.abs(err) / np.maximum(y, 1e-9))),
        "r2": 1.0 - ss_res / ss_tot,
    }


def yield_metrics(m: KairosModels, batches: dict[int, BatchData]) -> dict[str, Any]:
    ym = m.yield_model
    train = [batches[i] for i in m.splits["train"]]
    test = [batches[i] for i in m.splits["test_normal"]]
    y = np.array([b.yield_kg for b in test])
    naive_value = float(np.mean([b.yield_kg for b in train]))

    def predictors(rows: pd.DataFrame) -> dict[str, Array]:
        x = rows[ym.feature_names]
        return {
            "kairos": ym.predict_p50(rows),
            "naive_mean": np.full(len(rows), naive_value),
            "linear": np.asarray(ym.linear.predict(x.fillna(0.0)), dtype=float),
            "mechanistic_prior": rows["prior_kg"].to_numpy(dtype=float),
        }

    checkpoints = []
    for p in CHECKPOINTS:
        rows = pd.concat([_row_at(b, p) for b in test])
        preds = predictors(rows)
        entry: dict[str, Any] = {
            "progress": p,
            "models": {k: _errors(v, y) for k, v in preds.items()},
        }
        for cov in (0.8, 0.9):
            _, lo, hi = ym.interval(rows, coverage=cov)
            entry[f"coverage_{int(cov * 100)}"] = float(np.mean((y >= lo) & (y <= hi)))
            entry[f"mean_width_{int(cov * 100)}_kg"] = float(np.mean(hi - lo))
        checkpoints.append(entry)

    curve = []
    for p in np.round(np.arange(0.1, 0.951, 0.05), 2):
        rows = pd.concat([_row_at(b, float(p)) for b in test])
        preds = predictors(rows)
        curve.append(
            {"progress": float(p), **{k: float(np.mean(np.abs(v - y))) for k, v in preds.items()}}
        )

    # Overall interval coverage on all hourly test checkpoints.
    tab = checkpoint_table(test)
    overall = {}
    for cov in (0.8, 0.9):
        _, lo, hi = ym.interval(tab, coverage=cov)
        t = tab["target_kg"].to_numpy()
        overall[f"coverage_{int(cov * 100)}"] = float(np.mean((t >= lo) & (t <= hi)))

    return {
        "target": "total penicillin produced per batch (kg) = mid-batch harvests + final P x V",
        "unit": "kg",
        "provenance": PROVENANCE,
        "n_test_batches": len(test),
        "test_batches": m.splits["test_normal"],
        "test_yield_range_kg": [float(y.min()), float(y.max())],
        "typical_yield_kg": ym.golden_yield_kg,
        "checkpoints": checkpoints,
        "convergence_curve_mae_kg": curve,
        "overall_hourly_coverage": overall,
        "conformal_half_widths_kg": {str(k): v for k, v in ym.q.items()},
        "notes": [
            "Test batches were never used for training, calibration, or model selection.",
            "Conformal intervals calibrated on 15 validation batches per progress band.",
            "Only 15 test batches: treat errors as indicative, not precise.",
        ],
    }


def _episodes(flags: npt.NDArray[np.bool_]) -> int:
    f = flags.astype(int)
    return int(np.sum(np.diff(np.concatenate([[0], f])) == 1))


def _alarm_entries(states: Sequence[str]) -> int:
    return sum(
        1 for i, s in enumerate(states) if s == "alarm" and (i == 0 or states[i - 1] != "alarm")
    )


def fault_metrics(m: KairosModels, batches: dict[int, BatchData]) -> dict[str, Any]:
    def ratio(b: BatchData) -> Array:
        r, _, _ = m.mspc.ratio(b.zscores.to_numpy())
        return np.where(warmup_mask(b.raw["time_h"].to_numpy()), r, 0.0)

    ratios = {
        i: ratio(batches[i])
        for i in [*m.splits["test_normal"], *m.splits["test_fault"], *m.splits["val"]]
    }

    def evaluate(logic: AlarmLogic) -> dict[str, Any]:
        per_fault = []
        for i in m.splits["test_fault"]:
            b = batches[i]
            t = b.raw["time_h"].to_numpy()
            onset = float(m.onsets[i]["onset_h"])  # type: ignore[arg-type]
            st = logic.states(ratios[i])
            after = [k for k, s in enumerate(st) if s == "alarm" and t[k] >= onset]
            before = [k for k, s in enumerate(st) if s == "alarm" and t[k] < onset]
            base = np.flatnonzero((ratios[i] > 1.0) & (t >= onset))
            per_fault.append(
                {
                    "batch": i,
                    "onset_h": onset,
                    "onset_method": m.onsets[i]["method"],
                    "fault_variable": m.onsets[i]["variable"],
                    "detected": bool(after),
                    "first_alarm_h": float(t[after[0]]) if after else None,
                    "delay_h": float(t[after[0]] - onset) if after else None,
                    "alarm_before_onset": bool(before),
                    "baseline_first_alarm_h": float(t[base[0]]) if len(base) else None,
                    "baseline_delay_h": float(t[base[0]] - onset) if len(base) else None,
                }
            )
        normal_hours = 0.0
        kairos_fa = baseline_fa = 0
        per_normal = []
        for i in m.splits["test_normal"]:
            t = batches[i].raw["time_h"].to_numpy()
            st = logic.states(ratios[i])
            k_fa, b_fa = _alarm_entries(st), _episodes(ratios[i] > 1.0)
            kairos_fa += k_fa
            baseline_fa += b_fa
            normal_hours += float(t[-1])
            per_normal.append(
                {"batch": i, "kairos_false_alarms": k_fa, "baseline_false_alarms": b_fa}
            )
        delays = [float(str(f["delay_h"])) for f in per_fault if f["delay_h"] is not None]
        base_delays = [
            float(str(f["baseline_delay_h"]))
            for f in per_fault
            if f["baseline_delay_h"] is not None
        ]
        n_normal = len(m.splits["test_normal"])
        return {
            "per_fault_batch": per_fault,
            "per_normal_batch": per_normal,
            "summary": {
                "kairos": {
                    "detected": sum(f["detected"] for f in per_fault),
                    "n_fault_batches": len(per_fault),
                    "median_delay_h": float(np.median(delays)) if delays else None,
                    "false_alarms_per_batch": kairos_fa / n_normal,
                    "false_alarms_per_100_batch_hours": 100 * kairos_fa / normal_hours,
                },
                "mspc_baseline": {
                    "detected": len(base_delays),
                    "n_fault_batches": len(per_fault),
                    "median_delay_h": float(np.median(base_delays)) if base_delays else None,
                    "false_alarms_per_batch": baseline_fa / n_normal,
                    "false_alarms_per_100_batch_hours": 100 * baseline_fa / normal_hours,
                },
            },
        }

    main = evaluate(m.alarm)
    tradeoff = []
    for thr in (1.5, 2.0, 2.5, 3.0, 4.0, 5.0):
        for k in (5, 10, 20):
            s = evaluate(AlarmLogic(alarm_threshold=thr, persistence=k))["summary"]["kairos"]
            tradeoff.append({"threshold": thr, "persistence_rows": k, **s})
    return {
        "provenance": PROVENANCE,
        "detector": {
            "mspc_components": int(m.mspc.pca.n_components_),
            "t2_limit_99": m.mspc.t2_limit,
            "spe_limit_99": m.mspc.spe_limit,
            "alarm_threshold": m.alarm.alarm_threshold,
            "persistence_rows": m.alarm.persistence,
            "persistence_h": m.alarm.persistence * 0.2,
            "ewma_lambda": m.alarm.ewma_lambda,
            "selection_rule": "smallest persistence, then smallest threshold, with zero alarms on validation normal batches",
            "monitored": m.mspc.variables,
        },
        **main,
        "tradeoff": tradeoff,
        "notes": [
            "Fault onsets are exact for input-step faults (departure from the recipe) and estimated for the rest.",
            "Only 10 fault batches and 15 test normal batches: rates are indicative.",
            "Baseline = classic MSPC: alarm whenever T2 or SPE exceeds its 99% limit (no smoothing or persistence).",
        ],
    }


def driver_metrics(m: KairosModels, batches: dict[int, BatchData]) -> dict[str, Any]:
    why = WhyEngine(m.yield_model)
    tab = checkpoint_table([batches[i] for i in m.splits["train"]])
    drivers = why.drivers(tab)
    inter = why.interactions(tab)
    return {
        "provenance": PROVENANCE,
        "method": "Exact additive attribution for the ensemble: 0.5 x TreeSHAP + 0.5 x linear contribution",
        "drivers": [d.__dict__ for d in drivers],
        "interactions": [
            {
                "a": i.a,
                "b": i.b,
                "a_label": label(i.a),
                "b_label": label(i.b),
                "strength_kg": i.strength,
                "sentence": i.sentence,
            }
            for i in inter
        ],
    }


def write(name: str, payload: dict[str, Any], out_dir: Path = METRICS_DIR) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{name}.json"
    path.write_text(json.dumps(payload, indent=2, default=float) + "\n", encoding="utf-8")
    return path
