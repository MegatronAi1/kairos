"""Tenant, plants (with live roll-ups for the operations map) and demo sign-in."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.core.security import require_token
from app.processes import catalog
from app.replay.engine import Reactor
from app.replay.scenarios import Plant
from app.state import AppState, get_state

router = APIRouter(tags=["plants"], dependencies=[Depends(require_token)])
auth_router = APIRouter(prefix="/auth", tags=["auth"])

SEVERITY = {"normal": 0, "watch": 1, "alarm": 2}


def _rollup(plant: Plant, reactors: list[Reactor]) -> dict[str, Any]:
    states = [r.state for r in reactors]
    ticks = [r.last_tick for r in reactors if r.last_tick is not None]
    power = sum((t.derived.get("power_kw") or 0.0) for t in ticks)
    kwh = sum((t.derived.get("kwh_cum") or 0.0) for t in ticks)
    vs = [t.forecast.vs_golden_pct for t in ticks if t.forecast is not None]
    process = catalog.get_process(plant.process_id) or {}
    worst = max(states, key=lambda s: SEVERITY[s]) if states else "normal"
    return {
        "id": plant.id,
        "code": plant.code,
        "name": plant.name,
        "city": plant.city,
        "country": plant.country,
        "lat": plant.lat,
        "lon": plant.lon,
        "commissioned": plant.commissioned,
        "process_id": plant.process_id,
        "process_name": process.get("name", plant.process_id),
        "process_family": process.get("family"),
        "reactor_ids": [r.id for r in reactors],
        "reactors": len(reactors),
        "state": worst,
        "alarms_open": sum(1 for r in reactors if r.state == "alarm" and not r.acknowledged),
        "watch": states.count("watch"),
        "power_kw": round(power, 1),
        "energy_kwh": round(kwh, 0),
        "forecast_vs_typical_pct": round(sum(vs) / len(vs), 1) if vs else None,
    }


def _reactors_of(state: AppState, plant: Plant) -> list[Reactor]:
    return [r for r in state.engine.reactors.values() if r.plant_id == plant.id]


@router.get("/tenant")
def tenant(state: AppState = Depends(get_state)) -> dict[str, Any]:
    t = state.tenant
    return {"id": t.id, "name": t.name, "tagline": t.tagline, "fictional": True}


@router.get("/plants")
def plants(state: AppState = Depends(get_state)) -> list[dict[str, Any]]:
    return [_rollup(p, _reactors_of(state, p)) for p in state.tenant.plants]


@router.get("/plants/{plant_id}")
def plant(plant_id: str, state: AppState = Depends(get_state)) -> dict[str, Any]:
    for p in state.tenant.plants:
        if p.id == plant_id:
            rs = _reactors_of(state, p)
            return _rollup(p, rs) | {"reactor_summaries": [r.summary().model_dump() for r in rs]}
    raise HTTPException(status.HTTP_404_NOT_FOUND, f"Unknown plant {plant_id}")


class LoginRequest(BaseModel):
    email: str
    password: str


@auth_router.post("/login")
def login(body: LoginRequest, state: AppState = Depends(get_state)) -> dict[str, Any]:
    """Demo sign-in against the configured demo accounts. Not production identity:
    a pilot would use the customer's SSO (OIDC/SAML)."""
    for user in state.settings.demo_user_list:
        if body.email.strip().lower() == user["email"] and body.password == user["password"]:
            return {
                "token": state.settings.api_token,
                "user": {k: user[k] for k in ("email", "name", "role")},
                "tenant": {"id": state.tenant.id, "name": state.tenant.name},
            }
    raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Email or password is not recognised")


@auth_router.get("/demo-accounts")
def demo_accounts(state: AppState = Depends(get_state)) -> list[dict[str, str]]:
    """Shown on the sign-in screen so judges can log in."""
    return [
        {k: u[k] for k in ("email", "password", "name", "role")}
        for u in state.settings.demo_user_list
    ]
