"""The mobile fixtures must validate against the backend wire schemas (both directions of the contract)."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.schemas import AckEvent, AlarmEvent, InsightEvent, ReactorSummary, TickEvent

FIXTURES = Path(__file__).resolve().parents[2] / "mobile" / "test" / "fixtures"


@pytest.mark.parametrize(
    ("name", "model"),
    [
        ("tick.json", TickEvent),
        ("alarm.json", AlarmEvent),
        ("insight.json", InsightEvent),
        ("ack.json", AckEvent),
        ("reactor_summary.json", ReactorSummary),
    ],
)
def test_fixture_matches_schema(name: str, model: type) -> None:
    raw = json.loads((FIXTURES / name).read_text(encoding="utf-8"))
    parsed = model.model_validate(raw)
    # Round trip: every field the backend emits is present in the fixture.
    assert set(parsed.model_dump()) <= set(raw)
