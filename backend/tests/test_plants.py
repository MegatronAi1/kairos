from __future__ import annotations

from fastapi.testclient import TestClient

from app.replay.scenarios import DEMO_TENANT, Plant, Tenant
from app.state import AppState

API = "/api/v1"


def _use_tenant(state: AppState) -> None:
    tenant = Tenant(
        id="t",
        name="Test Co",
        tagline="fictional",
        plants=[
            Plant(
                id="a",
                code="A",
                name="Plant A",
                city="X",
                country="Y",
                lat=1,
                lon=2,
                process_id="whey",
                slots={"R1": 1, "R2": 91},
            ),
            Plant(
                id="b",
                code="B",
                name="Plant B",
                city="X",
                country="Y",
                lat=3,
                lon=4,
                process_id="whey",
                slots={"R1": 2},
                start_h=5.0,
            ),
        ],
    )
    state.tenant = tenant
    state.engine.load_tenant(tenant, 1.0)


def test_reactor_ids_are_plant_scoped(state: AppState) -> None:
    _use_tenant(state)
    assert sorted(state.engine.reactors) == ["A-R1", "A-R2", "B-R1"]
    assert state.engine.reactors["B-R1"].t_h == 5.0
    assert state.engine.reactors["A-R2"].summary().plant_id == "a"


async def test_plant_rollup_reports_worst_state(client: TestClient, state: AppState) -> None:
    _use_tenant(state)
    r = state.engine.reactors["A-R2"]
    for _ in range(12):
        await state.engine.step(r, 0.5)
    plants = {p["id"]: p for p in client.get(f"{API}/plants").json()}
    assert plants["a"]["state"] == "alarm" and plants["a"]["alarms_open"] == 1
    assert plants["b"]["state"] == "normal" and plants["b"]["reactors"] == 1
    detail = client.get(f"{API}/plants/a").json()
    assert [s["id"] for s in detail["reactor_summaries"]] == ["A-R1", "A-R2"]
    assert client.get(f"{API}/plants/zzz").status_code == 404


def test_demo_login(client: TestClient) -> None:
    accounts = client.get(f"{API}/auth/demo-accounts").json()
    assert accounts and accounts[0]["email"].endswith("@aurora.demo")
    ok = client.post(
        f"{API}/auth/login",
        json={"email": accounts[0]["email"].upper(), "password": accounts[0]["password"]},
    )
    assert ok.status_code == 200 and ok.json()["user"]["role"]
    bad = client.post(f"{API}/auth/login", json={"email": accounts[0]["email"], "password": "nope"})
    assert bad.status_code == 401


def test_demo_tenant_is_fictional_and_uses_held_out_batches() -> None:
    import json
    from pathlib import Path

    splits = json.loads(
        (Path(__file__).resolve().parents[2] / "ml" / "config" / "splits.json").read_text()
    )
    held_out = set(splits["test_normal"]) | set(splits["test_fault"])
    for plant in DEMO_TENANT.plants:
        assert set(plant.slots.values()) <= held_out, plant.id
