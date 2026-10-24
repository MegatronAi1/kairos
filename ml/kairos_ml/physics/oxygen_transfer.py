"""Oxygen transfer: van't Riet kLa and OTR."""

from __future__ import annotations

import numpy as np

from kairos_ml.constants import const
from kairos_ml.physics.power import ArrayLike


def superficial_gas_velocity(air_m3_per_s: ArrayLike, cross_section_m2: float) -> ArrayLike:
    return np.asarray(air_m3_per_s, dtype=float) / cross_section_m2


def kla_per_s(
    gassed_power_w: ArrayLike,
    volume_m3: ArrayLike,
    vs_m_per_s: ArrayLike,
    calibration: float = 1.0,
) -> ArrayLike:
    """kLa = c * (Pg/V)^0.4 * vs^0.5 (coalescing broth). `calibration` is a fitted multiplier."""
    pv = np.asarray(gassed_power_w, dtype=float) / np.asarray(volume_m3, dtype=float)
    return (
        calibration
        * const("kla_coefficient")
        * np.power(np.clip(pv, 0.0, None), const("kla_power_exponent"))
        * np.power(np.clip(np.asarray(vs_m_per_s, dtype=float), 0.0, None), const("kla_vs_exponent"))
    )


def o2_saturation_mg_l(temp_c: ArrayLike) -> ArrayLike:
    """Air-saturated O2 solubility in water at 1 atm (Benson-Krause style fit, 0-40 C)."""
    t = np.asarray(temp_c, dtype=float)
    return 14.62 - 0.3898 * t + 0.006969 * t**2 - 0.00005897 * t**3


def otr_mg_l_h(kla_s: ArrayLike, c_star_mg_l: ArrayLike, do_mg_l: ArrayLike) -> ArrayLike:
    """OTR = kLa (C* - C), returned in mg O2 / (L h)."""
    return np.asarray(kla_s, dtype=float) * 3600.0 * (
        np.asarray(c_star_mg_l, dtype=float) - np.asarray(do_mg_l, dtype=float)
    )
