"""Canonical column schema for IndPenSim, frozen from the actual CSV header.

Keys are short snake_case names used everywhere downstream (features, API, UI).
Each entry: raw header label (after the PAT_ref comma fix), unit, kind, provenance.
See docs/DATA_PROFILE.md for the profile this was frozen from.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

Kind = Literal["time", "manipulated", "online", "offline", "label", "meta"]


@dataclass(frozen=True)
class Column:
    key: str
    raw: str
    unit: str
    kind: Kind
    description: str


# Order matches the raw CSV (first 37 columns; the remaining 2200 are Raman).
COLUMNS: tuple[Column, ...] = (
    Column("time_h", "Time (h)", "h", "time", "Time since inoculation"),
    Column("aeration_lph", "Aeration rate(Fg:L/h)", "L/h", "manipulated", "Aeration rate Fg"),
    Column("rpm", "Agitator RPM(RPM:RPM)", "rpm", "manipulated", "Agitator speed"),
    Column("feed_lph", "Sugar feed rate(Fs:L/h)", "L/h", "manipulated", "Sugar feed rate Fs"),
    Column("acid_lph", "Acid flow rate(Fa:L/h)", "L/h", "manipulated", "Acid flow Fa"),
    Column("base_lph", "Base flow rate(Fb:L/h)", "L/h", "manipulated", "Base flow Fb"),
    Column("cooling_lph", "Heating/cooling water flow rate(Fc:L/h)", "L/h", "manipulated", "Cooling water flow Fc"),
    Column("heating_lph", "Heating water flow rate(Fh:L/h)", "L/h", "manipulated", "Heating water flow Fh"),
    Column("water_lph", "Water for injection/dilution(Fw:L/h)", "L/h", "manipulated", "Water for injection Fw"),
    Column("pressure_bar", "Air head pressure(pressure:bar)", "bar", "manipulated", "Head-space pressure"),
    Column("dumped_lph", "Dumped broth flow(Fremoved:L/h)", "L/h", "manipulated", "Broth removed (negative)"),
    Column("substrate_gl", "Substrate concentration(S:g/L)", "g/L", "online", "Substrate (simulated online)"),
    Column("do_mgl", "Dissolved oxygen concentration(DO2:mg/L)", "mg/L", "online", "Dissolved oxygen"),
    Column("penicillin_gl", "Penicillin concentration(P:g/L)", "g/L", "online", "Penicillin (simulator state)"),
    Column("volume_l", "Vessel Volume(V:L)", "L", "online", "Broth volume"),
    Column("weight_kg", "Vessel Weight(Wt:Kg)", "kg", "online", "Vessel weight"),
    Column("ph", "pH(pH:pH)", "pH", "online", "pH"),
    Column("temp_k", "Temperature(T:K)", "K", "online", "Broth temperature"),
    Column("heat_kj", "Generated heat(Q:kJ)", "kJ", "online", "Generated heat"),
    Column("co2_offgas_pct", "carbon dioxide percent in off-gas(CO2outgas:%)", "%", "online", "CO2 in off-gas"),
    Column("paa_lph", "PAA flow(Fpaa:PAA flow (L/h))", "L/h", "manipulated", "Precursor (PAA) flow"),
    Column("paa_offline", "PAA concentration offline(PAA_offline:PAA (g L^{-1}))", "g/L", "offline", "PAA (lab)"),
    Column("oil_lph", "Oil flow(Foil:L/hr)", "L/h", "manipulated", "Oil flow"),
    Column("nh3_offline", "NH_3 concentration off-line(NH3_offline:NH3 (g L^{-1}))", "g/L", "offline", "NH3 (lab)"),
    Column("our_gmin", "Oxygen Uptake Rate(OUR:(g min^{-1}))", "g/min", "online", "Oxygen uptake rate"),
    Column("o2_offgas_frac", "Oxygen in percent in off-gas(O2:O2  (%))", "fraction", "online", "O2 in off-gas (0.13-0.23: a fraction despite the label)"),
    Column("penicillin_offline", "Offline Penicillin concentration(P_offline:P(g L^{-1}))", "g/L", "offline", "Penicillin (lab)"),
    Column("biomass_offline", "Offline Biomass concentratio(X_offline:X(g L^{-1}))", "g/L", "offline", "Biomass (lab)"),
    Column("cer_gh", "Carbon evolution rate(CER:g/h)", "g/h", "online", "CO2 evolution rate"),
    Column("nh3_shots_kg", "Ammonia shots(NH3_shots:kgs)", "kg", "manipulated", "Ammonia shots"),
    Column("viscosity_offline", "Viscosity(Viscosity_offline:centPoise)", "cP", "offline", "Viscosity (lab)"),
    Column("fault_ref", "Fault reference(Fault_ref:Fault ref)", "-", "label", "1 if batch is a fault batch"),
    Column("control_ref", "0 - Recipe driven 1 - Operator controlled(Control_ref:Control ref)", "-", "meta", "0 recipe, 1 operator"),
    Column("pat_ref", "1- No Raman spec, 1-Raman spec recorded, 2-PAT control(PAT_ref:PAT ref)", "-", "meta", "1 no PAT, 2 Raman PAT control"),
    Column("batch_ref", "Batch reference(Batch_ref:Batch ref)", "-", "meta", "Batch number 1..100"),
    Column("batch_id", "Batch ID", "-", "meta", "Batch number 1..100"),
    Column("fault_flag", "Fault flag", "-", "label", "Per-row fault flag"),
)

KEYS: tuple[str, ...] = tuple(c.key for c in COLUMNS)
BY_KEY: dict[str, Column] = {c.key: c for c in COLUMNS}
N_PROCESS = len(COLUMNS)
