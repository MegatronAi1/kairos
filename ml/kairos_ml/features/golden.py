"""Golden trajectory: mean and std of each online variable across normal training
batches at the same batch time. Batch time aligns batches because the fed-batch
recipe is time-indexed (identical manipulated profiles across recipe batches).
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import numpy.typing as npt
import pandas as pd

Array = npt.NDArray[np.float64]
DT_H = 0.2


def time_index(time_h: npt.ArrayLike) -> npt.NDArray[np.int64]:
    return np.rint(np.asarray(time_h, dtype=float) / DT_H).astype(np.int64)


@dataclass
class GoldenTrajectory:
    variables: list[str]
    mean: Array  # (n_times, n_vars)
    std: Array

    @classmethod
    def fit(cls, df: pd.DataFrame, variables: list[str], min_batches: int = 5) -> GoldenTrajectory:
        idx = time_index(df["time_h"].to_numpy())
        frame = df[variables].assign(_ti=idx)
        g = frame.groupby("_ti")
        counts = g.size()
        valid = counts[counts >= min_batches].index
        n = int(valid.max()) + 1
        mean = g[variables].mean().reindex(range(n)).ffill().bfill().to_numpy(dtype=float)
        std = g[variables].std().reindex(range(n)).ffill().bfill().to_numpy(dtype=float)
        # Robust floor: never below the variable's median per-time std. Without it,
        # phases where all training batches agree (std ~ 0) turn noise into huge z.
        std = np.maximum(std, np.maximum(np.nanmedian(std, axis=0), 1e-6))
        return cls(variables, mean, std)

    def _rows(self, time_h: npt.ArrayLike) -> npt.NDArray[np.int64]:
        return np.clip(time_index(time_h), 0, self.mean.shape[0] - 1)

    def zscores(self, df: pd.DataFrame) -> pd.DataFrame:
        rows = self._rows(df["time_h"].to_numpy())
        x = df[self.variables].to_numpy(dtype=float)
        z = (x - self.mean[rows]) / self.std[rows]
        return pd.DataFrame(z, columns=self.variables, index=df.index)

    def at(self, time_h: float) -> dict[str, tuple[float, float]]:
        r = int(self._rows([time_h])[0])
        return {
            v: (float(self.mean[r, i]), float(self.std[r, i])) for i, v in enumerate(self.variables)
        }
