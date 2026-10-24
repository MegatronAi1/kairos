"""Agent tools: thin, read-only wrappers over the engines (spec 8.3).

Each tool returns plain JSON. Every number the agent states must come from here.
`EVIDENCE` maps tools to the evidence chips the UI shows ("Based on: ...").
"""

from __future__ import annotations

import json
from collections.abc import Callable
from functools import cached_property
from pathlib import Path
from typing import Any

from app.agent.templates import label
from app.state import AppState

Json = dict[str, Any]

EVIDENCE: dict[str, str] = {
    "get_reactor_state": "live_sensors",
    "list_fleet": "live_sensors",
    "predict_final_yield": "yield_model",
    "explain_drivers": "why_engine",
    "diagnose_alarm": "fault_detector",
    "recommend_settings": "energy_model",
    "simulate_what_if": "what_if",
    "estimate_point_of_no_return": "ponr",
    "get_model_evidence": "evaluation",
    "get_data_provenance": "provenance",
}

_REACTOR = {
    "type": "object",
    "properties": {"reactor_id": {"type": "string", "description": "Reactor ID, e.g. PUN-R2"}},
    "required": ["reactor_id"],
}

SPECS: list[Json] = [
    {
        "name": "list_fleet",
        "description": "Every reactor in the company: ID, plant, process, health state, health score, yield forecast as % of a typical batch, dissolved oxygen and agitation+aeration power. Use it for fleet-wide questions.",
        "schema": {"type": "object", "properties": {}},
    },
    {
        "name": "get_reactor_state",
        "description": "Latest sensors, derived signals (power, OUR, kLa), batch progress, health state and forecast for a reactor.",
        "schema": _REACTOR,
    },
    {
        "name": "predict_final_yield",
        "description": "Early forecast of total penicillin produced (kg) with an 80% interval, percent of a typical batch, and the model's measured accuracy at this progress.",
        "schema": _REACTOR,
    },
    {
        "name": "explain_drivers",
        "description": "What drives the yield forecast. scope='local': what pushes this reactor's forecast up or down now. scope='global': top drivers and interactions across all training batches.",
        "schema": {
            "type": "object",
            "properties": {
                "reactor_id": {"type": "string"},
                "scope": {"type": "string", "enum": ["local", "global"]},
            },
            "required": ["scope"],
        },
    },
    {
        "name": "diagnose_alarm",
        "description": "Fault detector view: health score, state and since when, T2/SPE versus limits, and the variables deviating most from normal batches (with direction).",
        "schema": _REACTOR,
    },
    {
        "name": "recommend_settings",
        "description": "Energy-saving or rescue setpoint recommendation (agitation, aeration, feed) with expected yield and energy effect.",
        "schema": {
            "type": "object",
            "properties": {
                "reactor_id": {"type": "string"},
                "mode": {"type": "string", "enum": ["energy", "rescue"]},
            },
            "required": ["reactor_id"],
        },
    },
    {
        "name": "simulate_what_if",
        "description": "Counterfactual: projected final yield and energy if setpoints change at a given batch time.",
        "schema": {
            "type": "object",
            "properties": {
                "reactor_id": {"type": "string"},
                "at_h": {"type": "number"},
                "changes": {
                    "type": "object",
                    "description": 'e.g. {"feed_pct": -10, "aeration_pct": 0}',
                },
            },
            "required": ["reactor_id"],
        },
    },
    {
        "name": "estimate_point_of_no_return",
        "description": "Hours left before the best correction can no longer recover 90% of a normal batch yield.",
        "schema": _REACTOR,
    },
    {
        "name": "get_model_evidence",
        "description": "Measured accuracy of Kairos models on held-out batches: yield error by progress, interval coverage, fault detection rate, delay and false alarms.",
        "schema": {"type": "object", "properties": {}},
    },
    {
        "name": "get_data_provenance",
        "description": "Whether a value is measured, published, assumed or synthetic, with its source. Pass a sensor key or constant name, or omit for the data source summary.",
        "schema": {"type": "object", "properties": {"field": {"type": "string"}}},
    },
]


def bedrock_tool_config() -> Json:
    return {
        "tools": [
            {
                "toolSpec": {
                    "name": s["name"],
                    "description": s["description"],
                    "inputSchema": {"json": s["schema"]},
                }
            }
            for s in SPECS
        ]
    }


def _r(v: Any, nd: int = 2) -> Any:
    return round(v, nd) if isinstance(v, float) else v


class ToolBox:
    def list_fleet(self) -> Json:
        plants = {p.id: p for p in getattr(self.state.tenant, "plants", [])}
        rows: list[Json] = []
        for r in self.state.engine.reactors.values():
            t = r.last_tick
            plant = plants.get(r.plant_id)
            rows.append(
                {
                    "reactor_id": r.id,
                    "plant": plant.name if plant else r.plant_id,
                    "process_id": plant.process_id if plant else None,
                    "state": r.state,
                    "acknowledged": r.acknowledged,
                    "health_score": round(t.health.score, 1) if t and t.health else None,
                    "yield_kg_p50": round(t.forecast.p50) if t and t.forecast else None,
                    "yield_vs_typical_pct": round(t.forecast.vs_golden_pct, 1)
                    if t and t.forecast
                    else None,
                    "do_pct": t.sensors.get("do_pct") if t else None,
                    "power_kw": t.derived.get("power_kw") if t else None,
                    "progress_pct": round(t.progress * 100, 1) if t else None,
                }
            )
        order = {"alarm": 0, "watch": 1, "normal": 2}
        rows.sort(key=lambda x: (order.get(str(x["state"]), 3), x["health_score"] or 100))
        return {
            "reactors": rows,
            "provenance": "live replay of held-out IndPenSim batches (synthetic)",
        }

    def __init__(self, state: AppState, metrics_dir: Path) -> None:
        self.state = state
        self.metrics_dir = metrics_dir
        self._fns: dict[str, Callable[..., Json]] = {
            "list_fleet": self.list_fleet,
            "get_reactor_state": self.get_reactor_state,
            "predict_final_yield": self.predict_final_yield,
            "explain_drivers": self.explain_drivers,
            "diagnose_alarm": self.diagnose_alarm,
            "recommend_settings": self.recommend_settings,
            "simulate_what_if": self.simulate_what_if,
            "estimate_point_of_no_return": self.estimate_point_of_no_return,
            "get_model_evidence": self.get_model_evidence,
            "get_data_provenance": self.get_data_provenance,
        }

    def call(self, name: str, args: Json) -> Json:
        fn = self._fns.get(name)
        if fn is None:
            return {"error": f"unknown tool {name}"}
        try:
            return fn(**args)
        except KeyError as e:
            return {"error": f"not found: {e}"}
        except TypeError as e:
            return {"error": f"bad arguments: {e}"}

    # --- helpers -------------------------------------------------------------
    def _reactor(self, reactor_id: str) -> Any:
        r = self.state.engine.reactors.get(reactor_id.upper())
        if r is None:
            raise KeyError(f"reactor {reactor_id}; known: {sorted(self.state.engine.reactors)}")
        return r

    @property
    def _ml(self) -> Any:
        return (
            getattr(self.state.engine.pipeline.engines, "models", None)
            and self.state.engine.pipeline.engines
        )

    def _metrics(self, name: str) -> Json:
        path = self.metrics_dir / f"{name}.json"
        if not path.exists():
            return {}
        data: Json = json.loads(path.read_text(encoding="utf-8"))
        return data

    @cached_property
    def _why(self) -> Any:
        from kairos_ml.engines.why import WhyEngine

        return WhyEngine(self._ml.models.yield_model)

    # --- tools ---------------------------------------------------------------
    def get_reactor_state(self, reactor_id: str) -> Json:
        r = self._reactor(reactor_id)
        t = r.last_tick
        if t is None:
            return {"reactor_id": r.id, "status": "no data yet"}
        return {
            "reactor_id": r.id,
            "batch_id": r.batch.batch_id,
            "strategy": r.batch.strategy,
            "t_h": t.t_h,
            "progress_pct": round(100 * t.progress, 1),
            "state": r.state,
            "acknowledged": r.acknowledged,
            "sensors": {k: v for k, v in t.sensors.items() if v is not None},
            "derived": {k: v for k, v in t.derived.items() if v is not None},
            "forecast": t.forecast.model_dump() if t.forecast else None,
            "health_score": t.health.score if t.health else None,
            "provenance": "synthetic (IndPenSim); power/kLa/OTR use assumed geometry",
        }

    def predict_final_yield(self, reactor_id: str) -> Json:
        r = self._reactor(reactor_id)
        t = r.last_tick
        if t is None or t.forecast is None:
            return {
                "reactor_id": r.id,
                "available": False,
                "reason": "no forecast yet (model not loaded or batch just started)",
            }
        f = t.forecast
        acc = self._accuracy_near(t.progress)
        return {
            "reactor_id": r.id,
            "p50_kg": f.p50,
            "interval_80pct_kg": [f.p10, f.p90],
            "percent_of_typical_batch": f.vs_golden_pct,
            "confidence": f.confidence,
            "progress_pct": round(100 * t.progress, 1),
            "measured_accuracy_near_this_progress": acc,
            "note": "Model estimate trained on simulated normal batches; for fault batches the forecast lags the fault.",
        }

    def _accuracy_near(self, progress: float) -> Json | None:
        y = self._metrics("yield")
        cps = y.get("checkpoints", [])
        if not cps:
            return None
        cp = min(cps, key=lambda c: abs(c["progress"] - progress))
        k = cp["models"]["kairos"]
        return {
            "at_progress": cp["progress"],
            "mae_kg": round(k["mae"]),
            "mape_pct": round(k["mape_pct"], 1),
            "coverage_90": cp["coverage_90"],
            "naive_mae_kg": round(cp["models"]["naive_mean"]["mae"]),
        }

    def explain_drivers(self, scope: str = "local", reactor_id: str | None = None) -> Json:
        d = self._metrics("drivers")
        if scope == "global" or reactor_id is None:
            return {
                "scope": "global",
                "drivers": [
                    {"driver": x["label"], "share_pct": round(100 * x["share"], 1)}
                    for x in d.get("drivers", [])[:6]
                ],
                "interactions": [x["sentence"] for x in d.get("interactions", [])[:3]],
                "method": d.get("method"),
            }
        ml = self._ml
        if not ml:
            return {"available": False, "reason": "models not loaded"}
        r = self._reactor(reactor_id)
        idx = r.batch.index_at(r.t_h)
        row = ml.batches[r.batch.batch_id].features.iloc[[idx]]
        from kairos_ml.engines.why import label as feat_label

        return {
            "scope": "local",
            "reactor_id": r.id,
            "forecast_contributions_kg": [
                {"driver": feat_label(n), "effect_kg": round(v)}
                for n, v in self._why.local(row, top=5)
            ],
            "note": "Positive pushes the forecast up versus the average training batch; exact additive attribution.",
        }

    def diagnose_alarm(self, reactor_id: str) -> Json:
        r = self._reactor(reactor_id)
        t = r.last_tick
        h = t.health if t else None
        if h is None:
            return {"reactor_id": r.id, "available": False}
        last = r.history[-1] if r.history else None
        first_alarm = next((a.t_h for a in r.history if a.state == "alarm"), None)
        return {
            "reactor_id": r.id,
            "batch_id": r.batch.batch_id,
            "state": r.state,
            "first_alarm_at_h": first_alarm,
            "alarm_latched": r.latched,
            "latch_note": (
                "Alarm is held until the operator acknowledges it; the detector's current reading is "
                f"'{r.detector_state}'. A fault can persist after the process partly adapts: check the yield forecast."
                if r.latched
                else None
            ),
            "detector_reading_now": r.detector_state,
            "health_score_now": h.score,
            "t2_vs_limit": [h.t2, h.t2_limit],
            "spe_vs_limit": [h.spe, h.spe_limit],
            "deviating_variables_now": [
                {"variable": label(c.var), "key": c.var, "share_pct": c.pct, "direction": c.dir}
                for c in h.top_contributors
            ],
            "last_transition": None if last is None else {"to": last.state, "at_h": last.t_h},
            "acknowledged": r.acknowledged,
            "method": "MSPC (T2/SPE) on golden-trajectory-normalised sensors, EWMA + 2 h persistence",
        }

    def recommend_settings(self, reactor_id: str, mode: str = "energy") -> Json:
        ml = self._ml
        if not ml:
            return {"available": False, "reason": "models not loaded"}
        from app.pipeline.ml_engines import recommend

        r = self._reactor(reactor_id)
        rec = recommend(ml, r.id, r.batch.batch_id, r.batch.index_at(r.t_h), mode)
        out = rec.model_dump(exclude={"options"})
        out["evaluated_saving_on_held_out_batches"] = self._metrics("energy").get("mean_saving_pct")
        return out

    def simulate_what_if(
        self, reactor_id: str, at_h: float | None = None, changes: Json | None = None
    ) -> Json:
        r = self._reactor(reactor_id)
        res = self._ponr(r)
        if res is None:
            return {"available": False, "reason": "what-if model not loaded"}
        target = at_h if at_h is not None else res.now_h
        point = min(res.curve, key=lambda c: abs(c.fix_h - target))
        return {
            "reactor_id": r.id,
            "if_fixed_at_h": point.fix_h,
            "recovered_final_yield_kg": {
                "p10": round(point.p10),
                "p50": round(point.p50),
                "p90": round(point.p90),
            },
            "if_unchanged_forecast_kg": r.last_tick.forecast.p50
            if r.last_tick and r.last_tick.forecast
            else None,
            "note": "Correction = restoring normal operation (e.g. the rescue setpoints). Model estimate from healthy analog batches.",
        }

    def estimate_point_of_no_return(self, reactor_id: str) -> Json:
        r = self._reactor(reactor_id)
        res = self._ponr(r)
        if res is None:
            return {"available": False, "reason": "point-of-no-return model not loaded"}
        return {
            "reactor_id": r.id,
            "now_h": res.now_h,
            "hours_left": res.hours_left,
            "beyond_horizon": res.hours_left is None,
            "act_immediately": res.hours_left == 0,
            "target_kg": round(res.target_kg),
            "definition": "Latest fix time that still recovers 90% of the yield a healthy batch in this state would deliver (model estimate).",
        }

    def _ponr(self, r: Any) -> Any:
        ml = self._ml
        first_alarm = next((a.t_h for a in r.history if a.state == "alarm"), None)
        return ml.ponr(r.batch, r.batch.index_at(r.t_h), reference_h=first_alarm) if ml else None

    def get_model_evidence(self) -> Json:
        y, f = self._metrics("yield"), self._metrics("faults")
        out: Json = {"provenance": "held-out simulated batches (IndPenSim)"}
        if y:
            out["yield_mae_kg_by_progress"] = {
                f"{int(100 * c['progress'])}%": {k: round(v["mae"]) for k, v in c["models"].items()}
                for c in y["checkpoints"]
            }
            out["interval_coverage_hourly"] = {
                k: round(v, 3) for k, v in y["overall_hourly_coverage"].items()
            }
            out["typical_yield_kg"] = round(y["typical_yield_kg"])
        if f:
            out["fault_detection"] = {
                k: {kk: _r(vv) for kk, vv in v.items()} for k, v in f["summary"].items()
            }
        return out

    def get_data_provenance(self, field: str | None = None) -> Json:
        from app.api.routes_meta import SENSORS
        from kairos_ml.constants import load_constants

        if field:
            for s in SENSORS:
                if s.key == field:
                    return s.model_dump()
            c = load_constants().get(field)
            if c:
                return {
                    "key": c.key,
                    "value": c.value,
                    "unit": c.unit,
                    "provenance": c.provenance,
                    "source": c.source,
                }
            return {"error": f"unknown field {field}"}
        return {
            "data": "IndPenSim: 100 simulated industrial-scale penicillin batches (synthetic, published simulator)",
            "labels": ["measured", "published", "assumed", "synthetic"],
        }
