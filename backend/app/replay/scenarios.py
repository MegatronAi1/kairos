"""Demo scenarios: which batch replays on which reactor slot.

Batch choices are provisional until the fault detector is evaluated; R2 should
be the fault batch with the clearest early detection (see docs/DECISIONS.md).
"""

from __future__ import annotations

SCENARIOS: dict[str, dict[str, int]] = {
    # R1 healthy recipe batch, R2 fault batch, R3 operator-controlled, R4 PAT-controlled.
    "investor_demo": {"R1": 22, "R2": 91, "R3": 46, "R4": 74},
    "single_fault": {"R1": 91},
}


def get_scenario(name: str) -> dict[str, int]:
    if name not in SCENARIOS:
        raise KeyError(f"Unknown scenario {name!r}; options: {sorted(SCENARIOS)}")
    return SCENARIOS[name]
