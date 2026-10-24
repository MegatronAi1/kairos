# Task list (mirrors spec section 4)

Legend: [ ] todo, [~] in progress, [x] done

## Must
- [x] M1 Data ingestion and cleaning, batch-wise splits
- [x] M2 Early yield predictor + conformal intervals (p = 0.2/0.3/0.5/0.7)
- [x] M3 Fault detector: MSPC + improved detector + persistence
- [~] M4 Explainability: SHAP drivers, interactions, alarm contributions
- [~] M5 Energy model (power, kLa, OTR) + setpoint recommender
- [~] M6 Replay streamer + FastAPI + WebSocket
- [x] M7 Claude agent on Bedrock (tool use, streaming, template fallback)
- [~] M8 Web Control Room: 3D twin, vitals, copilot, timeline
- [ ] M9 Flutter Pager: reactor list, alarm takeover, alarm detail
- [x] M10 Evidence page from metrics JSON
- [x] M11 Provenance labels in UI
- [ ] M12 `docker compose up` on one laptop

## Should
- [ ] S1 Point of no return
- [ ] S2 What-if console
- [ ] S3 Fleet view (4 reactors)
- [ ] S4 Pager chat
- [ ] S5 AWS hosted deploy
- [ ] S6 Energy Pareto in UI

## Could
- [ ] C1 Hybrid ODE twin
- [ ] C2 LBNL measured data
- [ ] C3 Raman premium tier
- [ ] C4 Voice readout
- [ ] C5 PDF report
