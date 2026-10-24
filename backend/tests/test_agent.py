"""Agent tests with a fake Bedrock client (no network)."""

from __future__ import annotations

import json
from collections.abc import AsyncIterator
from pathlib import Path
from typing import Any

from app.agent.bedrock import LlmUnavailable
from app.agent.service import AgentService
from app.agent.tools import SPECS, ToolBox, bedrock_tool_config
from app.schemas import AlarmEvent, Contribution
from app.state import AppState


class FakeClient:
    """Round 1: request a tool. Round 2: stream text. Cards: forced tool output."""

    def __init__(self, fail: bool = False) -> None:
        self.fail = fail
        self.calls: list[dict[str, Any]] = []

    async def converse(self, **kwargs: Any) -> dict[str, Any]:
        self.calls.append(kwargs)
        if self.fail:
            raise LlmUnavailable("ThrottlingException")
        card = {
            "title": "Oxygen transfer dropping",
            "summary": "Off-gas O2 low, CO2 high.",
            "action": "Restore airflow to recipe.",
            "expected_effect": "Not yet quantified",
            "confidence": "medium",
        }
        return {
            "output": {
                "message": {
                    "content": [
                        {"toolUse": {"toolUseId": "t1", "name": "alarm_card", "input": card}}
                    ]
                }
            }
        }

    async def converse_stream(self, **kwargs: Any) -> AsyncIterator[dict[str, Any]]:
        self.calls.append(kwargs)
        if self.fail:
            raise LlmUnavailable("ExpiredTokenException")
        if len(self.calls) == 1:
            yield {
                "contentBlockStart": {
                    "contentBlockIndex": 0,
                    "start": {"toolUse": {"toolUseId": "u1", "name": "get_model_evidence"}},
                }
            }
            yield {
                "contentBlockDelta": {"contentBlockIndex": 0, "delta": {"toolUse": {"input": "{}"}}}
            }
            yield {"messageStop": {"stopReason": "tool_use"}}
        else:
            for part in ("R2 is ", "drifting."):
                yield {"contentBlockDelta": {"contentBlockIndex": 0, "delta": {"text": part}}}
            yield {"messageStop": {"stopReason": "end_turn"}}


def _agent(state: AppState, client: Any, tmp_path: Path) -> AgentService:
    (tmp_path / "yield.json").write_text(json.dumps({}), encoding="utf-8")
    return AgentService(client, ToolBox(state, tmp_path), "chat-model", "fast-model")


def _alarm() -> AlarmEvent:
    return AlarmEvent(
        reactor_id="R2",
        ts=0,
        t_h=22,
        progress=0.1,
        batch_id=91,
        state="alarm",
        previous_state="normal",
        severity="critical",
        contributors=[Contribution(var="o2_offgas_pct", pct=50, dir="low")],
    )


async def test_chat_runs_tool_round_then_streams_text(state: AppState, tmp_path: Path) -> None:
    client = FakeClient()
    agent = _agent(state, client, tmp_path)
    events = [e async for e in agent.chat([{"role": "user", "content": "how good are you?"}])]
    kinds = [e["type"] for e in events]
    assert kinds == ["tool", "text", "text", "evidence", "done"]
    assert "evaluation" in events[-2]["items"]
    # The tool result is sent back to the model in round 2.
    results = [
        c["toolResult"]
        for m in client.calls[1]["messages"]
        for c in m["content"]
        if "toolResult" in c
    ]
    assert results and results[0]["toolUseId"] == "u1"


async def test_chat_reports_error_when_bedrock_down(state: AppState, tmp_path: Path) -> None:
    agent = _agent(state, FakeClient(fail=True), tmp_path)
    events = [e async for e in agent.chat([{"role": "user", "content": "hi"}])]
    assert events[-1]["type"] == "error"


async def test_alarm_card_is_structured_and_cached(state: AppState, tmp_path: Path) -> None:
    client = FakeClient()
    agent = _agent(state, client, tmp_path)
    card = await agent.alarm_card(_alarm())
    assert card is not None and card.title == "Oxygen transfer dropping"
    again = await agent.alarm_card(_alarm())
    assert again is card and len(client.calls) == 1  # cache hit, no second Bedrock call
    assert client.calls[0]["toolConfig"]["toolChoice"] == {"tool": {"name": "alarm_card"}}


async def test_alarm_card_falls_back_to_none(state: AppState, tmp_path: Path) -> None:
    agent = _agent(state, FakeClient(fail=True), tmp_path)
    assert await agent.alarm_card(_alarm()) is None


def test_tool_specs_valid_and_dispatch_handles_unknowns(state: AppState, tmp_path: Path) -> None:
    cfg = bedrock_tool_config()
    assert len(cfg["tools"]) == len(SPECS) == 10
    box = ToolBox(state, tmp_path)
    assert "error" in box.call("nope", {})
    assert "error" in box.call("get_reactor_state", {"reactor_id": "R9"})
    assert box.call("get_reactor_state", {"reactor_id": "R1"})["status"] == "no data yet"
    assert box.call("recommend_settings", {"reactor_id": "R1"})["available"] is False
