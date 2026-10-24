# Limitations

Stated plainly so the jury, mentors and future users know where Kairos is weak. Numbers come
from `artifacts/metrics/*.json` (`make eval`).

## Data
- **All data is simulated** (IndPenSim, a published industrial-scale penicillin simulator). No
  real-plant validation. Every number in the UI carries a provenance label.
- Only 100 batches: 60 train, 15 validation, 15 test-normal, 10 fault. Error rates are indicative.
- The dataset's published statistics file does not match its own time series (r = 0.33), so the
  yield target is derived from the time series (harvests + final P x V).
- Agitation is constant (100 rpm) in every batch: agitation effects come from physics
  correlations only, not from data.
- Dataset OUR/CER units do not give a physical respiratory quotient; RQ is used only as a ratio.

## Yield forecast
- Early forecasts on **fault batches** are poor: at 20-30% progress the error is ~1000 kg and the
  80% interval covers only 40-50% of fault batches (leave-one-fault-out). From 50% progress the
  error falls to ~320 kg. Once the detector alarms, the interval is widened using held-out fault
  residuals, so the UI shows the uncertainty instead of false precision.
- Alarm-state interval widths are calibrated and evaluated on the same 10 fault batches.
- Lab penicillin and biomass (offline, ~12 h apart) are inputs, as in normal plant QC.

## Fault detection
- pH-control faults are weak spots: batch 92 is caught ~91 h after the estimated onset and batch
  98 is missed. The pH loop compensates through base dosing, which keeps the deviation small.
- 3 false alarms across 15 held-out normal batches (0.2 per batch), above the spec's stretch target of
  under 1 per 10 batches. Classic MSPC on the same batches gives 11.4 per batch.
- Onsets for 4 of 10 fault batches are estimated from the data (labelled as estimates); a later
  true onset would make the measured delay look worse, an earlier one better.
- Alarms latch until acknowledged, so a process that partly adapts to a fault keeps the alarm.

## Energy
- Power uses a Rushton power number, van't Riet kLa and an assumed compressor specific energy
  with assumed vessel geometry. Values are order-of-magnitude, shown as assumed.
- Raw van't Riet OTR is far above the dataset OUR on the same units; a fitted calibration is
  required before any OTR-versus-OUR constraint is trusted.

## Copilot (Claude on Bedrock)
- The LLM never produces numbers; it phrases engine outputs. If Bedrock is down or the
  temporary credentials expire, the rule-based cards and all forecasts and alarms keep working.

## Impact page

Plant history (batches, failures, energy and feedstock per batch, prices) is simulated with fixed seeds per plant and labelled as such on the page and in the exports. Only the improvement rates (fault detection share, energy saving) come from the evaluation in `artifacts/metrics`. The rescued-batch share and the feed-optimisation share are stated assumptions (see `backend/app/impact.py`).

## Live demo loop

Reactors restart their batch after an 8 s turnaround, so the same held-out batches repeat. "Simulate alarm" swaps a reactor to a fault batch (96, 97 or 100) for one cycle.
