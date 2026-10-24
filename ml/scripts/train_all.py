"""Train every engine and save artifacts/models/kairos.joblib.

Run: uv run python ml/scripts/train_all.py
"""

from __future__ import annotations

import time

import numpy as np

from kairos_ml.bundle import KairosModels
from kairos_ml.data.load import load_process_frame
from kairos_ml.data.splits import load_onsets, load_splits
from kairos_ml.dataset import BatchData, build_batches, fit_golden
from kairos_ml.engines.fault_detector import AlarmLogic, Mspc, warmup_mask
from kairos_ml.engines.ponr import AnalogRescue
from kairos_ml.engines.yield_model import CHECKPOINT_EVERY_ROWS, YieldModel, conformal_quantile


def alarm_half_widths(models: KairosModels, fault_batches: list[BatchData]) -> dict[float, float]:
    """Conformal half-widths from held-out fault predictions after the first alarm."""
    resid = []
    for b in fault_batches:
        s = models.score(b)
        alarmed = np.maximum.accumulate(np.array([x == "alarm" for x in s.states]))
        rows = np.arange(0, len(alarmed), CHECKPOINT_EVERY_ROWS)
        rows = rows[alarmed[rows]]
        resid.append(np.abs(s.p50[rows] - b.yield_kg))
    r = np.concatenate(resid) if resid else np.array([])
    return {cov: conformal_quantile(r, 1 - cov) for cov in (0.8, 0.9)}


def main() -> None:
    t0 = time.perf_counter()
    df = load_process_frame()
    splits, onsets = load_splits(), load_onsets()
    golden = fit_golden(df, splits["train"])
    batches = build_batches(df, golden)

    def z(ids: list[int]) -> np.ndarray:
        return np.vstack(
            [
                batches[i].zscores.to_numpy()[warmup_mask(batches[i].raw["time_h"].to_numpy())]
                for i in ids
            ]
        )

    train = [batches[i] for i in splits["train"]]
    val = [batches[i] for i in splits["val"]]
    faults = splits["test_fault"]
    # Yield: normal training batches plus fault batches, so the model sees what a
    # failing batch looks like. Fault batches are evaluated leave-one-fault-out.
    ym = YieldModel.fit(train + [batches[f] for f in faults], val)
    holdouts = {
        f: YieldModel.fit(train + [batches[g] for g in faults if g != f], val) for f in faults
    }
    mspc = Mspc.fit(z(splits["train"]), golden.variables)
    mspc.set_limits(z(splits["val"]))
    models = KairosModels(
        golden=golden,
        yield_model=ym,
        mspc=mspc,
        alarm=AlarmLogic(),
        splits=splits,
        onsets=onsets,
        meta={"trained_seconds": round(time.perf_counter() - t0, 1)},
        fault_holdout_models=holdouts,
    )
    models.alarm_half_width = alarm_half_widths(models, [batches[f] for f in faults])
    models.rescue = AnalogRescue.fit(train)
    path = models.save()
    print(
        f"saved {path} in {time.perf_counter() - t0:.1f}s; PCA components {mspc.pca.n_components_}"
    )


if __name__ == "__main__":
    main()
