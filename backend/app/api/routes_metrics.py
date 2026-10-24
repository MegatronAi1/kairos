"""Evidence: serves artifacts/metrics/*.json written by ml/scripts/evaluate_all.py.

Nothing here is computed or typed by hand; missing files are simply omitted.
"""

from __future__ import annotations

import json
from typing import Any

from fastapi import APIRouter, Depends

from app.state import AppState, get_state

# Public on purpose: the evaluation results are the product's evidence (landing page).
router = APIRouter(tags=["metrics"])

METRIC_FILES = ("yield", "faults", "drivers", "energy")


@router.get("/metrics")
def metrics(state: AppState = Depends(get_state)) -> dict[str, Any]:
    out: dict[str, Any] = {}
    base = state.settings.artifacts_dir / "metrics"
    for name in METRIC_FILES:
        path = base / f"{name}.json"
        if path.exists():
            out[name] = json.loads(path.read_text(encoding="utf-8"))
    return out
