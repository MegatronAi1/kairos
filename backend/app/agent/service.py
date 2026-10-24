"""Claude agent on Bedrock (spec section 8).

- Chat: Converse stream with tool use; up to MAX_ROUNDS tool rounds; yields
  text deltas, tool calls and evidence chips.
- Alarm cards: one Converse call on the fast model, facts gathered by the tools
  beforehand, output forced through the `alarm_card` tool for structure. Cached
  per (batch, state, contributor set). Falls back to the template card.
"""

from __future__ import annotations

import json
from collections.abc import AsyncIterator
from pathlib import Path
from typing import Any

from app.agent.bedrock import ConverseClient, LlmUnavailable
from app.agent.templates import template_card
from app.agent.tools import EVIDENCE, ToolBox, bedrock_tool_config
from app.core.logging import log
from app.processes.catalog import get_process, summary
from app.schemas import AlarmEvent, InsightCard

PROMPT_PATH = Path(__file__).parent / "prompts" / "system.md"
MAX_ROUNDS = 5
Json = dict[str, Any]

CARD_TOOL: Json = {
    "toolSpec": {
        "name": "alarm_card",
        "description": "Return the operator alarm card.",
        "inputSchema": {
            "json": {
                "type": "object",
                "properties": {
                    "title": {
                        "type": "string",
                        "description": "Plain-language problem, under 6 words, sentence case",
                    },
                    "summary": {
                        "type": "string",
                        "description": "What is happening and why, under 40 words, numbers only from the facts",
                    },
                    "action": {
                        "type": "string",
                        "description": "One concrete operator action, under 14 words",
                    },
                    "expected_effect": {
                        "type": "string",
                        "description": "Expected effect with range from the facts, or 'Not yet quantified'",
                    },
                    "confidence": {"type": "string", "enum": ["low", "medium", "high"]},
                },
                "required": ["title", "summary", "action", "expected_effect", "confidence"],
            }
        },
    }
}


class AgentService:
    def __init__(
        self, client: ConverseClient | None, tools: ToolBox, model_chat: str, model_fast: str
    ) -> None:
        self.client = client
        self.tools = tools
        self.model_chat = model_chat
        self.model_fast = model_fast
        self.system = PROMPT_PATH.read_text(encoding="utf-8")
        self._card_cache: dict[tuple[int, str, tuple[str, ...]], InsightCard] = {}

    @property
    def enabled(self) -> bool:
        return self.client is not None and bool(self.model_chat)

    # --- alarm cards -----------------------------------------------------------
    async def alarm_card(self, alarm: AlarmEvent) -> InsightCard | None:
        """Agent-written card, or None when the LLM is unavailable (caller keeps the template)."""
        if self.client is None or not self.model_fast or alarm.state == "normal":
            return None
        key = (alarm.batch_id, alarm.state, tuple(sorted(c.var for c in alarm.contributors[:3])))
        if key in self._card_cache:
            return self._card_cache[key]
        facts = {
            "alarm": {"reactor": alarm.reactor_id, "state": alarm.state, "batch_time_h": alarm.t_h},
            "diagnosis": self.tools.call("diagnose_alarm", {"reactor_id": alarm.reactor_id}),
            "forecast": self.tools.call("predict_final_yield", {"reactor_id": alarm.reactor_id}),
            "rescue_setpoints": self.tools.call(
                "recommend_settings", {"reactor_id": alarm.reactor_id, "mode": "rescue"}
            ),
            "rule_based_card": template_card(alarm).model_dump(),
        }
        prompt = (
            "Write the alarm card for the operator's phone from these facts only. "
            "Use only numbers present in the facts. Under 90 words in total. Lead with the action. "
            "Recommend a concrete check or setpoint correction consistent with the deviating variables; "
            "the operator must verify before applying.\n\nFACTS:\n" + json.dumps(facts, default=str)
        )
        try:
            res = await self.client.converse(
                modelId=self.model_fast,
                system=[{"text": self.system}],
                messages=[{"role": "user", "content": [{"text": prompt}]}],
                toolConfig={"tools": [CARD_TOOL], "toolChoice": {"tool": {"name": "alarm_card"}}},
                inferenceConfig={"maxTokens": 500, "temperature": 0.2},
            )
        except LlmUnavailable:
            return None
        for block in res.get("output", {}).get("message", {}).get("content", []):
            if "toolUse" in block:
                data = block["toolUse"]["input"]
                fallback = template_card(alarm)
                fields = {
                    k: str(data.get(k) or getattr(fallback, k))
                    for k in ("title", "summary", "action", "expected_effect")
                }
                conf = data.get("confidence")
                card = InsightCard(
                    **fields,
                    confidence=conf if conf in ("low", "medium", "high") else "medium",
                    ponr_hours=alarm.ponr_hours,
                    evidence=["fault_detector", "yield_model", "energy_model"],
                )
                self._card_cache[key] = card
                return card
        log.warning("alarm_card_no_tool_use")
        return None

    # --- chat ------------------------------------------------------------------
    async def chat(
        self, messages: list[Json], reactor_id: str | None = None, process_id: str | None = None
    ) -> AsyncIterator[Json]:
        """Yields {"type": "text"|"tool"|"evidence"|"done"|"error", ...}."""
        if not self.enabled or self.client is None:
            yield {
                "type": "error",
                "message": "The Kairos copilot is offline. Live alarms and forecasts still work.",
            }
            return
        convo = [
            {"role": m["role"], "content": [{"text": m["content"]}]}
            for m in messages
            if m.get("content")
        ]
        system = self.system
        if reactor_id:
            # Preload a live snapshot so most questions need no tool round trip.
            snapshot = {
                "state": self.tools.call("get_reactor_state", {"reactor_id": reactor_id}),
                "diagnosis": self.tools.call("diagnose_alarm", {"reactor_id": reactor_id}),
                "forecast": self.tools.call("predict_final_yield", {"reactor_id": reactor_id}),
            }
            system += (
                f"\n\nThe operator is looking at reactor {reactor_id}. Live snapshot (counts as "
                "tool results; call tools only for anything not covered here):\n"
                + json.dumps(snapshot, default=str)
            )
        process = get_process(process_id) if process_id else None
        if process:
            system += (
                "\n\nThe operator has selected this alternative-protein process as context: "
                + summary(process)
                + " Live reactor data is the IndPenSim penicillin benchmark; say so when you transfer "
                "conclusions to the selected process, and do not invent process numbers beyond this summary."
            )
        evidence: list[str] = (
            ["live_sensors", "fault_detector", "yield_model"] if reactor_id else []
        )
        try:
            for _ in range(MAX_ROUNDS):
                blocks: dict[int, Json] = {}
                stop = None
                async for ev in self.client.converse_stream(
                    modelId=self.model_chat,
                    system=[{"text": system}],
                    messages=convo,
                    toolConfig=bedrock_tool_config(),
                    inferenceConfig={"maxTokens": 900},  # Sonnet 5 rejects temperature
                ):
                    if "contentBlockStart" in ev:
                        start = ev["contentBlockStart"]
                        tu = start.get("start", {}).get("toolUse")
                        if tu:
                            blocks[start["contentBlockIndex"]] = {
                                "toolUse": {
                                    "toolUseId": tu["toolUseId"],
                                    "name": tu["name"],
                                    "raw": "",
                                }
                            }
                    elif "contentBlockDelta" in ev:
                        d = ev["contentBlockDelta"]
                        i, delta = d["contentBlockIndex"], d["delta"]
                        if "text" in delta:
                            blocks.setdefault(i, {"text": ""})["text"] += delta["text"]
                            yield {"type": "text", "delta": delta["text"]}
                        elif "toolUse" in delta:
                            blocks[i]["toolUse"]["raw"] += delta["toolUse"].get("input", "")
                    elif "messageStop" in ev:
                        stop = ev["messageStop"].get("stopReason")
                content = []
                for i in sorted(blocks):
                    b = blocks[i]
                    if b.get("text"):
                        content.append({"text": b["text"]})
                    elif "toolUse" in b:
                        tu = b["toolUse"]
                        args = json.loads(tu["raw"] or "{}")
                        content.append(
                            {
                                "toolUse": {
                                    "toolUseId": tu["toolUseId"],
                                    "name": tu["name"],
                                    "input": args,
                                }
                            }
                        )
                convo.append({"role": "assistant", "content": content})
                if stop != "tool_use":
                    break
                results = []
                for c in content:
                    if "toolUse" not in c:
                        continue
                    name, args = c["toolUse"]["name"], c["toolUse"]["input"]
                    yield {"type": "tool", "name": name, "input": args}
                    out = self.tools.call(name, args)
                    chip = EVIDENCE.get(name)
                    if chip and chip not in evidence and out.get("available", True):
                        evidence.append(chip)
                    results.append(
                        {
                            "toolResult": {
                                "toolUseId": c["toolUse"]["toolUseId"],
                                "content": [{"json": out}],
                            }
                        }
                    )
                convo.append({"role": "user", "content": results})
            yield {"type": "evidence", "items": evidence}
            yield {"type": "done"}
        except LlmUnavailable as e:
            yield {
                "type": "error",
                "message": f"The copilot could not reach the model ({e}). Live alarms and forecasts still work.",
            }
