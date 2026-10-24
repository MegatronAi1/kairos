# Decisions

Each entry: date/time (IST), decision, reason. Newest last.

## 2026-10-24

- **Repo at `D:\kairos`, remote https://github.com/MegatronAi1/kairos.** Push at least hourly.
- **Python: one uv workspace (root `pyproject.toml`) with members `ml` and `backend`.** One lockfile and one `.venv` keeps the backend importing `kairos_ml` without path hacks. Deviation from spec's separate projects is structural only.
- **Dataset source: Kaggle mirror `stephengoldie/big-databiopharmaceutical-manufacturing`** (contains `Mendeley_data/100_Batches_IndPenSim_V3.csv`, 2.57 GB, plus `100_Batches_IndPenSim_Statistics.csv`). Original Mendeley Data DOI 10.17632/pdnjz7zz5x, CC BY 4.0. The first Mendeley zip download was truncated.
- **Raman columns detected as numeric headers and excluded at load time.** Keeps memory small and enforces the cheap-sensor model. Process columns cached to `data/processed/indpensim_process.parquet`.
- **Header repair.** The PAT_ref label contains unquoted commas, so the header has 2239 fields vs 2237 per row; every later column was shifted. `load.py` merges the fragments and asserts the result against the frozen schema in `kairos_ml/data/schema.py` (canonical snake_case keys). Columns are read by position.
- **Batch boundaries:** `batch_id` column (1..100).
- **Fault labels are batch-level only.** `fault_flag` is 1 on every row of batches 91-100 and 0 elsewhere; `fault_ref` is 1 only for batch 95. There is no per-row onset. Fault onset for detection-delay metrics will be estimated from the data (first sustained departure of a manipulated input or sensor from the normal envelope) and labelled as an estimate.
- **Agitation is constant (100 rpm) in all batches.** The ML models cannot learn agitation effects; the energy recommender handles RPM through physics (power number, van't Riet kLa) only, and says so.
- **`o2_offgas_frac` is a fraction (0.13-0.23)** despite the "%" label; unit recorded as fraction.
- **Operating strategies:** batches 1-30 recipe-driven, 31-60 operator-controlled, 61-90 Raman/PAT-controlled, 91-100 faults (recipe-driven base). Splits stratify on these.
- **Yield target candidate:** published `Penicllin_yield_total (kg)` from the statistics file (includes broth harvested mid-batch), cross-checked against final P x V. Final choice logged when the yield model lands.
- **No `tabulate` dependency:** markdown tables written by hand in `inspect.py`.
- **`make` is not installed; `mingw32-make` is.** Makefile recipes only call `uv run` / `pnpm`, so they work under either.
- **Unverified constants marked `assumed`** in `ml/config/constants.yaml`, including the India grid factor until verified against the current CEA database.
- **Design tokens built by a zero-dependency Node script** (`design/build-tokens.mjs`) instead of Style Dictionary. Same single source (`design/tokens.json`), same outputs (CSS vars, Tailwind preset, Dart constants), one less toolchain to break at 3 AM.
- **Flutter models are hand-written immutable classes, not freezed/json_serializable.** `freezed` and `json_serializable` failed to resolve against this SDK (pub fell back to pre-null-safety versions). Contract tests parse shared JSON fixtures instead.
- **Fonts bundled as assets** (Inter and JetBrains Mono variable TTFs from google/fonts, OFL) so the phone works offline at the venue.
- **Sole developer, one laptop.** Lanes run in sequence: thin end-to-end slice first, then deepen engines.
- **Aeration `Fg` treated as m3/min** (assumed): the dataset labels it L/h, but 20-75 L/h is physically impossible for a ~100 m3 vessel, while 20-75 m3/min is 0.3-1 vvm, a typical range.
- **DO % saturation uses C* scaled by head pressure** (Henry's law, gauge pressure assumed): gives 60-95% on normal batches, matching DO up to 16.5 mg/L.
- **RQ from dataset OUR/CER is not physical** (median ~0.013 with the labelled units), so the units are likely scaled. RQ is used only as a ratio normalised to the golden trajectory (RQ index), never shown as a true molar RQ.
- **kLa calibration multiplier pending:** raw van't Riet OTR is ~1000x the dataset OUR on the same units, so a fitted calibration (OTR ~= OUR in steady phases) is required before any OTR-vs-OUR constraint is used.
- **Statistics-file yields are grams, not kg.** `Penicllin_yield_total (kg)` is ~2.8e6 for batch 1 while final P x V is ~2.3e6 g; values are divided by 1000 and reported in kg.
