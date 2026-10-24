# KAIROS — Master Build Specification

> **Read this whole file before writing any code.** It is the single source of truth for the product, the science, the architecture, the design system, and the build plan. If something here conflicts with your assumptions, this file wins. If something here conflicts with **the actual data**, the data wins: flag the conflict in `docs/DECISIONS.md` and adapt.

- **Event:** Hack the Fork 2026 India Edition, NIFTEM-K, 24-hour final round (24 Oct 11:00 AM to 25 Oct 8:00 AM IST)
- **Problem statement:** 3(a) Smarter Fermentation for Smart Protein, Process Intelligence
- **Team tooling:** Claude Code (Claude Max), AWS sandbox account (us-east-1 only, Bedrock enabled, no GPU)
- **Quality bar:** production-grade code, professional and consistent UI/UX across every surface, scientifically defensible models, honest uncertainty

---

## Table of contents

1. Product summary
2. The problem (what the judges asked for)
3. The solution and the core story
4. Scope tiers (must / should / could)
5. System architecture
6. Data: sources, provenance, and handling
7. Science and ML: the four engines
8. The Claude agent (Bedrock)
9. Backend service
10. Real-time protocol (WebSocket + REST)
11. Design system (shared across web and mobile)
12. Web app: Kairos Control Room
13. Mobile app: Kairos Pager (Flutter)
14. AWS deployment
15. Repository structure and engineering standards
16. Security, privacy, and hackathon rules compliance
17. Testing and acceptance criteria
18. Build plan and timeline (24 hours)
19. Demo script
20. Pitch deck content
21. Judge Q&A bank
22. Startup and six-month plan
23. References
24. Instructions for Claude Code (operating rules)

---

## 1. Product summary

**Kairos is an AI co-pilot for fermentation bioreactors.** It watches a running batch through ordinary process sensors and:

1. **Predicts the final yield early** (at 20 to 50% of batch time) with an honest uncertainty band.
2. **Detects drift and faults early with few false alarms**, and estimates the **point of no return**: how long the operator has before the batch can no longer be rescued.
3. **Explains why**: which parameters drive the outcome and how they interact.
4. **Recommends settings** that keep yield high while **using less energy** (agitation and aeration are the big electricity costs).
5. **Talks**: a Claude agent turns all of this into plain-language, operator-ready advice, grounded only in model outputs.

**Surfaces:**

- **Kairos Control Room (web):** an immersive 3D digital twin of each bioreactor, a flight-recorder timeline, a what-if console, a model-evidence page, and an AI copilot panel.
- **Kairos Pager (Flutter mobile):** the operator's phone. It buzzes on alarms with the diagnosis and recommended fix, and offers the chat.

**One-line pitch:** *"Every failed batch has a point of no return. Kairos finds it hours before it happens, tells the operator exactly what to change, and proves it would have saved the batch, while cutting the energy bill."*

**Name note:** "Kairos" is Greek for "the decisive moment". If the name clashes with something during the event, use it internally and rename later.

---

## 2. The problem (what the judges asked for)

From the official problem statement 3(a):

> A tool that learns from several process parameters during a run (for example dissolved oxygen, pH, temperature, agitation, aeration, feed rate, biomass, off-gas CO2) to **predict final yield early**, **catch drift or contamination with few false alarms**, and **recommend settings that keep yield high while using less energy**. It should **show which parameters drive the result and how they interact.**

Key metrics the jury will look at for 3(a):

- Yield prediction accuracy
- Fault-detection performance
- False alarms
- Estimated oxygen-transfer versus energy trade-offs

General judging criteria (all equally important unless told otherwise):

1. Presentation and relevance
2. Technical approach and scientific validity (credible data, justified assumptions, acknowledged limitations)
3. Functionality (the prototype works and produces useful outputs)
4. Feasibility and potential impact in 6 months (first pilot or customer, what is needed, what it costs)
5. Innovation and meaningful use of AI

Hard rules from the organisers that affect the build:

- Every data input must be **labelled as measured, published, assumed, or synthetic**. This must be visible in the product UI and the deck.
- **No personal or sensitive data.**
- Every data source, paper, model, and tool must be listed on the References slide as a clickable link.
- Push code to GitHub at least every hour. No keys in the repo.
- AWS: us-east-1 only, Bedrock under about 1 request per second per person, no GPUs, account deleted at the end.
- Final deck on the official template (shared by 10 PM). Submission 6:00 to 8:00 AM on 25 Oct. Pitch is 4 minutes plus 4 minutes Q&A. The prototype must be runnable on one team laptop during Q&A.

**Why this matters (the industry decision Kairos supports):** an operator or process engineer must decide, during a run, *"Is this batch healthy? If not, what do I change, and is it still worth saving?"* Today that decision is made with fixed setpoints and experience. Lost batches waste days of reactor time, feedstock, and electricity. Precision and biomass fermentation for alternative proteins only becomes cost-competitive when batch success rates go up and energy per kg goes down.

---

## 3. The solution and the core story

### 3.1 The narrative arc (use this everywhere: UI copy, deck, demo)

1. **See it coming.** Early yield forecast and early fault warning.
2. **Know why.** Drivers and interactions, in plain language.
3. **Know how long you have.** Point-of-no-return countdown.
4. **Know what to do.** A concrete, quantified recommendation.
5. **Prove it.** Counterfactual replay shows the rescued outcome.
6. **Save energy every batch.** Optimised agitation and aeration with the oxygen-transfer trade-off made explicit.

### 3.2 What makes it different (innovation claims we can defend)

- **Hybrid models (physics plus ML)**, not a black box. Mechanistic penicillin kinetics and oxygen-transfer physics combined with gradient-boosted correction. Judges with science backgrounds trust this.
- **Point of no return** as a first-class output. Most monitoring tools say "something is wrong"; Kairos says "you have about 4 hours to act, and here is what saves it".
- **Counterfactual rescue.** The what-if engine replays a failed batch with the recommended correction and shows the recovered yield.
- **Cheap-sensor first.** Models use only standard sensors (pH, DO, temperature, agitation, aeration, feed, off-gas). Expensive Raman spectroscopy is optional, which suits Indian contract manufacturers and startups that cannot afford it.
- **Honest uncertainty.** Conformal prediction intervals with measured coverage, explicit false-alarm rates, and provenance labels on every number.
- **AI used meaningfully.** Claude is an agent that calls the four engines as tools and reasons over their outputs. It is never the source of a number.

### 3.3 Prior work we must acknowledge and differentiate from

- IndPenSim has been used for soft sensing before, including a 2026 bioRxiv study on fault-inclusive soft sensing of penicillin concentration, and Metcalfe et al.'s LSTM soft sensor in an MLOps workflow using batches 91 to 100.
- **Our difference:** those estimate the *current* concentration. Kairos forecasts the *final* outcome early, detects faults with explicit false-alarm control, estimates the point of no return, recommends energy-aware corrections, and wraps it in an operator workflow. Say this in the deck if asked.

---

## 4. Scope tiers

Build strictly in this order. **Never start a "Should" item while a "Must" item is broken.**

### Must (the demo fails without these)

- M1. Data ingestion and cleaning for IndPenSim, with batch-wise train/validation/test splits.
- M2. Early final-yield predictor with conformal intervals, evaluated at 20%, 30%, 50% of batch time.
- M3. Fault detector (MSPC baseline plus improved detector) with persistence logic, evaluated on detection delay and false alarm rate.
- M4. Explainability: SHAP global drivers, SHAP interaction pairs, and per-alarm variable contributions.
- M5. Energy model (agitation and aeration power, kLa, OTR) and a setpoint recommender.
- M6. Batch replay streamer and FastAPI backend with WebSocket.
- M7. Claude agent on Bedrock with tool calling and a grounded, streaming chat.
- M8. Web Control Room: 3D reactor twin, live vitals, copilot panel, timeline with alarm markers.
- M9. Flutter Pager: live reactor list, alarm takeover screen with haptics and sound, alarm detail with recommendation.
- M10. Evidence page with real metrics produced by the evaluation scripts (no hand-typed numbers).
- M11. Provenance labels (measured, published, assumed, synthetic) visible in the UI.
- M12. Runs fully on one laptop with `docker compose up` (plus Bedrock credentials).

### Should

- S1. Point-of-no-return estimate and countdown.
- S2. What-if console: change a setpoint at time t and see the projected final yield.
- S3. Fleet view: four reactors replaying different batches at once.
- S4. Pager chat (Ask Kairos on mobile).
- S5. Hosted deployment on AWS (EC2 plus CloudFront HTTPS).
- S6. Energy Pareto trade-off (kWh vs yield) shown in the UI.

### Could

- C1. Hybrid ODE digital twin calibrated to IndPenSim (mechanistic counterfactuals).
- C2. LBNL measured runs as a second "real data" validation (Rhodosporidium toruloides on different feedstocks).
- C3. Raman "premium tier" model comparison (with vs without Raman).
- C4. Voice readout of alarms on the pager (text-to-speech).
- C5. PDF batch report export.

---

## 5. System architecture

```
                ┌───────────────────────────┐
                │  Data (IndPenSim, LBNL)   │   files in ./data (gitignored), copy in private S3
                └─────────────┬─────────────┘
                              │ offline training (ml/)
                              ▼
                ┌───────────────────────────┐
                │  Trained artifacts        │   models/*.joblib, metrics/*.json, golden trajectories
                └─────────────┬─────────────┘
                              │ loaded at startup
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Backend (FastAPI, Python 3.11)                                       │
│                                                                      │
│  ReplayEngine ──tick──► InferencePipeline ──► EventBus ──► WebSocket │
│   (streams a batch      ├ YieldPredictor (+ conformal)               │
│    as if live, Nx speed)├ FaultDetector (MSPC + ML + persistence)    │
│                         ├ WhyEngine (SHAP, contributions)            │
│                         ├ EnergyModel + Recommender                  │
│                         └ PONR estimator / WhatIf simulator          │
│                                                                      │
│  AgentService (Claude on Bedrock, Converse API, tool use, streaming) │
│   tools = thin wrappers over the engines above                       │
│                                                                      │
│  REST: /reactors, /batches, /metrics, /whatif, /agent/chat ...       │
└───────────────┬───────────────────────────────┬──────────────────────┘
                │ WS + REST                      │ WS + REST
                ▼                                ▼
   ┌─────────────────────────┐       ┌─────────────────────────┐
   │ Web: Control Room       │       │ Mobile: Pager (Flutter) │
   │ Vite+React+TS+R3F       │       │ Riverpod, local notifs  │
   └─────────────────────────┘       └─────────────────────────┘
```

**Key principle:** every number shown anywhere comes from an engine or an evaluation script. The LLM explains numbers; it never produces them.

---

## 6. Data

### 6.1 Primary: IndPenSim (industrial-scale penicillin fed-batch simulation)

- **What it is:** 100 simulated batches from a validated simulator of an industrial-scale fed-batch *Penicillium chrysogenum* process. 90 batches are normal operation across three operating strategies, and batches 91 to 100 contain documented process deviations (faults). Roughly 114,000 observations in total.
- **Provenance label:** **Synthetic (published simulator).** The simulator itself is published and built on industrial-scale process knowledge.
- **Where to get it:** search "IndPenSim dataset" (official site industrialpenicillinsimulation.com, plus mirrors on Mendeley Data and Kaggle). Download the CSV. It can be large (Raman spectra columns add thousands of columns): load only the needed columns.
- **Expected variable families (verify against actual headers, do not assume names):**
  - Time (h), batch ID, fault flag/reference
  - Manipulated: aeration rate (Fg), agitator RPM, sugar feed rate (Fs), acid flow, base flow, heating/cooling water flow, PAA (precursor) flow, oil flow, water for injection
  - Measured online: pH, temperature, dissolved oxygen (DO2), O2 and CO2 in off-gas, vessel volume, vessel weight, generated heat
  - Offline / lab: penicillin concentration (P), biomass concentration (X), substrate concentration, viscosity, NH3, PAA concentration
  - Raman spectra (thousands of columns): **excluded from the core "cheap sensor" model**, optional tier C3
- **First task for Claude Code:** write `ml/data/inspect.py` that prints the column list, dtypes, missingness, batch lengths, the three operating strategies if identifiable, and the fault labels per batch. Save to `docs/DATA_PROFILE.md`. Then build the canonical schema from what is actually there.

### 6.2 Secondary: LBNL ABPDU fermentation bioreactor sample data

- **What it is:** sample bioreactor runs of *Rhodosporidium toruloides* on different feedstocks, from the Feedstock Conversion Interface Consortium.
- **Provenance label:** **Measured.**
- **Where:** abpdu.lbl.gov, "Fermentation Bioreactor Sample Data".
- **Use:** tier C2 only. Demonstrates that the pipeline ingests real measured data (schema adapter plus fault detector trained on early runs) and supports the "works beyond penicillin" claim. Do not let it block the Must items.

### 6.3 Published constants and assumptions

Store in `ml/config/constants.yaml`. Each entry has `value`, `unit`, `provenance` (published / assumed), and `source`. Examples:

| Constant | Value (starting point) | Provenance | Source |
|---|---|---|---|
| Rushton impeller power number Np | 5.0 | published | standard turbulent Rushton value |
| Broth density ρ | 1000 to 1050 kg/m³ | assumed | water-like broth |
| Impeller diameter D | derive from vessel volume and D/T ≈ 0.33 | assumed | typical stirred-tank geometry |
| Gassed power ratio Pg/P | 0.5 to 0.7 | assumed | typical range for aerated Rushton |
| kLa correlation (coalescing) | kLa = 0.026 (Pg/V)^0.4 vs^0.5 (SI, s⁻¹) | published | van't Riet (1979) |
| O2 saturation C* | about 7 to 8 mg/L at 25 °C, 1 atm (adjust for temperature) | published | standard solubility tables |
| Critical DO for *P. chrysogenum* | about 20 to 30% saturation | published/assumed | literature range, flag |
| Compressor specific energy | assumed kW per (m³/min) | assumed | state assumption |
| Grid emission factor (India) | latest CEA CO2 Baseline Database value | published | Central Electricity Authority |
| Electricity tariff (industrial, India) | assumed INR/kWh | assumed | state assumption |
| Bajpai–Reuss kinetic parameters | μx ≈ 0.092 h⁻¹, Kx ≈ 0.15 g/g, μp ≈ 0.005 h⁻¹, Kp ≈ 0.0002 g/L, Ki ≈ 0.1 g/L, K(hydrolysis) ≈ 0.04 h⁻¹, Yx/s ≈ 0.45, Yp/s ≈ 0.9, mx ≈ 0.014 h⁻¹ | published | Bajpai & Reuss (1980); Birol et al. (2002). Verify before use; calibrate to data |

**Rule:** if a value is not verified, its provenance is `assumed` and the UI shows it as assumed. Never silently promote assumed to published.

### 6.4 Data handling rules

- Raw data lives in `./data/raw/` (gitignored). Processed Parquet in `./data/processed/` (gitignored). A private S3 bucket in us-east-1 holds copies (`kairos-data-<team>`), with Block Public Access on.
- **Split by batch, never by row.** Suggested split (adapt after inspection, stratify across operating strategies):
  - Train: about 60 normal batches
  - Validation: about 15 normal batches (hyperparameters, conformal calibration)
  - Test-normal: about 15 normal batches (false alarm rate, yield accuracy)
  - Test-fault: batches 91 to 100 (detection delay, recall). Never train the detector on these (one optional exception is documented in 7.2).
- Fix seeds. Write the split to `ml/config/splits.json` and commit it.
- Resample each batch to a uniform grid (e.g. 0.2 h or 0.5 h, decide after inspection). Forward-fill offline lab variables only up to their last sample time, and never leak future lab values into features.
- Normalise time as both absolute hours and **batch progress fraction** (t / typical batch length). Early prediction checkpoints use progress fraction.

---

## 7. Science and ML: the four engines

All engines live in `ml/kairos_ml/` as an importable package used by both training scripts and the backend. Every engine exposes a typed, pure-function style API so the agent can call it as a tool.

### 7.0 Feature engineering (shared)

From online sensors only (no Raman, no offline labs except where stated):

- Raw sensors at time t
- Rolling mean, std, slope over 1 h, 3 h, 6 h windows
- Cumulative quantities: cumulative sugar fed, cumulative acid and base, cumulative aeration, cumulative energy
- **Physiology proxies from off-gas** (these are the scientifically strong features):
  - OUR (oxygen uptake rate) from inlet vs outlet O2 and gas flow
  - CER (CO2 evolution rate) from outlet CO2 and gas flow
  - RQ = CER / OUR (respiratory quotient: shifts indicate metabolic changes)
  - Cumulative OUR and CER (correlate with biomass grown)
- Oxygen transfer: estimated kLa from agitation and aeration (section 7.4), OTR = kLa(C* − C), and the DO margin above critical
- **Deviation from golden trajectory:** for each sensor, the difference from the mean normal-batch trajectory at the same progress fraction (z-scored). This is the classic batch-monitoring trick and is critical for fault detection.

### 7.1 Engine A: Early Yield Predictor

**Target:** final penicillin concentration at harvest, and final penicillin mass (P × V) if volume is available. Choose the primary target after inspection and justify it in `DECISIONS.md`.

**Approach (hybrid):**

1. **Mechanistic prior.** A simple physics-informed estimate of final titer from current state (e.g. current P plus remaining-time production-rate extrapolation from recent dP/dt proxies, or Bajpai–Reuss-based projection if C1 exists). This is the baseline the ML improves on.
2. **ML correction.** LightGBM regressor predicting final yield (or the residual from the mechanistic prior) from features at progress fraction p. Train one model with p as a feature (preferred) or separate models per checkpoint.
3. **Uncertainty.** Split conformal or conformalised quantile regression (CQR) with MAPIE, calibrated on the validation batches, for a 90% interval. Report empirical coverage on test-normal batches.

**Baselines to report (judges want to see we beat something):**

- Naive: training-set mean final yield
- Linear regression on the same features
- Mechanistic prior alone

**Metrics** (`metrics/yield.json`): MAE, RMSE, MAPE, R² at p = 0.2, 0.3, 0.5, 0.7; interval coverage and mean width at 90%; a "convergence curve" of error vs progress.

**Output contract:**

```python
@dataclass
class YieldForecast:
    p50: float           # g/L (or kg)
    p10: float
    p90: float
    unit: str
    progress: float      # 0..1
    vs_golden_pct: float # forecast as % of typical normal-batch yield
    confidence: Literal["low", "medium", "high"]  # derived from interval width
    provenance: Literal["synthetic"]  # inherits from data source
```

### 7.2 Engine B: Fault Detector

**Goal:** catch drift and faults early with few false alarms, and say which variables are responsible.

**Layer 1: MSPC baseline (must exist, it is the scientific reference).**

- Batch-dynamic PCA on golden-trajectory-normalised online sensors (subtract the mean normal trajectory at the same progress, divide by its std). Fit on training normal batches.
- Hotelling's T² and SPE (Q) statistics, with 99% control limits estimated on validation normal batches (empirical quantiles are fine and more honest than F-distribution formulas here).
- Variable contributions to T² and SPE give "which variable".

**Layer 2: Improved detector (pick one, prefer the first).**

- Option A: a one-step-ahead (or k-step) forecaster per key variable (LightGBM on lagged features). Residuals feed a **CUSUM** or EWMA chart per variable plus a combined score.
- Option B: Isolation Forest or a small autoencoder (CPU, sklearn MLPRegressor) on the normalised window features.

**Alarm logic (false-alarm control):**

- Health score 0 to 100 combining layers (document the formula).
- States: `normal → watch → alarm`. Enter `alarm` only if the score breaches its limit for k consecutive ticks (persistence, tune k on validation normal batches to hit a target false-alarm rate such as under 1 false alarm per 10 normal batches).
- Hysteresis on exit.

**Optional:** a fault-type classifier trained with leave-one-fault-batch-out on 91 to 100 (report honestly that there are only 10 fault batches).

**Metrics** (`metrics/faults.json`):

- Per fault batch: true fault onset (from labels), first alarm time, **detection delay (h)**, detected yes/no
- On test-normal batches: false alarms per batch, false alarms per 100 batch-hours
- Comparison table: MSPC vs improved vs combined
- A detection-delay vs false-alarm trade-off curve as k and the threshold vary

**Output contract:**

```python
@dataclass
class HealthStatus:
    score: float                  # 0..100, higher is healthier
    state: Literal["normal", "watch", "alarm"]
    t2: float; t2_limit: float
    spe: float; spe_limit: float
    top_contributors: list[Contribution]  # variable, contribution %, direction
    since_h: float | None         # time the current state began
```

### 7.3 Engine C: Why Engine (explainability)

- **Global drivers:** SHAP TreeExplainer on the yield model, mean |SHAP| ranked.
- **Interactions:** SHAP interaction values, top 5 pairs (e.g. DO × feed rate, temperature × pH). Produce a plain-language description for each pair: "When DO drops below X while feed is above Y, predicted yield falls sharply."
- **Local (per batch, per moment):** SHAP values for the current forecast ("what is pulling this batch's yield down right now").
- **Alarm explanation:** MSPC contributions plus the improved detector's per-variable residual ranking.

**Output contract:** `Explanation { drivers: [...], interactions: [...], local: [...], narrative_facts: [...] }`, where `narrative_facts` are short machine-generated factual strings the agent can quote.

### 7.4 Engine D: Energy Model and Recommender

**Physics:**

- Ungassed impeller power: P = Np · ρ · N³ · D⁵ (N in rev/s, D in m)
- Gassed power: Pg = ratio × P (state the assumed ratio)
- Superficial gas velocity: vs = Q_gas / A_cross-section
- kLa = 0.026 (Pg/V)^0.4 · vs^0.5 (van't Riet, coalescing, SI units, s⁻¹). Optionally calibrate a multiplier so OTR ≈ OUR in normal steady phases (document it as a fitted calibration).
- OTR = kLa · (C* − C_DO)
- Aeration (compressor) power: assumed specific energy × gas flow (state the assumption)
- Total electrical power and cumulative kWh; CO2 via the grid emission factor; cost via the assumed tariff

**Recommender:**

- Decision variables per phase (e.g. growth phase, production phase): agitation RPM and aeration rate setpoints, and optionally a feed-rate trim.
- Objective: minimise kWh subject to (a) predicted final yield ≥ 97% of the baseline forecast (yield model), and (b) predicted OTR ≥ OUR with DO ≥ critical DO plus a margin.
- Solver: Optuna (TPE) over the setpoint space using the yield model and the physics constraints as a surrogate. Return the best feasible point plus a **Pareto front** (kWh vs yield).
- When a fault is active, the recommender switches to **rescue mode**: maximise recovered yield first, energy second.

**Output contract:**

```python
@dataclass
class Recommendation:
    action: str                    # "Reduce agitation 900→780 rpm, keep aeration"
    setpoints: dict[str, float]
    expected_yield_delta_pct: float
    expected_energy_delta_pct: float
    expected_kwh_saved_per_batch: float
    co2_saved_kg: float
    dO_margin_after: float
    confidence: Literal["low", "medium", "high"]
    assumptions: list[str]         # each with provenance
```

### 7.5 Point of No Return (PONR) and What-If

**Definition (put this in the UI tooltip and the deck):** *The point of no return is the latest time at which the best available correction still recovers at least 90% of the yield a normal batch would deliver, according to Kairos's models.*

**Implementation, tiered:**

- **Tier 1 (Should, data-driven analog):** for the current batch state at time t, find the k nearest normal-batch states at similar progress (in normalised feature space). Their final yields, adjusted by the yield model with the correction applied as modified future setpoints, give the recovered-yield estimate. Sweep the correction time from now forward to find when recovery drops below 90%. PONR minus now = the countdown.
- **Tier 2 (Could, C1 hybrid ODE twin):** implement Bajpai–Reuss style ODEs (biomass, substrate, penicillin, DO, volume) with scipy `solve_ivp`, calibrate parameters per operating strategy to IndPenSim normal batches, and add an ML residual correction. Counterfactuals become "re-simulate from the state at t with new setpoints".

**What-if API:** given batch, time t, and setpoint changes, return the projected final yield p10/p50/p90, energy delta, and DO trajectory summary. Clearly labelled "model estimate".

**Honesty rule:** PONR and what-if outputs are always labelled as model estimates with their interval, and the UI never presents them as certain.

---

## 8. The Claude agent (Bedrock)

### 8.1 Model selection

- Use the Bedrock **Converse / ConverseStream API** via boto3 in us-east-1.
- Discover the exact model IDs or inference profile IDs at runtime with `aws bedrock list-foundation-models --region us-east-1` and `aws bedrock list-inference-profiles --region us-east-1`. Do not hardcode IDs you have not verified. Put them in config.
- Default: Claude Haiku 4.5 for development and automatic alarm summaries. Claude Sonnet 5 (or Sonnet 4.6 if Sonnet 5 is unavailable) for the chat and the final demo. Keep the model ID switchable via env var.
- If a model call fails with a data-retention error, follow the AWS guide (Playground → set data retention to Default) or fall back to another allowed model.

### 8.2 Rate limits and resilience

- Global token bucket in the backend: at most about 0.8 requests per second total, queue the rest.
- Cache automatic insights per (batch, alarm state, contributor set).
- Automatic insights fire **only on state transitions** (normal→watch, watch→alarm, alarm→recovered), never on every tick.
- Exponential backoff on ThrottlingException. If Bedrock is down, the UI shows a deterministic template summary built from the engine outputs (the product still works without the LLM).

### 8.3 Tools (JSON schema in `backend/app/agent/tools.py`)

| Tool | Purpose | Backed by |
|---|---|---|
| `get_reactor_state(reactor_id)` | Latest sensors, progress, health, forecast | ReplayEngine + pipeline cache |
| `predict_final_yield(reactor_id)` | Forecast with interval and vs-golden | Engine A |
| `explain_drivers(reactor_id, scope)` | Global, local, interactions | Engine C |
| `diagnose_alarm(reactor_id)` | Contributors, onset, likely cause | Engine B + C |
| `recommend_settings(reactor_id, mode)` | Energy or rescue recommendation | Engine D |
| `simulate_what_if(reactor_id, at_h, changes)` | Counterfactual outcome | 7.5 |
| `estimate_point_of_no_return(reactor_id)` | Countdown and confidence | 7.5 |
| `get_model_evidence()` | Accuracy, false alarms, coverage | metrics/*.json |
| `get_data_provenance(field)` | measured/published/assumed/synthetic and source | constants.yaml + data registry |

### 8.4 System prompt (store in `backend/app/agent/prompts/system.md`)

Key rules to encode:

- You are Kairos, a fermentation process co-pilot speaking to plant operators and process engineers.
- **Every number you state must come from a tool result in this conversation.** If you do not have it, call a tool or say you do not know.
- Always give: what is happening, why (top 1 to 3 drivers), what to do (one concrete action), expected effect with its range, and confidence.
- Mention uncertainty and data provenance when relevant ("model estimate from simulated data").
- Be concise: operators read on a phone. Lead with the action. Under 90 words for alarm summaries unless asked for more.
- Never claim real-plant validation. The data is simulated (IndPenSim) unless stated otherwise.
- Never give safety-critical instructions beyond process setpoints; recommend operator verification for any change.

### 8.5 Output formats

- **Alarm card** (structured JSON the agent fills via a final "respond" tool or JSON mode): `title`, `summary`, `action`, `expected_effect`, `confidence`, `ponr_hours`, `evidence[]`.
- **Chat:** streamed markdown with inline "evidence chips" (the backend attaches the tool calls used so the UI can show "Based on: yield model, fault detector").

---

## 9. Backend service

### 9.1 Stack

- Python 3.11, **uv** for dependency management
- FastAPI, uvicorn, pydantic v2, pydantic-settings
- numpy, pandas (or polars), pyarrow, scikit-learn, lightgbm, shap, mapie, optuna, scipy, joblib
- boto3 (Bedrock)
- structlog (JSON logs), orjson
- pytest, pytest-asyncio, httpx; ruff (lint + format); mypy (strict on `app/` and `kairos_ml/`)

### 9.2 Modules

```
backend/app/
  main.py                 # app factory, lifespan loads artifacts
  config.py               # Settings (env-driven), no secrets in code
  api/
    routes_reactors.py    # list, detail, start/pause/seek/speed replay
    routes_batches.py     # batch catalogue, golden trajectories
    routes_metrics.py     # evidence (reads metrics/*.json)
    routes_whatif.py      # what-if, recommendations
    routes_agent.py       # chat (SSE or WS stream), alarm insights
    routes_meta.py        # provenance registry, health, version
    ws.py                 # /ws stream, subscription by reactor
  replay/
    engine.py             # async ticker, speed control, seek, multi-reactor
    scenarios.py          # demo scenarios (which batch on which reactor)
  pipeline/
    inference.py          # runs engines per tick, caches latest state
    events.py             # event models + in-process pub/sub
  agent/
    service.py            # Converse loop with tool use, streaming
    tools.py              # tool schemas + dispatch
    ratelimit.py          # token bucket
    prompts/system.md
  core/
    logging.py, errors.py, security.py
```

### 9.3 Replay engine

- Each "reactor" is a slot (R1 to R4) bound to a batch ID and a speed (e.g. 1 batch-hour per 1 to 2 real seconds by default; adjustable 0.5× to 50×).
- Controls: start, pause, seek(progress), set_speed, swap_batch.
- On each tick: slice the next row(s), run the inference pipeline, publish a `tick` event; publish `alarm`, `insight`, `ponr` events on transitions.
- Demo scenarios in `scenarios.py`, e.g. `investor_demo`: R1 normal batch, R2 fault batch (strongest, clearest fault), R3 normal batch with a different strategy, R4 energy-optimised replay.

### 9.4 Performance

- Inference per tick must take under 50 ms for 4 reactors on a t3.xlarge or a laptop. Precompute heavy things (SHAP global, golden trajectories) at startup. Compute local SHAP at most once per N ticks or on demand.

---

## 10. Real-time protocol

### 10.1 WebSocket `/ws?token=...`

Client sends `{"type":"subscribe","reactors":["R1","R2"]}`. Server events (all have `type`, `reactor_id`, `ts`, `t_h`, `progress`):

```json
{"type":"tick","reactor_id":"R2","t_h":63.4,"progress":0.31,
 "sensors":{"do_pct":31.2,"ph":6.48,"temp_c":25.1,"rpm":100,"aeration":60,"feed":80,"co2_offgas":0.8,"o2_offgas":19.9},
 "derived":{"our":..., "cer":..., "rq":..., "kla":..., "otr":..., "power_kw":..., "kwh_cum":...},
 "forecast":{"p50":27.1,"p10":24.0,"p90":29.8,"unit":"g/L","vs_golden_pct":88,"confidence":"medium"},
 "health":{"score":64,"state":"watch","top_contributors":[{"var":"do_pct","pct":46,"dir":"low"}]}}
```

```json
{"type":"alarm","reactor_id":"R2","t_h":71.2,"state":"alarm","severity":"critical",
 "contributors":[...],"ponr_hours":4.5}
```

```json
{"type":"insight","reactor_id":"R2","card":{"title":"Oxygen limitation developing",
 "summary":"...","action":"Reduce sugar feed 10% for 3 h","expected_effect":"+6 to +11% final yield",
 "confidence":"medium","evidence":["fault_detector","yield_model","energy_model"]}}
```

Units: send canonical units with every payload's schema (document in `docs/API.md`). Exact sensor keys are decided after data inspection and frozen in a shared schema file.

### 10.2 REST (prefix `/api/v1`)

- `GET /reactors` · `GET /reactors/{id}` · `POST /reactors/{id}/control` (start, pause, seek, speed, swap)
- `GET /batches` · `GET /batches/{id}/trajectory` · `GET /golden`
- `POST /whatif` · `POST /recommend`
- `GET /metrics` (yield, faults, energy, coverage)
- `GET /provenance`
- `POST /agent/chat` (stream via SSE) · `GET /agent/insights/{reactor_id}`
- `GET /healthz` · `GET /version`

**Shared schema:** generate TypeScript types from FastAPI's OpenAPI (`openapi-typescript`) and Dart models (freezed + json_serializable) from the same field list. Do not hand-maintain divergent types.

---

## 11. Design system (shared across web and mobile)

### 11.1 Principles

1. **Calm until it matters.** The default state is quiet and dark like a control room. Colour and motion are reserved for state changes. A judge should spot the problem reactor in under one second.
2. **One accent, three states.** Bioluminescent teal is the brand accent. Amber means watch, red means alarm, green means healthy. Nothing else competes.
3. **Numbers are first-class.** Monospaced tabular numerals, units always shown, uncertainty always shown (p10 to p90).
4. **Provenance is visible.** Every metric can show a small label chip: Measured / Published / Assumed / Synthetic.
5. **No generic dashboard.** No grids of identical cards with line charts. The 3D twin is the hero; charts are minimal, purposeful, and secondary.
6. **Same product, two surfaces.** Web and mobile share tokens, iconography, copy, and state colours. A screenshot of either is recognisably Kairos.

### 11.2 Tokens (single source: `design/tokens.json`)

Generate CSS variables + Tailwind theme (web) and a Dart `ThemeExtension` (Flutter) from this file using **Style Dictionary** (it has CSS and Flutter output formats). Never hardcode colours in components.

**Colour (dark theme is primary):**

| Token | Hex | Use |
|---|---|---|
| `bg.base` | #0A0E13 | app background |
| `bg.surface` | #11171F | panels |
| `bg.elevated` | #18202A | popovers, sheets |
| `bg.inset` | #0D1218 | wells, inputs |
| `border.subtle` | #1F2933 | hairlines |
| `border.strong` | #2E3A47 | focused / hover |
| `text.primary` | #E6EDF3 | main text |
| `text.secondary` | #9AA6B2 | labels |
| `text.muted` | #66727F | hints |
| `accent.500` | #2DD4BF | brand teal (bioluminescent) |
| `accent.600` | #14B8A6 | pressed / strong |
| `accent.glow` | #2DD4BF at 16% | subtle highlights only |
| `state.healthy` | #34D399 | healthy |
| `state.watch` | #F5A524 | watch |
| `state.alarm` | #F43F5E | alarm |
| `state.info` | #60A5FA | informational |
| `provenance.measured` | #34D399 | chip |
| `provenance.published` | #60A5FA | chip |
| `provenance.assumed` | #F5A524 | chip |
| `provenance.synthetic` | #A78BFA | chip |

A light theme is optional (useful for deck screenshots); derive it from the same tokens.

**Typography:**

- UI: **Inter** (variable). Weights 400 and 500 for most text, 600 only for display numbers.
- Numbers and code: **JetBrains Mono** with tabular numerals.
- Scale (px): 12, 13, 14, 16, 20, 24, 32, 48 (the 48 is only for hero metrics like the PONR countdown).
- Sentence case everywhere. No ALL CAPS except tiny overlines (11 to 12 px, letter-spacing 0.06em).

**Spacing:** 4 px base grid: 4, 8, 12, 16, 24, 32, 48, 64.
**Radius:** 6 (controls), 10 (cards/panels), 16 (sheets/modals), full (pills).
**Elevation:** use surface colour steps, not heavy shadows. One soft shadow token for floating sheets.
**Motion:** durations 120 / 200 / 320 ms; easing `cubic-bezier(0.2, 0.8, 0.2, 1)`. Respect reduced motion. Alarms use one pulse on entry, then a calm steady state (no endless flashing).
**Iconography:** Lucide (web) and `lucide_icons` (Flutter), outline, 1.5 px stroke.

### 11.3 Shared components (build on both platforms with identical semantics)

- `StatusPill` (healthy / watch / alarm with dot)
- `MetricReadout` (label, value, unit, optional p10 to p90 range, provenance chip, delta)
- `ProvenanceChip` (M / P / A / S with tooltip naming the source)
- `ConfidenceMeter` (low / medium / high, three segments)
- `InsightCard` (the agent's alarm card: title, summary, action button, expected effect, confidence, evidence chips)
- `PonrCountdown` (large mono countdown with a ring)
- `TimelineScrubber` (web) / `EventStrip` (mobile): batch progress with markers for alarm onset, PONR, interventions
- `EvidenceChip` ("Based on: fault detector")
- `EmptyState`, `ErrorState`, `Skeleton` (every async view has all three)

### 11.4 Copy and voice

- Plain, confident, short. "Oxygen limitation developing", not "Anomaly detected in DO2 channel".
- Always pair a problem with an action.
- Units always: "31% DO", "780 rpm", "27.1 g/L (24.0 to 29.8)".
- Never overclaim: "model estimate" on every predictive number's tooltip.

---

## 12. Web app: Kairos Control Room

### 12.1 Stack

- **Vite + React + TypeScript (strict)**
- **React Three Fiber + drei** for the 3D twin; `@react-three/postprocessing` only for a restrained bloom on the accent glow
- **Zustand** (live state from WebSocket) + **TanStack Query** (REST)
- **Tailwind CSS** wired to generated tokens; **Radix UI** primitives for accessible popovers, dialogs, tooltips, sliders
- **Framer Motion** for UI transitions
- **uPlot** or **visx** for the few charts (lightweight, styled to tokens)
- ESLint + Prettier, Vitest, Playwright (one smoke test that loads the room and receives ticks)

### 12.2 Information architecture

1. **Fleet** (`/`): four 3D reactors on a dark stage, each with a floating status pill, forecast vs golden, and health. The faulty one is instantly visible (amber/red rim light, broth colour shift). Click a reactor to fly the camera in.
2. **Reactor** (`/reactor/:id`), the hero screen:
   - **Center:** the 3D twin, large.
   - **Left rail (vitals):** compact `MetricReadout`s for DO, pH, temperature, agitation, aeration, feed, OUR, RQ, power, each with a 30-minute micro-sparkline and a provenance chip.
   - **Right rail (copilot):** current `InsightCard`, `PonrCountdown` when in alarm, the `Recommendation` with a "Simulate" button, and the Ask Kairos chat.
   - **Bottom:** the `TimelineScrubber` (flight recorder): progress bar with markers, play/pause, speed, scrub to any moment (the whole UI rewinds to that state).
   - **What-if drawer:** sliders for feed, agitation, aeration at a chosen time; shows the projected final yield band vs current forecast and the energy delta. "Model estimate" label.
3. **Evidence** (`/evidence`): the judges' page. Real metrics from `metrics/*.json`:
   - Yield error vs batch progress (convergence curve), with naive/linear/mechanistic baselines
   - Interval coverage (target 90%, actual X%)
   - Fault detection: per-batch detection delay table, false alarms on normal batches, MSPC vs Kairos comparison, delay vs false-alarm trade-off curve
   - Top drivers and top interaction pairs, with plain-language sentences
   - Energy: kWh vs yield Pareto, kLa/OTR vs power trade-off
   - Data provenance table (every input with its label and link)
4. **About / Method** (`/method`): a one-page explainer of the hybrid approach with a simple diagram, assumptions, and limitations. Useful in Q&A.

### 12.3 The 3D twin specification

- Glass cylindrical vessel with stainless steel head and base, a sparger ring, baffles (4), and a Rushton impeller on a shaft.
- **Data bindings (every visual means something):**
  - Impeller rotation speed ∝ agitation RPM
  - Bubble count and rise speed ∝ aeration rate (instanced meshes, pooled)
  - Broth hue mapped from pH (narrow, tasteful range around the setpoint; deviation shifts hue)
  - Broth opacity and turbidity ∝ biomass estimate
  - A soft inner glow (accent teal) ∝ current production rate
  - A DO ring gauge around the vessel's mid-height (fills by DO %, turns amber/red below the critical threshold)
  - Rim light colour = health state; one pulse on alarm entry
  - Liquid level ∝ vessel volume
- Hover any part to see its live value (e.g. hover impeller → "780 rpm · 41 kW").
- Performance target: 60 fps on a mid-range laptop; cap device pixel ratio at 2; pause rendering when the tab is hidden; WebGL-unavailable fallback is a 2D cutaway SVG with the same bindings.
- Camera: slow idle orbit on Fleet; smooth fly-to on selection; user can orbit and zoom within limits.

### 12.4 Quality checklist (web)

- Keyboard navigable, visible focus rings, ARIA labels on icon buttons
- Responsive down to 1280 px wide for the demo laptop; usable on a tablet
- Every async view has loading skeleton, empty, and error states
- WebSocket auto-reconnect with backoff and a visible connection status indicator
- No console errors; Lighthouse performance reasonable outside the 3D canvas

---

## 13. Mobile app: Kairos Pager (Flutter)

### 13.1 Stack

- Flutter (latest stable), Dart null-safety, Material 3 with Kairos `ThemeExtension` from generated tokens
- **Riverpod** (state), **go_router** (navigation), `web_socket_channel`, `dio` (REST)
- `freezed` + `json_serializable` (models), `flutter_local_notifications` (alarm notifications), `HapticFeedback` (haptics), an alert sound asset
- `flutter_markdown` for agent responses
- Lints: `very_good_analysis` or `flutter_lints` (strict); widget tests for key screens

### 13.2 Screens

1. **Pair** (first launch): enter or scan (QR from the web app) the server URL and demo token. Saved securely (`flutter_secure_storage`).
2. **Plant** (home): list of reactors as tall cards with a mini vessel illustration (2D, animated by aeration/agitation), status pill, forecast vs golden, health. Pull to refresh; live via WS.
3. **Alarm takeover:** when an `alarm` event arrives in the foreground, a full-screen takeover with one strong haptic pattern and sound: title, reactor, `PonrCountdown`, the agent's action in large type, buttons "View details" and "Acknowledge". In background, a local notification with the same title and action.
4. **Reactor detail:** vitals list (same `MetricReadout` semantics as web), event strip, `InsightCard`, recommendation, and "Ask Kairos" entry.
5. **Ask Kairos:** chat with streaming responses and evidence chips. Suggested prompts: "Why is R2 drifting?", "What should I change?", "How much energy can we save on R1?"
6. **Settings:** server, notification test, theme, about/provenance.

### 13.3 Demo-critical behaviour

- The alarm takeover must fire within 1 second of the server event. Test this repeatedly.
- Works on a physical Android phone over the same Wi-Fi as the laptop (and over the hosted URL if S5 is done).
- Acknowledge sends `POST /reactors/{id}/ack` so the web shows "Acknowledged by operator" (a nice cross-device moment).

---

## 14. AWS deployment

### 14.1 Principles

- **The laptop is the primary demo.** The jury may ask to see the prototype live; venue Wi-Fi can fail. `docker compose up` on the demo laptop must run everything locally except Bedrock calls.
- The hosted version is a bonus link for the submission form (and dies with the account, so also record the demo video).

### 14.2 Hosted setup (S5)

- Region **us-east-1** everywhere (set `AWS_REGION=us-east-1` in env and code defaults).
- **EC2** t3.xlarge (or smaller), Amazon Linux 2023, Docker + docker compose. An IAM instance profile allowing `bedrock:InvokeModel*` / `bedrock:Converse*` and read access to the private S3 bucket. No access keys on the box.
- **CloudFront** in front of the EC2 origin for HTTPS (CloudFront supports WebSockets), so the web app and mobile app can use `https://` and `wss://`. The backend serves the built web app as static files, or nginx in compose serves `web/dist` and proxies `/api` and `/ws`.
- **S3** private bucket for data and model artifacts. Block Public Access stays on.
- Infrastructure as code: `infra/deploy.sh` with AWS CLI commands (create bucket, security group, instance with user-data, CloudFront distribution) and `infra/teardown.sh`. Keep every command in the repo; console clicks cannot be replayed.
- Optional: AWS Amplify Hosting for the web build, but then the backend must also be HTTPS (CloudFront) to avoid mixed-content WS errors.

### 14.3 Local credentials

- Copy temporary credentials from the Workshop Studio event page into the terminal environment (or `~/.aws/credentials` profile `kairos`). They expire; refresh when needed. Never commit them. `.env.example` lists variable names only.

---

## 15. Repository structure and engineering standards

```
kairos/
├── KAIROS_BUILD_SPEC.md        # this file
├── README.md                   # quickstart, architecture image, demo GIF, references
├── Makefile                    # make setup | data | train | eval | dev | up | test | lint
├── docker-compose.yml
├── .env.example                # names only
├── .gitignore                  # data/, models/ large files, .env, *.pem, node_modules, build/
├── design/
│   ├── tokens.json
│   └── build-tokens.mjs        # Style Dictionary → web/src/styles/tokens.css, tailwind preset, mobile/lib/theme/tokens.dart
├── ml/
│   ├── pyproject.toml
│   ├── config/ (constants.yaml, splits.json, features.yaml)
│   ├── kairos_ml/
│   │   ├── data/ (load.py, inspect.py, clean.py, schema.py)
│   │   ├── features/ (engineering.py, golden.py, offgas.py)
│   │   ├── engines/ (yield_model.py, fault_detector.py, why.py, energy.py, recommender.py, ponr.py, whatif.py)
│   │   ├── physics/ (oxygen_transfer.py, power.py, kinetics.py)
│   │   └── eval/ (yield_eval.py, fault_eval.py, energy_eval.py, report.py)
│   ├── scripts/ (train_all.py, evaluate_all.py, export_artifacts.py)
│   ├── notebooks/ (exploration only; never the source of truth)
│   └── tests/
├── backend/
│   ├── pyproject.toml
│   ├── app/ (see section 9.2)
│   ├── tests/
│   └── Dockerfile
├── web/
│   ├── package.json
│   ├── src/ (app/, features/{fleet,reactor,evidence,method}/, components/, three/, lib/{api,ws,store}/, styles/)
│   ├── tests/
│   └── Dockerfile
├── mobile/
│   ├── pubspec.yaml
│   └── lib/ (app/, features/{pair,plant,alarm,reactor,chat,settings}/, core/{api,ws,models,theme}/, widgets/)
├── artifacts/                  # models/*.joblib (small), metrics/*.json, golden/*.parquet (gitignored if large)
├── infra/ (deploy.sh, teardown.sh, cloudfront.json, user-data.sh)
└── docs/
    ├── DECISIONS.md            # every non-obvious choice with a reason
    ├── DATA_PROFILE.md
    ├── API.md
    ├── ASSUMPTIONS.md          # every assumption with provenance
    ├── LIMITATIONS.md
    ├── DEMO_SCRIPT.md
    └── REFERENCES.md
```

**Standards:**

- Type everything (mypy strict on Python packages, TS strict, Dart strict analysis).
- Lint and format before every commit (ruff, eslint/prettier, dart format). Add a pre-commit config.
- Small, focused modules; no 1,000-line files.
- Config via environment (pydantic-settings); no magic numbers in code (constants.yaml).
- Conventional commits (`feat:`, `fix:`, `chore:`). **Commit and push at least hourly.**
- A GitHub Actions workflow that runs lint and tests for ml, backend, web, mobile (fast; skip heavy training).
- README with a 60-second quickstart that a teammate can follow on a fresh laptop.

---

## 16. Security, privacy, and rules compliance

- No access keys, tokens, or passwords anywhere in the repo, prompts, notebooks, or logs. Use instance roles and env vars.
- `.gitignore` covers `.env`, `*.pem`, data folders, credentials files. Add a secret scan (e.g. `gitleaks`) to pre-commit or CI.
- S3 Block Public Access on. No public buckets.
- Demo auth: a simple bearer token for WS/REST (from env) so the hosted URL is not wide open. CORS restricted to known origins.
- No personal or sensitive data is used or collected. The app stores no user data beyond a device's server URL and token.
- Bedrock: respect the rate limit (section 8.2). No tight loops.
- Licences: credit IndPenSim, LBNL, all libraries and models in `docs/REFERENCES.md` and the deck.

---

## 17. Testing and acceptance criteria

### 17.1 ML

- Unit tests for physics functions (known-value checks for power and kLa), feature leakage tests (no future values in features at time t), split integrity (no batch in two splits).
- `make eval` regenerates `artifacts/metrics/*.json` deterministically.
- **Acceptance:** the yield model beats all three baselines at p = 0.3 and 0.5 on test-normal; interval coverage within ±5% of the 90% target; the fault detector catches the majority of fault batches with a stated median delay and a false-alarm rate at or below the target on test-normal; MSPC vs Kairos comparison reported honestly even if MSPC wins on some batches.

### 17.2 Backend

- API contract tests (httpx), WebSocket test that subscribes and receives ticks and an alarm in the fault scenario, agent tool dispatch tests with a mocked Bedrock client.
- **Acceptance:** `docker compose up` starts in under 60 seconds; 4 reactors stream at default speed with under 50 ms inference per tick; the fault scenario produces an alarm and an insight card.

### 17.3 Web

- Vitest for stores and formatters; Playwright smoke: open Fleet → enter R2 → receive ticks → alarm appears → insight card renders.
- **Acceptance:** 60 fps on the demo laptop with 4 reactors on Fleet; no console errors; every view has loading/empty/error states.

### 17.4 Mobile

- Widget tests for Plant and Alarm screens; manual test of the takeover on a real phone 5 times in a row.
- **Acceptance:** alarm takeover within 1 second of the server event; acknowledge reflects on web.

### 17.5 End-to-end demo rehearsal

- Run the full demo script (section 19) three times without touching code. Record the best take as the 2-minute video.

---

## 18. Build plan and timeline (IST)

Assume roughly four people: **ML**, **Backend+Agent**, **Web**, **Mobile+Deck**. Adjust if the team is smaller (merge Backend with ML, Mobile with Deck).

| Time | ML | Backend + Agent | Web | Mobile + Deck |
|---|---|---|---|---|
| 12:00–13:00 | Download IndPenSim, `inspect.py`, `DATA_PROFILE.md` | Repo scaffold, Makefile, compose, CI, settings | Tokens + Style Dictionary, Vite app shell, layout | Flutter scaffold, theme from tokens, Pair screen. **Declare 3(a) by 1 PM.** |
| 13:00–15:00 | Cleaning, splits, features, golden trajectories | Replay engine with raw data, WS tick events | 3D vessel model with impeller and bubbles bound to mock data | Plant screen with mock WS data |
| 15:00–17:00 | Yield model + baselines + conformal; MSPC baseline | Inference pipeline wiring engines as they land | Reactor screen layout, vitals rail, timeline | Alarm takeover + local notifications + haptics |
| 17:00–18:00 | Improved detector + persistence; first metrics JSON | Bedrock client, tool schemas, rate limiter | Bind 3D to real WS ticks | Reactor detail screen |
| 18:00–20:00 *(mentor round)* | Validate science with mentors; SHAP drivers + interactions | Agent loop working end-to-end (alarm insight) | Copilot panel, InsightCard, chat streaming | Ask Kairos chat; start deck outline |
| 20:00–22:00 | Energy physics + recommender; PONR tier 1 | What-if and recommend endpoints | What-if drawer, PONR countdown | Hook all mobile screens to real backend |
| 22:00–01:00 | Evaluation report polish; delay vs false-alarm curve | Scenarios, ack flow, hardening, tests | Evidence page from metrics JSON, Fleet view | Official template arrives: build deck |
| 01:00–03:00 | Stretch: C1 ODE twin or C2 LBNL (only if Musts are green) | Optional AWS hosted deploy (S5) | Polish: motion, empty/error states, a11y | Polish mobile; screenshots for deck |
| **03:00** | **Feature freeze.** Push everything. | | | |
| 03:00–05:00 | Fix bugs only; rehearse demo 3 times | | | Record 2-minute demo video; finalise References slide |
| 05:00–06:00 | Final push, verify a clean clone runs on another laptop | | | Export deck to PDF |
| 06:00–08:00 | **Submit** (deck PDF, video, repo link). Do not wait until 7:55. | | | |
| 08:30–10:00 | Pitch practice round | | | |

---

## 19. Demo script (the 30 to 60 seconds that win the room)

1. Open the Fleet: four reactors gently bubbling. "These are four bioreactors replaying real-scale fermentation batches."
2. Point at R2: rim light turning amber, broth hue shifting. On the jury table, **the phone buzzes**: "Oxygen limitation developing on R2. About 4 hours before the point of no return. Reduce sugar feed 10% for 3 hours."
3. Fly into R2. Show the PONR countdown and the insight card. Hover the impeller and DO ring.
4. Open the what-if drawer: apply the recommendation at the alarm time. The projected final yield band moves back toward normal. "Model estimate, with uncertainty, on simulated industrial-scale data."
5. Scrub the timeline back: "Here is the moment it went wrong, 6 hours before a human would have noticed from the screens."
6. Type in Ask Kairos: "Why did this happen and how much energy can R1 save?" The answer streams, with evidence chips.
7. Flash the Evidence page: yield error vs progress beating baselines, false alarms on normal batches, coverage. "Every number here is reproducible from our repo."

---

## 20. Pitch deck content (4 minutes, on the official template)

1. **Hook (20 s):** "A single failed industrial batch can waste days of reactor time and the feedstock and power that went into it. Operators still run fermentation on fixed settings and gut feel." (Verify any cost figure before quoting it; otherwise keep it qualitative.)
2. **Problem and user (30 s):** the operator and process engineer's decision during a run. Why this matters for alternative proteins (precision and biomass fermentation economics).
3. **Kairos (40 s):** see it coming, know why, know how long you have, know what to do, prove it, save energy.
4. **Live demo / video (60 s).**
5. **How it works (30 s):** hybrid physics + ML; four engines; Claude as a grounded agent; architecture diagram.
6. **Evidence (30 s):** the three headline metrics (early yield accuracy at 30% progress, median detection delay with false alarm rate, energy saved at equal yield), each with its data label.
7. **Why it is credible (15 s):** data provenance table summary, limitations stated.
8. **Six-month plan and business (25 s):** pilot partner, retrofit edge box, pricing per reactor, costs (section 22).
9. **Ask and team (10 s).**
10. **References** (every source as a clickable link).

Keep slides visual: screenshots of the 3D twin and the phone takeover, not bullet walls.

---

## 21. Judge Q&A bank (prepare short answers)

- *"Your data is simulated. Why should we trust it?"* IndPenSim is a published simulator of an industrial-scale process and a recognised benchmark. We label it synthetic everywhere. Our pipeline is data-agnostic; we show ingestion of measured LBNL runs (if C2 done), and the six-month plan starts with retraining on a pilot partner's historian data.
- *"Penicillin is not alternative protein."* Both are aerobic fed-batch fermentations where oxygen transfer, feed strategy, pH, and temperature drive yield, and where energy goes to agitation and aeration. The method transfers; the models retrain per process.
- *"How do you control false alarms?"* Golden-trajectory normalisation, empirical control limits on held-out normal batches, persistence and hysteresis, and we report false alarms per 100 batch-hours on batches the model never saw.
- *"How is the point of no return computed?"* Section 7.5 definition; it is a model estimate with an interval, not a guarantee.
- *"Where is AI meaningful, not decorative?"* The ML engines make the predictions; Claude orchestrates them as tools, reasons across them, and turns them into operator actions. It never invents numbers, and the product still works if the LLM is off.
- *"Energy numbers?"* Standard power-number and van't Riet kLa correlations with stated assumptions for geometry and compressor efficiency, shown as ranges.
- *"How would you deploy at a real plant?"* Read-only connection to the plant historian or PLC via OPC-UA/Modbus through an edge box, shadow mode first (advice only), operator always in control.
- *"What did you build in 24 hours vs before?"* Be honest.

---

## 22. Startup and six-month plan

**Customer segments:**

1. Precision and biomass fermentation startups scaling from bench to pilot (India: e.g. companies working on fermentation-derived dairy proteins and gas fermentation; globally the same segment).
2. Contract development and manufacturing organisations (CDMOs) and university or government pilot plants that run many different processes and need fewer failed runs.
3. Adjacent markets: enzymes, industrial biotech, pharma fermentation, brewing.

**Why India first:** a fast-growing biomanufacturing push (the government's BioE3 policy for biomanufacturing), cost-sensitive operators who cannot afford premium analytics hardware (our cheap-sensor approach), and a strong software talent base. **Why global:** the same physics and the same pain everywhere; the software ships as SaaS plus an edge box.

**Product path:**

- Months 0 to 2: pilot with one partner (a university or institute pilot plant, or a startup). Shadow mode: read-only data, weekly reports, measure detection lead time and energy opportunity on their historical batches.
- Months 2 to 4: retrain on partner data; live advisory mode on one reactor; operator feedback loop on alarm usefulness.
- Months 4 to 6: second pilot in a different process; first paid contract; publish a case study.

**What is needed:** historical batch data from the partner (anonymised process data only), a small edge gateway, cloud hosting, two to three engineers plus a bioprocess advisor.

**Business model:** subscription per reactor per month plus an onboarding fee; an energy-savings-share option for larger plants. Put indicative numbers in the deck only after a quick sanity check; mark them as assumptions.

**Market size:** do not quote numbers from memory. Look up current published estimates for precision fermentation and bioprocess analytics during the build, cite them, and label them published.

---

## 23. References (verify every link resolves before putting it on the slide)

**Data**

- IndPenSim, industrial-scale penicillin simulation: industrialpenicillinsimulation.com (and the dataset mirror you actually download from)
- Goldrick, S. et al. (2015). The development of an industrial-scale fed-batch fermentation simulation. *Journal of Biotechnology.*
- Goldrick, S. et al. (2019). Modern day monitoring and control challenges outlined on an industrial-scale benchmark fermentation process. *Computers & Chemical Engineering.*
- LBNL ABPDU, Fermentation Bioreactor Sample Data: https://abpdu.lbl.gov/resources/fermentation-bioreactor-sample-data/

**Science**

- Bajpai, R.K. & Reuss, M. (1980). A mechanistic model for penicillin production. *Journal of Chemical Technology and Biotechnology.*
- Birol, G., Ündey, C. & Çınar, A. (2002). A modular simulation package for fed-batch fermentation: penicillin production. *Computers & Chemical Engineering.*
- van't Riet, K. (1979). Review of measuring methods and results in nonviscous gas-liquid mass transfer in stirred vessels. *Industrial & Engineering Chemistry Process Design and Development.*
- Nomikos, P. & MacGregor, J.F. (1994). Monitoring batch processes using multiway principal component analysis. *AIChE Journal.*
- Lundberg, S.M. & Lee, S.-I. (2017). A unified approach to interpreting model predictions (SHAP). *NeurIPS.*
- Romano, Y., Patterson, E. & Candès, E. (2019). Conformalized quantile regression. *NeurIPS.*
- Related IndPenSim soft-sensing work: bioRxiv (2026), "Towards Digital-Twin-Enabled Bioprocess Monitoring: Fault-Inclusive Soft Sensing of Penicillin Concentration Under Process Deviations", https://www.biorxiv.org/content/10.64898/2026.09.21.753176.full.pdf

**Policy and context**

- India BioE3 policy (Department of Biotechnology), official page
- CEA CO2 Baseline Database (grid emission factor), official page

**Tools and models**

- Amazon Bedrock; Anthropic Claude (exact model IDs used); LightGBM; scikit-learn; SHAP; MAPIE; Optuna; SciPy; FastAPI; React; Three.js; React Three Fiber; Tailwind CSS; Radix UI; Flutter; Riverpod; Style Dictionary; Claude Code (used for development)

---

## 24. Instructions for Claude Code (operating rules)

1. **Start by reading this file fully**, then create `docs/DECISIONS.md` and a task list mirroring section 4 (Must → Should → Could).
2. **Inspect the data before modelling.** Generate `docs/DATA_PROFILE.md` first. Freeze column names into `ml/kairos_ml/data/schema.py` from what actually exists.
3. **Work in vertical slices.** Get a thin end-to-end path working early (replay raw data → WS → web shows numbers → phone shows a card), then deepen each engine. A working ugly path beats a beautiful broken one at 3 AM.
4. **Never fabricate metrics.** Every number on the Evidence page and in the deck comes from `artifacts/metrics/*.json` produced by `make eval`. If a model underperforms, report it honestly and note it in `LIMITATIONS.md`.
5. **Never hardcode secrets or model IDs.** Discover Bedrock model IDs with the AWS CLI; keep them in env/config.
6. **Respect Bedrock limits** (token bucket, caching, transition-only insights).
7. **Provenance everywhere:** every constant has a provenance label; the API returns provenance; the UI shows it.
8. **UI quality is a requirement, not polish.** Use the design tokens only, the shared components, loading/empty/error states for every async view, consistent copy. Web and mobile must feel like one product.
9. **Commit and push at least hourly** with conventional commit messages. Keep `main` runnable.
10. **Tests with every engine and endpoint**, at least the acceptance tests in section 17.
11. **Ask before** large dependency additions, architectural changes, or deleting files. Make small decisions yourself and log them in `DECISIONS.md`.
12. **Feature freeze at 03:00 IST.** After that, only bug fixes, rehearsal, video, and deck support.
13. When in doubt, choose the option that makes the **demo more reliable** and the **science more honest**.
