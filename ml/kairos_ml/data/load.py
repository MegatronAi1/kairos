"""Raw IndPenSim loading.

The raw CSV is ~2.5 GB because of 2200 Raman spectrum columns. We read only the
first 37 process columns by position and cache the result as Parquet with the
canonical keys from `schema.py`.

Header quirk: the PAT_ref label contains unquoted commas, so the header has 2
more fields than each data row. `read_header` repairs it; `load_process_frame`
asserts the repaired header matches the frozen schema.
"""

from __future__ import annotations

import csv
import re
import zipfile
from pathlib import Path

import pandas as pd

from kairos_ml.data.schema import COLUMNS, KEYS, N_PROCESS

RAW_DIR = Path("data/raw")
PROCESSED_DIR = Path("data/processed")
PROCESS_PARQUET = PROCESSED_DIR / "indpensim_process.parquet"

_NUMERIC_HEADER = re.compile(r"^\s*-?\d+(\.\d+)?\s*$")


def find_raw_csv(raw_dir: Path = RAW_DIR) -> Path:
    """Return the main IndPenSim CSV, extracting it from the zip if needed."""
    csvs = sorted(p for p in raw_dir.rglob("*.csv") if "statistics" not in p.name.lower())
    if csvs:
        return max(csvs, key=lambda p: p.stat().st_size)
    zips = sorted(raw_dir.glob("*.zip"))
    if not zips:
        raise FileNotFoundError(f"No IndPenSim CSV or zip found in {raw_dir}")
    with zipfile.ZipFile(zips[0]) as zf:
        members = [m for m in zf.namelist() if m.lower().endswith(".csv")]
        zf.extractall(raw_dir, members=members)
    return find_raw_csv(raw_dir)


def find_statistics_csv(raw_dir: Path = RAW_DIR) -> Path | None:
    hits = [p for p in raw_dir.rglob("*.csv") if "statistics" in p.name.lower()]
    return hits[0] if hits else None


def is_raman_column(name: str) -> bool:
    """Raman spectrum columns are headed by bare wavenumbers (e.g. '2400')."""
    return bool(_NUMERIC_HEADER.match(str(name)))


def _repair_header(header: list[str], n_fields: int) -> list[str]:
    """Merge header fragments split by unquoted commas until it has n_fields names.

    A fragment is a non-numeric name without the '(...)' unit suffix that every
    real label except 'Time (h)', 'Batch ID' and 'Fault flag' carries; it is
    glued onto the following field.
    """
    out = [h.strip() for h in header]
    extra = len(out) - n_fields
    i = 0
    while extra > 0 and i < len(out) - 1:
        name = out[i]
        if not is_raman_column(name) and "(" not in name and name not in {"Batch ID", "Fault flag"}:
            out[i : i + 2] = [f"{name}, {out[i + 1]}"]
            extra -= 1
        else:
            i += 1
    if len(out) != n_fields:
        raise ValueError(f"Cannot repair header: {len(out)} names for {n_fields} fields")
    return out


def read_header(csv_path: Path) -> list[str]:
    """Header names aligned to the data rows."""
    with csv_path.open("r", encoding="utf-8", errors="replace", newline="") as fh:
        reader = csv.reader(fh)
        header = next(reader)
        first_row = next(reader)
    return _repair_header(header, len(first_row))


def load_process_frame(csv_path: Path | None = None, *, use_cache: bool = True) -> pd.DataFrame:
    """Load the process columns with canonical keys. Cached to Parquet."""
    if use_cache and PROCESS_PARQUET.exists():
        return pd.read_parquet(PROCESS_PARQUET)
    csv_path = csv_path or find_raw_csv()
    header = read_header(csv_path)
    expected = [c.raw for c in COLUMNS]
    if header[:N_PROCESS] != expected:
        diff = [(i, a, b) for i, (a, b) in enumerate(zip(header, expected, strict=False)) if a != b]
        raise ValueError(f"Header differs from frozen schema: {diff[:3]}")
    df = pd.read_csv(
        csv_path, header=None, skiprows=1, usecols=range(N_PROCESS), names=list(KEYS), low_memory=False
    )
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    df.to_parquet(PROCESS_PARQUET, index=False)
    return df
