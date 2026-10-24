from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.security import require_token
from app.processes import catalog

router = APIRouter(prefix="/processes", tags=["processes"], dependencies=[Depends(require_token)])


@router.get("")
def list_processes() -> dict[str, Any]:
    cat = catalog.load_catalog()
    return {
        "notes": cat["notes"],
        "processes": [
            {
                k: p.get(k)
                for k in (
                    "id",
                    "family",
                    "name",
                    "product",
                    "example",
                    "organism",
                    "reactor",
                    "mode",
                )
            }
            | {"benchmark_fit": (p.get("kairos") or {}).get("benchmark_fit")}
            for p in cat["processes"]
        ],
    }


@router.get("/{process_id}")
def process_detail(process_id: str) -> dict[str, Any]:
    p = catalog.get_process(process_id)
    if p is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"Unknown process {process_id}")
    return p
