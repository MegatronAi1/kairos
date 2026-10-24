"""Deterministic insight cards built only from engine outputs.

Used when Bedrock is unavailable and as the instant first card before the agent
replies, so the product works with the LLM off.
"""

from __future__ import annotations

from app.schemas import AlarmEvent, InsightCard

VAR_LABELS: dict[str, str] = {
    "do_pct": "dissolved oxygen",
    "ph": "pH",
    "temp_c": "temperature",
    "aeration": "aeration",
    "feed": "sugar feed",
    "pressure_bar": "head pressure",
    "co2_offgas_pct": "off-gas CO2",
    "o2_offgas_pct": "off-gas O2",
    "our": "oxygen uptake",
    "cer": "CO2 evolution",
    "base_lph": "base dosing",
    "acid_lph": "acid dosing",
    "cooling_lph": "cooling water",
    "paa_lph": "precursor feed",
    "oil_lph": "oil feed",
    "volume_l": "broth volume",
}


def label(var: str) -> str:
    return VAR_LABELS.get(var, var.replace("_", " "))


def template_card(alarm: AlarmEvent) -> InsightCard:
    top = alarm.contributors[:3]
    if alarm.state == "normal":
        return InsightCard(
            title=f"{alarm.reactor_id} back to normal",
            summary="Health score is back inside normal limits.",
            action="No action needed. Keep monitoring.",
            expected_effect="None",
            confidence="medium",
            evidence=["fault_detector"],
        )
    if top:
        lead = top[0]
        direction = "low" if lead.dir == "low" else "high"
        title = f"{label(lead.var).capitalize()} running {direction}"
        drivers = ", ".join(f"{label(c.var)} {c.dir} ({c.pct:.0f}%)" for c in top)
        summary = f"Deviation from normal batches is driven by {drivers}."
        action = f"Check {label(lead.var)} and its setpoint against the recipe."
    else:
        title = "Batch drifting from normal"
        summary = "Health score dropped below its limit."
        action = "Review recent setpoint changes."
    if alarm.ponr_hours is not None:
        summary += (
            f" About {alarm.ponr_hours:.1f} h before the point of no return (model estimate)."
        )
    return InsightCard(
        title=title,
        summary=summary,
        action=action,
        expected_effect="Not yet quantified",
        confidence="low" if alarm.state == "watch" else "medium",
        ponr_hours=alarm.ponr_hours,
        evidence=["fault_detector"],
    )
