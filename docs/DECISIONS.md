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
- **Yield target: total penicillin produced per batch (kg), derived from the time series** = sum over rows of P x broth removed (mid-batch harvests) + final P x V. The published statistics file correlates only r = 0.33 with these values (e.g. batch 2: 2326 vs 3588 kg) and appears to come from a different simulation run, so it is not used.
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
- **Splits** (`ml/config/splits.json`, seed 20261024): per strategy 20 train / 5 val / 5 test-normal; fault batches 91-100 test only.
- **Fault onsets** (`ml/config/fault_onsets.json`), independent of the detector: batches 91, 94, 95, 97, 99, 100 depart from the recipe's manipulated inputs at exactly 20.0 h (recipe batches 1-30 have identical input profiles), so onset is exact. 92, 93, 96, 98 have no input departure; onset is estimated as the earliest time a monitored variable stays > 4 sigma from the recipe-batch envelope for >= 2 h (92: pH 80.0 h, 93: temperature 70.6 h, 96: temperature 76.4 h, 98: pH 80.0 h). Labelled as estimates.
- **Golden trajectory aligned on batch time** (0.2 h grid), not progress fraction: the recipe is time-indexed.
- **Lab penicillin and biomass (offline, ~every 12 h) are used as features**, forward-filled from sample time only. Standard plant QC assays; the online simulator penicillin/substrate states are never features.
- **Bedrock models (verified 24 Oct, workshop allowlist):** chat `us.anthropic.claude-sonnet-5`, fast/alarm summaries `us.anthropic.claude-haiku-4-5-20251001-v1:0`. Sonnet 5.5 / Haiku 5.5 are listed but explicitly denied by the workshop allowlist policy. `us.*` inference profiles keep traffic in US regions. IDs live in `.env` (gitignored), never in code.
- **Local AWS credentials via named profile `kairos`** in `~/.aws/credentials` (outside the repo); backend reads `AWS_PROFILE`. Temporary workshop keys; refresh when they expire.
- **Yield model trains on normal + fault batches; fault batches are scored leave-one-fault-out** (10 hold-out models in the bundle; the replay uses the hold-out model for a fault batch, so the demo never shows a model that saw that batch). Trained on normal batches only, early forecasts for severe faults were 2.5-5x too high. Normal-test MAE also improved (e.g. 645 -> 590 kg at 20%). After the first alarm the 80% interval is widened to the held-out fault residual quantile (~1200 kg).
- **Chart series colours** (`color.chart.series1-3` in tokens): aqua `#199E70` (Kairos), blue `#3987E5`, orange `#D95926`, from a validated dark categorical palette (all-pairs CVD dE >= 9.4, normal-vision >= 20.9 on `#11171F`). Naive baseline is a dashed neutral reference line, not a categorical hue. Status colours stay reserved for health state.
- **Light theme from the same tokens** (`themes.light.color` in `design/tokens.json`): web switches with `:root[data-theme="light"]` (toggle System/Dark/Light, remembered; `?theme=` URL parameter for deck screenshots), mobile switches `KColors.palette` (dark/light `KPalette`) and rebuilds the tree. Dark stays the default. Light chart series validated on white (aqua is 2.8:1, relieved by direct labels and tables).
- **Docker:** backend image installs uv from PyPI (ghcr.io is unreachable from the venue network); data/, artifacts/ and ~/.aws are mounted read-only, never baked into images. Web is served by nginx, which proxies /api (unbuffered for SSE) and /ws.
