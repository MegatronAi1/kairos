import pandas as pd

from kairos_ml.engines.energy import EnergyEngine, kla_h, power_kw


def _row(do: float = 70.0, rpm: float = 100.0, aer: float = 60.0) -> pd.Series:
    return pd.Series(
        {"rpm": rpm, "aeration_lph": aer, "volume_l": 80000.0, "do_pct_sat": do, "time_h": 50.0}
    )


def test_more_transfer_costs_more_power() -> None:
    assert float(power_kw([110], [60])[0]) > float(power_kw([100], [60])[0])
    assert float(kla_h([100], [70], [80000])[0]) > float(kla_h([100], [50], [80000])[0])


def test_counterfactual_do_falls_with_less_transfer() -> None:
    row = _row(do=70.0)
    same = EnergyEngine.predict_do(row, [100.0], [60.0])[0]
    less = EnergyEngine.predict_do(row, [100.0], [40.0])[0]
    assert abs(same - 70.0) < 1e-6
    assert less < same


def test_energy_mode_saves_power_and_respects_target() -> None:
    eng = EnergyEngine()
    rec = eng.recommend(_row(do=80.0))
    assert rec.best.power_kw <= rec.current.power_kw
    assert rec.best.do_pct >= eng.target_do
    assert rec.best.aeration >= 0.7 * 60.0 - 1e-9  # step limit


def test_rescue_never_reduces_transfer() -> None:
    eng = EnergyEngine()
    row = _row(do=20.0, aer=40.0)
    rec = eng.recommend(row, mode="rescue")
    k_now = kla_h([row["rpm"]], [row["aeration_lph"]], [row["volume_l"]])[0]
    k_new = kla_h([rec.best.rpm], [rec.best.aeration], [row["volume_l"]])[0]
    assert k_new >= k_now
    assert rec.best.do_pct > 20.0
