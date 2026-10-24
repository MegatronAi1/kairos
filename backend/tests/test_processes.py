from __future__ import annotations

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.processes import catalog

API = "/api/v1"

YAML = """
notes: ["typical ranges"]
processes:
  - id: whey
    family: precision
    name: Whey protein
    product: Beta-lactoglobulin
    example: {company: Example Co}
    organism: Trichoderma reesei
    reactor: stirred_tank
    mode: fed_batch
    setpoints:
      temp_c: {min: 28, max: 30, provenance: published, source: "https://example.org"}
    critical_risks: ["Contamination"]
    energy_hotspots: ["Cooling"]
    kairos: {benchmark_fit: high, benchmark_fit_why: "Aerobic fungal fed-batch"}
"""


@pytest.fixture
def fake_catalog(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    path = tmp_path / "catalog.yaml"
    path.write_text(YAML, encoding="utf-8")
    monkeypatch.setattr(catalog, "CATALOG_PATH", path)


def test_list_and_detail(client: TestClient, fake_catalog: None) -> None:
    body = client.get(f"{API}/processes").json()
    assert body["processes"][0]["id"] == "whey"
    assert body["processes"][0]["benchmark_fit"] == "high"
    detail = client.get(f"{API}/processes/whey").json()
    assert detail["setpoints"]["temp_c"]["provenance"] == "published"
    assert client.get(f"{API}/processes/nope").status_code == 404


def test_summary_mentions_benchmark(fake_catalog: None) -> None:
    p = catalog.get_process("whey")
    assert p is not None
    text = catalog.summary(p)
    assert "Trichoderma reesei" in text and "temp_c 28-30 (published)" in text
