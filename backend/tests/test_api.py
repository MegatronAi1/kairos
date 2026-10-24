from __future__ import annotations

from fastapi.testclient import TestClient

from app.state import AppState

API = "/api/v1"


def test_healthz(client: TestClient) -> None:
    assert client.get(f"{API}/healthz").json() == {"status": "ok"}


def test_list_reactors(client: TestClient) -> None:
    ids = [r["id"] for r in client.get(f"{API}/reactors").json()]
    assert ids == ["R1", "R2"]


def test_unknown_reactor_404(client: TestClient) -> None:
    assert client.get(f"{API}/reactors/R9").status_code == 404


def test_control_and_ack(client: TestClient) -> None:
    res = client.post(f"{API}/reactors/R1/control", json={"action": "pause"})
    assert res.status_code == 200 and res.json()["running"] is False
    res = client.post(f"{API}/reactors/R1/ack", json={"by": "phone"})
    assert res.json()["type"] == "ack"


def test_trajectory_downsampled(client: TestClient) -> None:
    body = client.get(
        f"{API}/batches/1/trajectory", params={"keys": ["do_pct"], "every": 10}
    ).json()
    assert len(body["t_h"]) == len(body["series"]["do_pct"]) == 10


def test_token_required_when_configured(client: TestClient, state: AppState) -> None:
    state.settings.api_token = "secret"
    assert client.get(f"{API}/reactors").status_code == 401
    ok = client.get(f"{API}/reactors", headers={"Authorization": "Bearer secret"})
    assert ok.status_code == 200


def test_ws_snapshot_then_alarm(client: TestClient, state: AppState) -> None:
    with client.websocket_connect("/ws") as ws:
        ws.send_json({"type": "subscribe", "reactors": ["R2"]})
        assert ws.receive_json()["type"] == "snapshot"
        r = state.engine.reactors["R2"]

        async def drive() -> None:
            for _ in range(12):
                await state.engine.step(r, 0.5)

        client.portal.call(drive)  # type: ignore[union-attr]
        seen = set()
        for _ in range(60):
            msg = ws.receive_json()
            assert msg["reactor_id"] == "R2"
            seen.add(msg["type"])
            if {"alarm", "insight"} <= seen:
                break
        assert {"tick", "alarm", "insight"} <= seen
