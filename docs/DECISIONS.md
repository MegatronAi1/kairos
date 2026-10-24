# Decisions

Each entry: date/time (IST), decision, reason. Newest last.

## 2026-10-24

- **Repo at `D:\kairos`, single git repo, local only for now.** No GitHub remote or AWS creds yet; add remote later and push hourly once available.
- **Python: one uv workspace (root `pyproject.toml`) with members `ml` and `backend`.** One lockfile and one `.venv` keeps the backend importing `kairos_ml` without path hacks. Deviation from spec's separate projects is structural only.
- **Dataset source: Mendeley Data DOI 10.17632/pdnjz7zz5x v2, `100_Batches_IndPenSim.zip` (503.8 MB, sha256 `bc434c6c...181f00`), CC BY 4.0.** Chosen over Kaggle (needs auth) and an unofficial Zenodo copy. Venue bandwidth measured ~166 KB/s, so the compressed zip is the only practical option.
- **Raman columns detected as numeric headers and excluded at load time.** Keeps memory small and enforces the cheap-sensor model. Process columns cached to `data/processed/indpensim_process.parquet`.
- **Batch boundaries:** use an explicit batch ID/ref column if present, otherwise detect time resets.
- **No `tabulate` dependency:** markdown tables written by hand in `inspect.py`.
- **`make` is not installed; `mingw32-make` is.** Makefile recipes only call `uv run` / `pnpm`, so they work under either.
- **Unverified constants marked `assumed`** in `ml/config/constants.yaml`, including the India grid factor until verified against the current CEA database.
