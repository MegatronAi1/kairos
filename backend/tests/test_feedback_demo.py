from __future__ import annotations

import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.api import routes_demo
from app.state import AppState

API = "/api/v1"


def test_feedback_appends_jsonl(client: TestClient, state: AppState, tmp_path: Path) -> None:
    state.settings.var_dir = tmp_path
    body = {"category": "idea", "rating": 5, "message": "Add a shift report", "source": "pager"}
    res = client.post(f"{API}/feedback", json=body)
    assert res.status_code == 201 and res.json()["id"]
    rows = [json.loads(line) for line in (tmp_path / "feedback.jsonl").read_text().splitlines()]
    assert rows[0]["message"] == "Add a shift report" and rows[0]["rating"] == 5


def test_feedback_rejects_empty_message(client: TestClient) -> None:
    assert client.post(f"{API}/feedback", json={"message": ""}).status_code == 422


def test_trigger_fault_raises_alarm(
    client: TestClient, state: AppState, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setitem(routes_demo.FAULTS, "oxygen", (91, 20.0, "test fault"))
    res = client.post(f"{API}/demo/trigger-fault", json={"reactor_id": "R1", "kind": "oxygen"})
    assert res.status_code == 200
    assert res.json()["fault_batch"] == 91
    assert state.engine.reactors["R1"].state == "alarm"  # scripted engines alarm at t >= 5 h
