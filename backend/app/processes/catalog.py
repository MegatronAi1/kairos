"""Loads the alternative-protein process catalog (catalog.yaml).

The catalog describes how each commercial process is run and controlled, with
provenance and sources. Live replay data stays IndPenSim; each process states how
well that benchmark represents it (`kairos.benchmark_fit`).
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml

CATALOG_PATH = Path(__file__).with_name("catalog.yaml")


def load_catalog() -> dict[str, Any]:
    return _load(CATALOG_PATH)


@lru_cache(maxsize=4)
def _load(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"notes": [], "processes": []}
    data: dict[str, Any] = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    data.setdefault("notes", [])
    data.setdefault("processes", [])
    return data


def get_process(process_id: str) -> dict[str, Any] | None:
    for p in load_catalog()["processes"]:
        if p.get("id") == process_id:
            result: dict[str, Any] = p
            return result
    return None


def summary(process: dict[str, Any]) -> str:
    """Compact text for the copilot's system prompt."""
    sp = process.get("setpoints", {}) or {}
    ranges = ", ".join(
        f"{k} {v.get('min')}-{v.get('max')} ({v.get('provenance')})"
        for k, v in sp.items()
        if isinstance(v, dict)
    )
    k = process.get("kairos", {}) or {}
    return (
        f"{process.get('name')} ({process.get('family')} fermentation), organism {process.get('organism')}, "
        f"{process.get('mode')} in a {process.get('reactor')} reactor; product location {process.get('product_location')}. "
        f"Typical setpoints: {ranges}. Risks: {'; '.join(process.get('critical_risks', []) or [])}. "
        f"Energy hotspots: {'; '.join(process.get('energy_hotspots', []) or [])}. "
        f"Benchmark fit of the live IndPenSim data: {k.get('benchmark_fit')} ({k.get('benchmark_fit_why')})."
    )
