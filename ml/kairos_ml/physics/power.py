"""Agitation and aeration power. SI units unless the name says otherwise."""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np
import numpy.typing as npt

from kairos_ml.constants import const

ArrayLike = float | npt.NDArray[np.float64]


@dataclass(frozen=True)
class VesselGeometry:
    volume_m3: float
    tank_diameter_m: float
    impeller_diameter_m: float

    @property
    def cross_section_m2(self) -> float:
        return math.pi * self.tank_diameter_m**2 / 4.0


def geometry_from_volume(volume_m3: float) -> VesselGeometry:
    """Derive tank and impeller diameter from working volume (assumed H/T and D/T)."""
    aspect = const("tank_aspect_ratio")
    tank_d = (4.0 * volume_m3 / (math.pi * aspect)) ** (1.0 / 3.0)
    return VesselGeometry(volume_m3, tank_d, const("impeller_to_tank_ratio") * tank_d)


def ungassed_power_w(rpm: ArrayLike, impeller_diameter_m: float) -> ArrayLike:
    """P = Np * rho * N^3 * D^5 with N in rev/s."""
    n = np.asarray(rpm, dtype=float) / 60.0
    return const("impeller_power_number") * const("broth_density") * n**3 * impeller_diameter_m**5


def gassed_power_w(rpm: ArrayLike, impeller_diameter_m: float) -> ArrayLike:
    return const("gassed_power_ratio") * ungassed_power_w(rpm, impeller_diameter_m)


def agitator_electrical_kw(rpm: ArrayLike, impeller_diameter_m: float) -> ArrayLike:
    return gassed_power_w(rpm, impeller_diameter_m) / const("motor_efficiency") / 1000.0


def compressor_kw(air_m3_per_min: ArrayLike) -> ArrayLike:
    return const("compressor_specific_power") * np.asarray(air_m3_per_min, dtype=float)
