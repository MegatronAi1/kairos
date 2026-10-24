"""Physically derived signals from online sensors (vectorised, row-wise).

Used by feature engineering (training) and the live inference pipeline, so the
same formulas feed models and the UI. Units and assumptions:

- Aeration `Fg` is labelled L/h in the dataset but its magnitude (20-75 for a
  ~60-100 m3 vessel) matches m3/min (0.3-1 vvm). Treated as m3/min (assumed).
- `pressure_bar` is treated as gauge head pressure; C* scales with absolute
  pressure by Henry's law (assumed). This makes DO % saturation consistent with
  the dataset's DO range (up to ~16.5 mg/L).
- OUR (g/min) and CER (g/h) are dataset values; RQ is molar CER/OUR.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import numpy.typing as npt

from kairos_ml.physics.oxygen_transfer import (
    kla_per_s,
    o2_saturation_mg_l,
    otr_mg_l_h,
    superficial_gas_velocity,
)
from kairos_ml.physics.power import (
    agitator_electrical_kw,
    compressor_kw,
    gassed_power_w,
    geometry_from_volume,
)

Array = npt.NDArray[np.float64]

O2_MOLAR_G = 32.0
CO2_MOLAR_G = 44.0
# Geometry is fixed per vessel: derived once from the nominal working volume.
NOMINAL_VOLUME_M3 = 100.0


@dataclass(frozen=True)
class Derived:
    temp_c: Array
    o2_offgas_pct: Array
    c_star_mg_l: Array
    do_pct_sat: Array
    our_mg_l_h: Array
    cer_mg_l_h: Array
    rq: Array
    agitator_kw: Array
    compressor_kw: Array
    power_kw: Array
    kla_h: Array
    otr_mg_l_h: Array

    def row(self, i: int = -1) -> dict[str, float]:
        return {k: float(np.asarray(v)[i]) for k, v in self.__dict__.items()}


def _arr(x: npt.ArrayLike) -> Array:
    return np.atleast_1d(np.asarray(x, dtype=float))


def compute_derived(
    *,
    temp_k: npt.ArrayLike,
    o2_offgas_frac: npt.ArrayLike,
    do_mgl: npt.ArrayLike,
    pressure_bar: npt.ArrayLike,
    our_gmin: npt.ArrayLike,
    cer_gh: npt.ArrayLike,
    volume_l: npt.ArrayLike,
    rpm: npt.ArrayLike,
    aeration: npt.ArrayLike,
    kla_calibration: float = 1.0,
) -> Derived:
    temp_c = _arr(temp_k) - 273.15
    volume_m3 = _arr(volume_l) / 1000.0
    c_star = o2_saturation_mg_l(temp_c) * (1.0 + _arr(pressure_bar)) / 1.01325
    do_pct = 100.0 * _arr(do_mgl) / c_star

    our_g_h = _arr(our_gmin) * 60.0
    cer_g_h = _arr(cer_gh)
    our_mg_l_h = our_g_h * 1000.0 / _arr(volume_l)
    cer_mg_l_h = cer_g_h * 1000.0 / _arr(volume_l)
    with np.errstate(divide="ignore", invalid="ignore"):
        rq = np.where(our_g_h > 1e-6, (cer_g_h / CO2_MOLAR_G) / (our_g_h / O2_MOLAR_G), np.nan)

    geom = geometry_from_volume(NOMINAL_VOLUME_M3)
    air_m3_min = _arr(aeration)
    agit_kw = _arr(agitator_electrical_kw(_arr(rpm), geom.impeller_diameter_m))
    comp_kw = _arr(compressor_kw(air_m3_min))
    pg_w = _arr(gassed_power_w(_arr(rpm), geom.impeller_diameter_m))
    vs = superficial_gas_velocity(air_m3_min / 60.0, geom.cross_section_m2)
    kla_s = _arr(kla_per_s(pg_w, volume_m3, vs, kla_calibration))
    otr = _arr(otr_mg_l_h(kla_s, c_star, _arr(do_mgl)))

    return Derived(
        temp_c=temp_c,
        o2_offgas_pct=100.0 * _arr(o2_offgas_frac),
        c_star_mg_l=c_star,
        do_pct_sat=do_pct,
        our_mg_l_h=our_mg_l_h,
        cer_mg_l_h=cer_mg_l_h,
        rq=rq,
        agitator_kw=agit_kw,
        compressor_kw=comp_kw,
        power_kw=agit_kw + comp_kw,
        kla_h=kla_s * 3600.0,
        otr_mg_l_h=otr,
    )
