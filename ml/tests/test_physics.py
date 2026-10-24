import math

import pytest

from kairos_ml.constants import load_constants
from kairos_ml.physics.oxygen_transfer import kla_per_s, o2_saturation_mg_l, otr_mg_l_h
from kairos_ml.physics.power import geometry_from_volume, ungassed_power_w


def test_every_constant_has_provenance() -> None:
    for c in load_constants().values():
        assert c.provenance in {"measured", "published", "assumed", "synthetic", "fitted"}
        assert c.source


def test_ungassed_power_known_value() -> None:
    # Np=5, rho=1030, N=2 rev/s, D=1 m -> 5*1030*8*1 = 41200 W
    assert float(ungassed_power_w(120.0, 1.0)) == pytest.approx(41_200.0)


def test_power_scales_with_cube_of_speed() -> None:
    assert float(ungassed_power_w(200.0, 0.5)) / float(ungassed_power_w(100.0, 0.5)) == pytest.approx(8.0)


def test_geometry_round_trip() -> None:
    g = geometry_from_volume(100.0)
    height = 2.5 * g.tank_diameter_m
    assert math.pi * g.tank_diameter_m**2 / 4 * height == pytest.approx(100.0)
    assert g.impeller_diameter_m == pytest.approx(0.33 * g.tank_diameter_m)


def test_kla_van_t_riet_known_value() -> None:
    # Pg/V = 1000 W/m3, vs = 0.01 m/s -> 0.026 * 1000^0.4 * 0.1 = 0.0410
    assert float(kla_per_s(1000.0, 1.0, 0.01)) == pytest.approx(0.026 * 1000**0.4 * 0.1)


def test_o2_saturation_25c() -> None:
    assert float(o2_saturation_mg_l(25.0)) == pytest.approx(8.26, abs=0.1)


def test_otr_zero_at_saturation() -> None:
    assert float(otr_mg_l_h(0.05, 8.0, 8.0)) == 0.0
