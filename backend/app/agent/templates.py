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
    "heating_lph": "heating water",
    "paa_lph": "precursor feed",
    "oil_lph": "oil feed",
    "volume_l": "broth volume",
}


def label(var: str) -> str:
    return VAR_LABELS.get(var, var.replace("_", " "))


def _sentence_case(text: str) -> str:
    return text[:1].upper() + text[1:]


# Rule-based diagnosis patterns: (variables that must lead, title, action).
PATTERNS: list[tuple[set[str], str, str]] = [
    (
        {"o2_offgas_pct", "co2_offgas_pct", "do_pct", "our", "cer"},
        "Oxygen transfer dropping",
        "Check the air supply and aeration rate against the recipe; restore airflow.",
    ),
    (
        {"temp_c", "cooling_lph", "heating_lph"},
        "Temperature control struggling",
        "Check cooling water supply and the temperature probe.",
    ),
    (
        {"ph", "base_lph", "acid_lph"},
        "pH control drifting",
        "Check pH probe calibration and the base dosing line.",
    ),
]


def _match(vars_: list[str]) -> tuple[str, str] | None:
    lead = set(vars_[:2])
    for group, title, action in PATTERNS:
        if lead and lead <= group:
            return title, action
    return None


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
        drivers = ", ".join(f"{label(c.var)} {c.dir} ({c.pct:.0f}%)" for c in top)
        summary = f"Deviation from normal batches is driven by {drivers}."
        matched = _match([c.var for c in top])
        if matched:
            title, action = matched
        else:
            title = _sentence_case(f"{label(lead.var)} running {lead.dir}")
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
