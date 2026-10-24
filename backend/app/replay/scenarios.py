"""Demo tenant, plants and which held-out batch replays in which reactor.

The tenant is fictional (no real brand is impersonated). Every reactor replays an
IndPenSim batch the yield model never trained on: test batches, validation batches
(used only for model selection and calibration, all alarm-free) and fault batches
(scored with leave-one-fault-out models). Each plant runs one alternative-protein
process from the Process Library (backend/app/processes/catalog.yaml).

Sites sit in Hack the Fork 2026-27 host cities (hackthefork.org/hackathons), one
per region so the map reads as a global operation. Three plants carry a fault
batch (Pune: aeration, Davis: feed, Nairobi: temperature) at staggered start
times; replays loop, so alarms keep arriving on a live deployment. The three
normal test batches with known false alarms (27, 45, 68) are not placed anywhere.
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
    # Healthy batch replayed between fault cycles, so a looping fault reactor
    # alarms on one batch in `fault_every` (see ReplayEngine), not every batch.
    relief: dict[str, int] = field(default_factory=dict)

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
            relief={"R2": 19},
            start_h=0.0,
            commissioned="2025",
        ),
        Plant(
            id="paris",
            code="PAR",
            name="Paris Collagen Foundry",
            city="Paris",
            country="France",
            lat=48.86,
            lon=2.35,
            process_id="collagen",
            slots={"R1": 22, "R2": 24, "R3": 29},
            start_h=90.0,
            commissioned="2025",
        ),
        Plant(
            id="lagos",
            code="LOS",
            name="Lagos Single-Cell Protein",
            city="Lagos",
            country="Nigeria",
            lat=6.52,
            lon=3.38,
            process_id="yeast_protein",
            slots={"R1": 54, "R2": 58},
            start_h=200.0,
            commissioned="2026",
        ),
        Plant(
            id="nairobi",
            code="NBO",
            name="Nairobi Air-Protein Pilot",
            city="Nairobi",
            country="Kenya",
            lat=-1.29,
            lon=36.82,
            process_id="solein",
            # R1 replays batch 93: a temperature drift from about 70 h.
            slots={"R1": 93, "R2": 52},
            relief={"R1": 20},
            start_h=20.0,
            commissioned="2026",
        ),
        Plant(
            id="manila",
            code="MNL",
            name="Manila Microalgae Farm",
            city="Manila",
            country="Philippines",
            lat=14.6,
            lon=120.98,
            process_id="microalgae",
            slots={"R1": 61, "R2": 38},
            start_h=150.0,
            commissioned="2026",
        ),
        Plant(
            id="providence",
            code="PVD",
            name="Providence Lactoferrin Lab",
            city="Providence",
            country="USA",
            lat=41.82,
            lon=-71.41,
            process_id="lactoferrin",
            slots={"R1": 69, "R2": 75},
            start_h=50.0,
            commissioned="2025",
        ),
        Plant(
            id="davis",
            code="DAV",
            name="Davis Precision Dairy",
            city="Davis",
            country="USA",
            lat=38.54,
            lon=-121.74,
            process_id="whey",
            # R1 replays batch 95: a feed fault at 20 h.
            slots={"R1": 95, "R2": 4, "R3": 70},
            relief={"R1": 36},
            start_h=130.0,
            commissioned="2026",
        ),
    ],
)

TENANTS: dict[str, Tenant] = {"investor_demo": DEMO_TENANT}


def get_tenant(name: str) -> Tenant:
    if name not in TENANTS:
        raise KeyError(f"Unknown scenario {name!r}; options: {sorted(TENANTS)}")
    return TENANTS[name]
