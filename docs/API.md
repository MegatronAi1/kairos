# Kairos API

Schemas live in `backend/app/schemas.py` (pydantic, the single source). OpenAPI is
at `/openapi.json`. Mobile fixtures in `mobile/test/fixtures/` must parse against the
same shapes.

## Auth

`KAIROS_API_TOKEN` set: REST needs `Authorization: Bearer <token>`, WebSocket needs
`/ws?token=<token>`. Empty token disables auth (local dev only).

## WebSocket `/ws`

Client sends `{"type":"subscribe","reactors":["R1","R2"]}` (empty list = all).
Server replies with a `snapshot` (`{"type":"snapshot","reactors":[ReactorSummary...]}`)
then streams events. All events carry `type, reactor_id, ts (epoch ms), t_h, progress, batch_id`.

| type | when | extra fields |
|---|---|---|
| `tick` | every replay tick (default 2 Hz per reactor) | `sensors`, `derived`, `forecast?`, `health?` |
| `alarm` | health state transition only | `state`, `previous_state`, `severity`, `contributors`, `ponr_hours?` |
| `insight` | after each transition (template first, agent later) | `card`, `source` (`template`/`agent`) |
| `ack` | operator acknowledged | `by` |

Client may send `{"type":"ping"}`; server replies `{"type":"pong"}`.

### Sensor keys (frozen)

| key | unit | provenance | note |
|---|---|---|---|
| `do_pct` | % saturation | synthetic | DO over C* scaled by head pressure (assumed) |
| `do_mgl` | mg/L | synthetic | |
| `ph` | pH | synthetic | |
| `temp_c` | °C | synthetic | |
| `rpm` | rpm | synthetic | constant 100 in IndPenSim |
| `aeration` | m³/min | synthetic | dataset label says L/h; see DECISIONS |
| `feed` | L/h | synthetic | sugar feed |
| `pressure_bar` | bar | synthetic | head pressure |
| `co2_offgas_pct`, `o2_offgas_pct` | % | synthetic | |
| `volume_l` | L | synthetic | |
| `base_lph`, `acid_lph`, `cooling_lph`, `paa_lph`, `oil_lph` | L/h | synthetic | |

### Derived keys

| key | unit | provenance |
|---|---|---|
| `our`, `cer` | mg/L/h | synthetic (dataset OUR/CER per litre) |
| `kla` | 1/h | assumed (van't Riet, assumed geometry) |
| `otr` | mg/L/h | assumed |
| `power_kw`, `agitator_kw`, `compressor_kw` | kW | assumed |
| `kwh_cum` | kWh | assumed |

## REST (`/api/v1`)

- `GET /healthz`, `GET /version`, `GET /provenance`
- `GET /reactors`, `GET /reactors/{id}`, `GET /reactors/{id}/events`
- `POST /reactors/{id}/control` body `{"action":"start|pause|seek|speed|swap|restart", "progress"?, "speed_h_per_s"?, "batch_id"?}`
- `POST /reactors/{id}/ack` body `{"by":"operator"}`
- `GET /batches`, `GET /batches/{id}/trajectory?keys=do_pct&keys=ph&every=5&until_h=63.4`
