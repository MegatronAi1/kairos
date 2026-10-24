from __future__ import annotations

from datetime import date

import pytest
from fastapi.testclient import TestClient

from app.api import routes_impact
from app.impact import LIVE_INDEX, build_impact, month_labels
from app.main import API_PREFIX
from app.replay.scenarios import DEMO_TENANT
from app.state import AppState


@pytest.fixture
def impact_client(client: TestClient) -> TestClient:
    client.app.include_router(routes_impact.router, prefix=API_PREFIX)  # type: ignore[attr-defined]
    return client


def test_months_end_last_month() -> None:
    months = month_labels(date(2026, 10, 24))
    assert len(months) == 24
    assert months[0] == "2024-10" and months[-1] == "2026-09"


def test_impact_series(impact_client: TestClient) -> None:
    data = impact_client.get(f"{API_PREFIX}/impact").json()
    assert len(data["series"]) == 24
    assert data["totals"]["money_saved_inr"] > 0
    assert data["totals"]["energy_saved_kwh"] > 0
    assert data["totals"]["feedstock_saved_kg"] > 0
    for row in data["series"][:LIVE_INDEX]:
        assert row["money_saved_inr"] == 0
        assert row["energy_saved_kwh"] == 0
        assert row["failed_actual"] == row["failed_before_baseline"]
    assert data["kairos_live_from"] == data["series"][LIVE_INDEX]["period"]
    assert {p["plant_id"] for p in data["by_plant"]} == {p.id for p in DEMO_TENANT.plants}


def test_aggregation_consistent(state: AppState) -> None:
    month = build_impact(state.tenant, state.settings.artifacts_dir, "month")
    for period in ("quarter", "year"):
        agg = build_impact(state.tenant, state.settings.artifacts_dir, period)  # type: ignore[arg-type]
        for key in ("batches", "batches_rescued", "money_saved_inr", "energy_saved_kwh"):
            assert sum(r[key] for r in agg["series"]) == pytest.approx(
                sum(r[key] for r in month["series"]), rel=1e-6
            )


def test_plant_filter(impact_client: TestClient) -> None:
    pune = impact_client.get(f"{API_PREFIX}/impact", params={"plant": "pune"}).json()
    fleet = impact_client.get(f"{API_PREFIX}/impact").json()
    assert 0 < pune["totals"]["money_saved_inr"] < fleet["totals"]["money_saved_inr"]
    assert impact_client.get(f"{API_PREFIX}/impact", params={"plant": "nowhere"}).status_code == 404


def test_exports(impact_client: TestClient) -> None:
    x = impact_client.get(f"{API_PREFIX}/impact/export.xlsx", params={"period": "quarter"})
    assert x.status_code == 200 and x.content[:2] == b"PK"
    assert "attachment" in x.headers["content-disposition"]
    p = impact_client.get(f"{API_PREFIX}/impact/export.pdf", params={"period": "year"})
    assert p.status_code == 200 and p.content[:4] == b"%PDF"
