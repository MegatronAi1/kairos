from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends

from app.core.security import require_token
from app.schemas import SensorSpec
from kairos_ml.constants import load_constants

router = APIRouter(tags=["meta"])

VERSION = "0.1.0"

# Every value the clients show, with unit and provenance (spec section 11.1, rule 4).
SENSORS: list[SensorSpec] = [
    SensorSpec(
        key="do_pct",
        label="Dissolved oxygen",
        unit="% sat",
        provenance="synthetic",
        note="DO (mg/L) over C* scaled by head pressure (assumed Henry's law)",
    ),
    SensorSpec(key="do_mgl", label="Dissolved oxygen", unit="mg/L", provenance="synthetic"),
    SensorSpec(key="ph", label="pH", unit="pH", provenance="synthetic"),
    SensorSpec(key="temp_c", label="Temperature", unit="°C", provenance="synthetic"),
    SensorSpec(key="rpm", label="Agitation", unit="rpm", provenance="synthetic"),
    SensorSpec(
        key="aeration",
        label="Aeration",
        unit="m³/min",
        provenance="synthetic",
        note="Dataset labels L/h; magnitude implies m³/min (assumed)",
    ),
    SensorSpec(key="feed", label="Sugar feed", unit="L/h", provenance="synthetic"),
    SensorSpec(key="pressure_bar", label="Head pressure", unit="bar", provenance="synthetic"),
    SensorSpec(key="co2_offgas_pct", label="Off-gas CO₂", unit="%", provenance="synthetic"),
    SensorSpec(key="o2_offgas_pct", label="Off-gas O₂", unit="%", provenance="synthetic"),
    SensorSpec(key="volume_l", label="Broth volume", unit="L", provenance="synthetic"),
    SensorSpec(key="base_lph", label="Base dosing", unit="L/h", provenance="synthetic"),
    SensorSpec(key="acid_lph", label="Acid dosing", unit="L/h", provenance="synthetic"),
    SensorSpec(key="cooling_lph", label="Cooling water", unit="L/h", provenance="synthetic"),
    SensorSpec(key="paa_lph", label="Precursor feed", unit="L/h", provenance="synthetic"),
    SensorSpec(key="oil_lph", label="Oil feed", unit="L/h", provenance="synthetic"),
    SensorSpec(
        key="our",
        label="Oxygen uptake",
        unit="mg/L/h",
        provenance="synthetic",
        note="Dataset OUR scaled per litre",
    ),
    SensorSpec(key="cer", label="CO₂ evolution", unit="mg/L/h", provenance="synthetic"),
    SensorSpec(
        key="kla",
        label="kLa",
        unit="1/h",
        provenance="assumed",
        note="van't Riet (1979) correlation with assumed geometry",
    ),
    SensorSpec(key="otr", label="Oxygen transfer", unit="mg/L/h", provenance="assumed"),
    SensorSpec(
        key="power_kw",
        label="Electrical power",
        unit="kW",
        provenance="assumed",
        note="Agitator (power number) + compressor (assumed specific energy)",
    ),
    SensorSpec(key="agitator_kw", label="Agitator power", unit="kW", provenance="assumed"),
    SensorSpec(key="compressor_kw", label="Compressor power", unit="kW", provenance="assumed"),
    SensorSpec(key="kwh_cum", label="Energy used", unit="kWh", provenance="assumed"),
]


@router.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/version")
def version() -> dict[str, str]:
    return {"version": VERSION}


@router.get("/provenance", dependencies=[Depends(require_token)])
def provenance() -> dict[str, Any]:
    return {
        "data_sources": [
            {
                "name": "IndPenSim (100 batches)",
                "provenance": "synthetic",
                "note": "Published industrial-scale penicillin fed-batch simulator",
                "url": "http://www.industrialpenicillinsimulation.com/",
            }
        ],
        "sensors": [s.model_dump() for s in SENSORS],
        "constants": [
            {
                "key": c.key,
                "value": c.value,
                "unit": c.unit,
                "provenance": c.provenance,
                "source": c.source,
            }
            for c in load_constants().values()
        ],
    }
