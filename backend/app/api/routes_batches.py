from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.security import require_token
from app.pipeline.inference import DERIVED_KEYS, SENSOR_KEYS
from app.schemas import BatchInfo
from app.state import AppState, get_state

router = APIRouter(prefix="/batches", tags=["batches"], dependencies=[Depends(require_token)])


@router.get("", response_model=list[BatchInfo])
def list_batches(state: AppState = Depends(get_state)) -> list[BatchInfo]:
    return [
        BatchInfo(
            batch_id=b.batch_id,
            strategy=b.strategy,
            is_fault_batch=b.is_fault_batch,
            t_end_h=b.t_end_h,
            rows=b.rows,
            yield_total_kg=b.yield_total_kg,
            final_penicillin_gl=float(b.columns["penicillin_gl"][-1]),
        )
        for b in state.store.batches.values()
    ]


@router.get("/{batch_id}/trajectory")
def trajectory(
    batch_id: int,
    keys: list[str] = Query(default=["do_pct", "ph", "temp_c", "feed", "aeration"]),
    every: int = Query(default=5, ge=1, le=100),
    until_h: float | None = None,
    state: AppState = Depends(get_state),
) -> dict[str, Any]:
    """Downsampled sensor history (every Nth row). `until_h` stops at the replay cursor."""
    if batch_id not in state.store.batches:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"Unknown batch {batch_id}")
    b = state.store.get(batch_id)
    sources = {**SENSOR_KEYS, **DERIVED_KEYS}
    unknown = [k for k in keys if k not in sources]
    if unknown:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, f"Unknown keys {unknown}")
    end = b.index_at(until_h) + 1 if until_h is not None else b.rows
    sl = slice(0, end, every)
    return {
        "batch_id": batch_id,
        "t_h": b.time_h[sl].round(3).tolist(),
        "series": {k: b.columns[sources[k]][sl].round(4).tolist() for k in keys},
    }
