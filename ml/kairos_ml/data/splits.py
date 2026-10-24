"""Batch-wise splits and fault-onset labels. Run once; outputs are committed.

Run: uv run python -m kairos_ml.data.splits
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd

from kairos_ml.data.load import load_process_frame

CONFIG_DIR = Path(__file__).resolve().parents[2] / "config"
SPLITS_PATH = CONFIG_DIR / "splits.json"
ONSETS_PATH = CONFIG_DIR / "fault_onsets.json"
SEED = 20261024

STRATEGY_RANGES = {"recipe": (1, 30), "operator": (31, 60), "pat": (61, 90)}
FAULT_BATCHES = list(range(91, 101))
MANIPULATED = [
    "aeration_lph",
    "feed_lph",
    "pressure_bar",
    "water_lph",
    "oil_lph",
    "paa_lph",
    "dumped_lph",
]
ENVELOPE_VARS = ["ph", "temp_k", "base_lph", "acid_lph", "cooling_lph", "heating_lph", "do_mgl"]


def make_splits(seed: int = SEED) -> dict[str, list[int]]:
    """Per strategy (30 batches each): 20 train, 5 validation, 5 test. Faults held out."""
    rng = np.random.default_rng(seed)
    out: dict[str, list[int]] = {
        "train": [],
        "val": [],
        "test_normal": [],
        "test_fault": FAULT_BATCHES,
    }
    for lo, hi in STRATEGY_RANGES.values():
        ids = rng.permutation(np.arange(lo, hi + 1)).tolist()
        out["train"] += ids[:20]
        out["val"] += ids[20:25]
        out["test_normal"] += ids[25:30]
    return {k: sorted(int(i) for i in v) for k, v in out.items()}


def estimate_fault_onsets(df: pd.DataFrame) -> dict[int, dict[str, object]]:
    """Fault onset per fault batch, independent of any detector.

    1. Exact: first time a manipulated input departs from the recipe (batches 1-30
       share identical manipulated profiles; fault batches are recipe-driven).
    2. Otherwise estimated: earliest time any envelope variable stays > 4 sigma from
       the recipe-batch mean for >= 2 h (10 rows).
    """
    recipe = df[df.batch_id.between(1, 30)]
    ref = recipe[recipe.batch_id == 1].set_index("time_h")[MANIPULATED]
    mu = recipe.groupby("time_h")[ENVELOPE_VARS].mean()
    sd = recipe.groupby("time_h")[ENVELOPE_VARS].std().clip(lower=1e-6)
    onsets: dict[int, dict[str, object]] = {}
    for b in FAULT_BATCHES:
        d = df[df.batch_id == b].set_index("time_h")
        common = d.index.intersection(ref.index)
        diff = (d.loc[common, MANIPULATED] - ref.loc[common]).abs() > 1e-6
        hits = [(float(diff.index[diff[c]].min()), c) for c in MANIPULATED if diff[c].any()]
        if hits:
            t, var = min(hits)
            onsets[b] = {
                "onset_h": t,
                "variable": var,
                "method": "exact: departs from recipe input",
            }
            continue
        z = ((d[ENVELOPE_VARS] - mu.reindex(d.index)) / sd.reindex(d.index)).abs()
        cands = []
        for c in ENVELOPE_VARS:
            flag = (z[c] > 4).astype(int)
            run = flag.groupby((flag != flag.shift()).cumsum()).transform("sum") * flag
            idx = z.index[run >= 10]
            if len(idx):
                cands.append((float(idx.min()), c))
        t, var = min(cands) if cands else (float("nan"), "")
        onsets[b] = {
            "onset_h": t,
            "variable": var,
            "method": "estimated: >4 sigma from recipe envelope for >=2 h",
        }
    return onsets


def load_splits() -> dict[str, list[int]]:
    data: dict[str, list[int]] = json.loads(SPLITS_PATH.read_text(encoding="utf-8"))
    return data


def load_onsets() -> dict[int, dict[str, object]]:
    raw = json.loads(ONSETS_PATH.read_text(encoding="utf-8"))
    return {int(k): v for k, v in raw.items()}


def main() -> None:
    splits = make_splits()
    SPLITS_PATH.write_text(json.dumps(splits, indent=2) + "\n", encoding="utf-8")
    onsets = estimate_fault_onsets(load_process_frame())
    ONSETS_PATH.write_text(json.dumps(onsets, indent=2) + "\n", encoding="utf-8")
    print(
        json.dumps({"splits": {k: len(v) for k, v in splits.items()}, "onsets": onsets}, indent=1)
    )


if __name__ == "__main__":
    main()
