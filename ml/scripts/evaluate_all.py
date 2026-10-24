"""Regenerate artifacts/metrics/*.json from the trained bundle.

Run: uv run python ml/scripts/evaluate_all.py
"""

from __future__ import annotations

from kairos_ml.bundle import KairosModels
from kairos_ml.data.load import load_process_frame
from kairos_ml.dataset import build_batches
from kairos_ml.eval.evaluate import driver_metrics, fault_metrics, write, yield_metrics


def main() -> None:
    models = KairosModels.load()
    batches = build_batches(load_process_frame(), models.golden)
    for name, fn in (
        ("yield", yield_metrics),
        ("faults", fault_metrics),
        ("drivers", driver_metrics),
    ):
        print("wrote", write(name, fn(models, batches)))


if __name__ == "__main__":
    main()
