"""Train every engine and save artifacts/models/kairos.joblib.

Run: uv run python ml/scripts/train_all.py
"""

from __future__ import annotations

import time

import numpy as np

from kairos_ml.bundle import KairosModels
from kairos_ml.data.load import load_process_frame
from kairos_ml.data.splits import load_onsets, load_splits
from kairos_ml.dataset import build_batches, fit_golden
from kairos_ml.engines.fault_detector import AlarmLogic, Mspc, warmup_mask
from kairos_ml.engines.yield_model import YieldModel


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

    ym = YieldModel.fit([batches[i] for i in splits["train"]], [batches[i] for i in splits["val"]])
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
    )
    path = models.save()
    print(
        f"saved {path} in {time.perf_counter() - t0:.1f}s; PCA components {mspc.pca.n_components_}"
    )


if __name__ == "__main__":
    main()
