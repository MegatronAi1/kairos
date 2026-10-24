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

    # Fault batches: leave-one-fault-out predictions (each scored by a model that never saw it).
    faults = m.splits["test_fault"]
    yf = np.array([batches[i].yield_kg for i in faults])
    fault_scores = {i: m.score(batches[i]) for i in faults}
    fault_cps = []
    for p in CHECKPOINTS:
        fpreds, los, his = [], [], []
        for i in faults:
            s = fault_scores[i]
            k = int(np.argmin(np.abs(batches[i].features["progress"].to_numpy() - p)))
            fpreds.append(s.p50[k])
            los.append(s.p10[k])
            his.append(s.p90[k])
        lo_a, hi_a = np.array(los), np.array(his)
        fault_cps.append(
            {
                "progress": p,
                "kairos": _errors(np.array(fpreds), yf),
                "naive_mean": _errors(np.full(len(yf), naive_value), yf),
                "coverage_80": float(np.mean((yf >= lo_a) & (yf <= hi_a))),
            }
        )

    return {
        "fault_batches": {
            "method": "leave-one-fault-out; interval widened after the first alarm",
            "true_yield_kg": {str(i): float(v) for i, v in zip(faults, yf, strict=True)},
            "checkpoints": fault_cps,
            "alarm_half_width_kg": {str(k): v for k, v in m.alarm_half_width.items()},
        },
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
            "Yield model trained on normal training batches plus fault batches; fault batches are scored leave-one-fault-out.",
            "Alarm-state interval widths are calibrated and evaluated on the same 10 fault batches.",
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


def energy_metrics(m: KairosModels, batches: dict[int, BatchData]) -> dict[str, Any]:
    """Oxygen-transfer vs energy trade-off on held-out normal batches."""
    from kairos_ml.constants import load_constants
    from kairos_ml.engines.energy import AERATION_GRID, RPM_GRID, EnergyEngine, kla_h, power_kw

    consts = load_constants()
    grid_factor = consts["grid_emission_factor_india"]
    tariff = consts["electricity_tariff_india"]
    test = m.splits["test_normal"]

    def run(margin: float) -> dict[str, Any]:
        eng = EnergyEngine(margin_pct=margin)
        per = []
        for i in test:
            p = eng.batch_policy(batches[i].raw)
            cur, best = (
                float(p["current_kw"].sum()),
                float(p["best_kw"].sum()),
            )  # 1 h decisions -> kWh
            below_cur = float(np.mean(p["current_do"] < eng.target_do))
            below_best = float(np.mean(p["best_do"] < eng.target_do))
            per.append(
                {
                    "batch": i,
                    "kwh_now": cur,
                    "kwh_kairos": best,
                    "saving_pct": 100 * (1 - best / cur),
                    "hours_below_target_now_pct": 100 * below_cur,
                    "hours_below_target_kairos_pct": 100 * below_best,
                }
            )
        saved = float(np.mean([r["kwh_now"] - r["kwh_kairos"] for r in per]))
        return {
            "margin_pct": margin,
            "target_do_pct": eng.target_do,
            "mean_saving_pct": float(np.mean([r["saving_pct"] for r in per])),
            "kwh_saved_per_batch": saved,
            "co2_saved_kg_per_batch": saved * grid_factor.value,
            "inr_saved_per_batch": saved * tariff.value,
            "per_batch": per,
        }

    main = run(10.0)
    sensitivity = [
        {k: v for k, v in run(mg).items() if k != "per_batch"} for mg in (5.0, 15.0, 20.0, 30.0)
    ]

    # Pareto: hold one setting for a whole representative batch; energy vs oxygen safety.
    rep = batches[test[0]].raw
    rep = rep[rep["time_h"] >= 10.0]
    k_now = kla_h(rep["rpm"], rep["aeration_lph"], rep["volume_l"])
    deficit = np.clip(100.0 - rep["do_pct_sat"].to_numpy(), 0, None)
    dt = float(np.median(np.diff(rep["time_h"].to_numpy())))
    target = EnergyEngine().target_do
    pareto = []
    for rpm in RPM_GRID:
        for aer in AERATION_GRID:
            k_new = kla_h(np.full(len(rep), rpm), np.full(len(rep), aer), rep["volume_l"])
            do = 100.0 - deficit * k_now / k_new
            pareto.append(
                {
                    "rpm": float(rpm),
                    "aeration": float(aer),
                    "kwh": float(power_kw([rpm], [aer])[0]) * dt * len(rep),
                    "do_p5_pct": float(np.percentile(do, 5)),
                    "hours_below_target_pct": float(100 * np.mean(do < target)),
                }
            )
    actual_kwh = float((rep["power_kw"] * dt).sum())

    # Yield check: does the lower-DO trajectory change the yield forecast?
    eng = EnergyEngine()
    deltas = []
    for i in test:
        b = batches[i]
        p = eng.batch_policy(b.raw, every=1)
        do_new = np.interp(b.raw["time_h"], p["time_h"], p["best_do"])
        c_star = b.raw["c_star_mg_l"].to_numpy()
        feats = b.features.copy()
        new_mgl = pd.Series(do_new * c_star / 100.0).rolling(30, min_periods=1).mean().to_numpy()
        feats["do_mgl_mean6h"] = np.where(b.raw["time_h"] >= 10.0, new_mgl, feats["do_mgl_mean6h"])
        k = int(np.argmin(np.abs(feats["progress"].to_numpy() - 0.7)))
        base = m.yield_model.predict_p50(b.features.iloc[[k]])[0]
        new = m.yield_model.predict_p50(feats.iloc[[k]])[0]
        deltas.append(100 * (new - base) / base)

    return {
        "provenance": "synthetic data; power, kLa and the oxygen balance use published correlations with assumed geometry and efficiencies",
        "method": "Live oxygen demand inferred from measured DO and van't Riet kLa (quasi-steady balance); cheapest setting keeping DO >= critical + margin, step-limited (aeration >= 70% of current, agitation +-10%), decided hourly.",
        "constants": {
            k: {"value": c.value, "unit": c.unit, "provenance": c.provenance}
            for k, c in consts.items()
            if k
            in (
                "critical_do_fraction",
                "compressor_specific_power",
                "impeller_power_number",
                "gassed_power_ratio",
                "grid_emission_factor_india",
                "electricity_tariff_india",
            )
        },
        **main,
        "sensitivity": sensitivity,
        "pareto": {
            "batch": test[0],
            "actual_kwh": actual_kwh,
            "target_do_pct": target,
            "points": pareto,
        },
        "yield_check_pct_change_at_70pct": {
            "mean": float(np.mean(deltas)),
            "min": float(np.min(deltas)),
            "max": float(np.max(deltas)),
        },
        "notes": [
            "Agitation is constant in IndPenSim, so agitation effects are physics-only (assumed).",
            "Quasi-steady oxygen balance; kLa in viscous broths can be lower than van't Riet predicts.",
            "Savings are model estimates; a pilot would confirm them with step tests.",
        ],
    }
