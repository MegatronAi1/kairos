"""Typed access to ml/config/constants.yaml (values with provenance)."""

from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Literal

import yaml

Provenance = Literal["measured", "published", "assumed", "synthetic", "fitted"]

CONSTANTS_PATH = Path(__file__).resolve().parents[1] / "config" / "constants.yaml"


@dataclass(frozen=True)
class Constant:
    key: str
    value: float
    unit: str
    provenance: Provenance
    source: str


@lru_cache(maxsize=1)
def load_constants(path: Path = CONSTANTS_PATH) -> dict[str, Constant]:
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    return {
        key: Constant(
            key=key,
            value=float(entry["value"]),
            unit=str(entry["unit"]),
            provenance=entry["provenance"],
            source=str(entry["source"]),
        )
        for key, entry in raw.items()
    }


def const(key: str) -> float:
    return load_constants()[key].value
