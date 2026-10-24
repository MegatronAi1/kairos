"""Demo tenant, plants and which held-out batch replays in which reactor.

The tenant is fictional (no real brand is impersonated). Every reactor replays a
held-out IndPenSim test batch, so all numbers on screen are real model outputs on
data the models never saw. Each plant is configured for one alternative-protein
process from the Process Library (backend/app/processes/catalog.yaml).

Only the demo plant (Pune) carries a fault batch, so the story on the map is
clear: one plant needs attention. Other plants start part-way through their
batches so the fleet looks like a running operation, not a synchronised replay.
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class Plant:
    id: str
    code: str  # reactor id prefix
    name: str
    city: str
    country: str
    lat: float
    lon: float
    process_id: str
    slots: dict[str, int]  # short reactor name -> held-out batch id
    start_h: float = 0.0
    commissioned: str = ""

    def reactor_id(self, short: str) -> str:
        return f"{self.code}-{short}"


@dataclass(frozen=True)
class Tenant:
    id: str
    name: str
    tagline: str
    plants: list[Plant] = field(default_factory=list)


DEMO_TENANT = Tenant(
    id="aurora",
    name="Aurora Bioproteins",
    tagline="Fictional demo company running alternative-protein fermentation plants",
    plants=[
        Plant(
            id="pune",
            code="PUN",
            name="Pune Mycoprotein Works",
            city="Pune",
            country="India",
            lat=18.52,
            lon=73.86,
            process_id="mycoprotein",
            # R2 replays batch 99: an aeration fault at 20 h, caught at 22 h.
            slots={"R1": 26, "R2": 99, "R3": 49, "R4": 85},
            commissioned="2025",
        ),
        Plant(
            id="bengaluru",
            code="BLR",
            name="Bengaluru Precision Dairy",
            city="Bengaluru",
            country="India",
            lat=12.97,
            lon=77.59,
            process_id="whey",
            slots={"R1": 65, "R2": 70, "R3": 73, "R4": 27},
            start_h=60.0,
            commissioned="2026",
        ),
        Plant(
            id="rotterdam",
            code="RTM",
            name="Rotterdam Egg-Protein Plant",
            city="Rotterdam",
            country="Netherlands",
            lat=51.92,
            lon=4.48,
            process_id="bioalbumen",
            slots={"R1": 38, "R2": 44, "R3": 57, "R4": 4},
            start_h=120.0,
            commissioned="2024",
        ),
        Plant(
            id="singapore",
            code="SIN",
            name="Singapore Functional Proteins",
            city="Singapore",
            country="Singapore",
            lat=1.35,
            lon=103.82,
            process_id="lactoferrin",
            slots={"R1": 68, "R2": 9, "R3": 28, "R4": 45},
            start_h=30.0,
            commissioned="2026",
        ),
    ],
)

TENANTS: dict[str, Tenant] = {"investor_demo": DEMO_TENANT}


def get_tenant(name: str) -> Tenant:
    if name not in TENANTS:
        raise KeyError(f"Unknown scenario {name!r}; options: {sorted(TENANTS)}")
    return TENANTS[name]
