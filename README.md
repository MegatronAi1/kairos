# Kairos

**AI co-pilot for alternative-protein fermentation.** Kairos watches the sensors a plant already has, forecasts final yield early, catches drift with few false alarms, estimates how long an operator has to act, and recommends agitation and aeration settings that save energy at a safe oxygen level. A Claude copilot on Amazon Bedrock turns all of this into one clear action, on a web control room and on the operator's phone.

Built at Hack the Fork 2026 (NIFTEM-K), problem statement 3(a): process intelligence for smart protein.

- Live demo: see the URL in the submission form (CloudFront, us-east-1)
- Demo accounts: `operator@aurora.demo` / `kairos-demo`, `manager@aurora.demo` / `kairos-demo`
- The demo company, Aurora Bioproteins, and its 15 plants (in the Hack the Fork 2026-27 host cities) are fictional. Replays loop; **Simulate alarm** (top bar) replays a real fault batch on demand. Every reactor replays a held-out batch of the IndPenSim industrial fermentation benchmark (synthetic data), so all forecasts and alarms are real model outputs on data the models never saw.

## Results (held-out batches, `make eval`)

| KPI (problem statement 3a) | Result |
|---|---|
| Yield prediction accuracy | 523 kg mean error at 30% of the batch vs 756 kg naive (31% better); 90% intervals cover 90% |
| Fault-detection performance | 9 of 10 fault batches caught, median 2.6 h after onset |
| False alarms | 0.2 per normal batch, vs 11.4 for classic MSPC |
| Oxygen transfer vs energy | 26% less agitation + aeration energy at dissolved oxygen above 35% sat (yield forecast change within ±3%) |
| Point of no return | median 24 h of warning across detected fault batches (model estimate) |

Numbers come from `artifacts/metrics/*.json`; limitations are in [docs/LIMITATIONS.md](docs/LIMITATIONS.md).

## How it works

```
IndPenSim CSV (100 batches) -> repair + Parquet -> batch-wise splits (60/15/15 + 10 faults)
  -> golden trajectory, causal features
  -> yield model (LightGBM + ridge, conformal intervals)    -> forecast + range
  -> fault detector (MSPC + EWMA + persistence + latching)  -> health, alarms
  -> why engine (exact additive attributions)               -> drivers
  -> energy engine (van't Riet kLa + O2 balance)            -> setpoints, kWh, CO2
  -> rescue engine (healthy analog batches)                 -> point of no return, what-if
FastAPI replay streams held-out batches through the engines -> WebSocket
  -> Control Room (React + three.js) and Pager (Flutter) ; Claude agent (Bedrock) with engine tools
```

## Run it

Prerequisites: Python 3.11 + [uv](https://docs.astral.sh/uv/), Node 20 + pnpm, Flutter (for the phone app), Docker (optional). Put the IndPenSim CSV under `data/raw/` (see [docs/REFERENCES.md](docs/REFERENCES.md)).

```bash
uv sync --all-packages                         # Python workspace (ml + backend)
uv run python -m kairos_ml.data.inspect        # profile data -> docs/DATA_PROFILE.md
uv run python -m kairos_ml.data.splits         # splits + fault onsets
uv run python ml/scripts/train_all.py          # train -> artifacts/models/kairos.joblib
uv run python ml/scripts/evaluate_all.py       # metrics -> artifacts/metrics/*.json
uv run uvicorn app.main:app --app-dir backend --port 8000
cd web && pnpm install && pnpm dev             # http://localhost:5173
```

Or everything in containers: `docker compose up --build` -> http://localhost:8080.

Copilot (optional): an AWS profile with Bedrock access and, in `.env`, `AWS_PROFILE`, `KAIROS_MODEL_CHAT`, `KAIROS_MODEL_FAST` (see `.env.example`). Without it, alarms use rule-based cards and everything else works.

Phone: `cd mobile && flutter run`, sign in with a demo account and the server URL.

Hosted: `uv run python infra/deploy.py` (S3 + EC2 + CloudFront, us-east-1), `infra/update.py` to ship a new commit to the same URL, `infra/teardown.py` to remove it.

## Repository

- `ml/` engines, features, evaluation (`kairos_ml`)
- `backend/` FastAPI, replay, agent, process library
- `web/` Control Room; `mobile/` Kairos Pager (Flutter)
- `design/` tokens and brand; `infra/` deployment; `docs/` decisions, limitations, references, demo script
