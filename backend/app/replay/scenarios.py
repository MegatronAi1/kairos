"""Demo tenant, plants and which held-out batch replays in which reactor.

The tenant is fictional (no real brand is impersonated). Every reactor replays an
IndPenSim batch the yield model never trained on: test batches, validation batches
(used only for model selection and calibration, all alarm-free) and fault batches
(scored with leave-one-fault-out models). Each plant runs one alternative-protein
process from the Process Library (backend/app/processes/catalog.yaml).

Sites sit in the cities that host Hack the Fork 2026-27 editions (hackthefork.org/
hackathons), so the map reads as a global operation. Three plants carry a fault
batch (Pune: aeration, Sonipat: feed, Nairobi: temperature) at staggered start
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
            slots={"R1": 65, "R2": 70, "R3": 73, "R4": 28},
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
            slots={"R1": 38, "R2": 44, "R3": 57},
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
            slots={"R1": 4, "R2": 9},
            start_h=30.0,
            commissioned="2026",
        ),
        Plant(
            id="sonipat",
            code="SNP",
            name="Sonipat Yeast Protein Hub",
            city="Sonipat",
            country="India",
            lat=28.93,
            lon=77.09,
            process_id="yeast_protein",
            # R1 replays batch 95: a feed fault at 20 h.
            slots={"R1": 95, "R2": 19, "R3": 20},
            start_h=130.0,
            commissioned="2026",
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
            slots={"R1": 22, "R2": 24},
            start_h=90.0,
            commissioned="2025",
        ),
        Plant(
            id="wageningen",
            code="WAG",
            name="Wageningen Algae Biorefinery",
            city="Wageningen",
            country="Netherlands",
            lat=51.97,
            lon=5.67,
            process_id="microalgae",
            slots={"R1": 29, "R2": 36},
            start_h=170.0,
            commissioned="2025",
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
            start_h=20.0,
            commissioned="2026",
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
            id="accra",
            code="ACC",
            name="Accra Mycoprotein Kitchen",
            city="Accra",
            country="Ghana",
            lat=5.60,
            lon=-0.19,
            process_id="mycoprotein",
            slots={"R1": 60},
            start_h=75.0,
            commissioned="2026",
        ),
        Plant(
            id="manila",
            code="MNL",
            name="Manila Microalgae Farm",
            city="Manila",
            country="Philippines",
            lat=14.60,
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
            id="ithaca",
            code="ITH",
            name="Ithaca Dairy Proteins",
            city="Ithaca",
            country="USA",
            lat=42.44,
            lon=-76.50,
            process_id="whey",
            slots={"R1": 79, "R2": 81},
            start_h=110.0,
            commissioned="2025",
        ),
        Plant(
            id="chicago",
            code="CHI",
            name="Chicago Fermentation Center",
            city="Chicago",
            country="USA",
            lat=41.88,
            lon=-87.63,
            process_id="mycoprotein",
            slots={"R1": 4, "R2": 26, "R3": 70},
            start_h=180.0,
            commissioned="2024",
        ),
        Plant(
            id="davis",
            code="DAV",
            name="Davis Egg-Protein Works",
            city="Davis",
            country="USA",
            lat=38.54,
            lon=-121.74,
            process_id="bioalbumen",
            slots={"R1": 49, "R2": 85},
            start_h=100.0,
            commissioned="2026",
        ),
    ],
)

TENANTS: dict[str, Tenant] = {"investor_demo": DEMO_TENANT}


def get_tenant(name: str) -> Tenant:
    if name not in TENANTS:
        raise KeyError(f"Unknown scenario {name!r}; options: {sorted(TENANTS)}")
    return TENANTS[name]
