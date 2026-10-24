"""Demo scenarios: which batch replays on which reactor slot.

All slots replay held-out test batches (never used for training or tuning).
R2 is batch 99: an aeration fault at 20 h that starves the broth of oxygen; the
detector alarms at 22 h and the batch ends at ~25% of typical yield.
"""

from __future__ import annotations

SCENARIOS: dict[str, dict[str, int]] = {
    # R1 healthy recipe batch, R2 fault batch, R3 operator-controlled, R4 PAT-controlled.
    "investor_demo": {"R1": 26, "R2": 99, "R3": 49, "R4": 85},
    "single_fault": {"R1": 91},
}


def get_scenario(name: str) -> dict[str, int]:
    if name not in SCENARIOS:
        raise KeyError(f"Unknown scenario {name!r}; options: {sorted(SCENARIOS)}")
    return SCENARIOS[name]
