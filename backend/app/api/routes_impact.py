"""Impact: savings Kairos brings a plant (money, energy, feedstock), with exports.

Plant history is simulated; improvement rates are measured (see app/impact.py).
"""

from __future__ import annotations

from datetime import date
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status

from app.core.security import require_token
from app.impact import Period, build_impact, to_pdf, to_xlsx
from app.state import AppState, get_state

router = APIRouter(prefix="/impact", tags=["impact"], dependencies=[Depends(require_token)])


def _impact(state: AppState, period: Period, plant: str) -> dict[str, Any]:
    try:
        return build_impact(state.tenant, state.settings.artifacts_dir, period, plant)
    except KeyError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"Unknown plant {plant}") from None


@router.get("")
def impact(
    period: Period = Query("month"),
    plant: str = Query("all"),
    state: AppState = Depends(get_state),
) -> dict[str, Any]:
    return _impact(state, period, plant)


def _filename(period: str, plant: str, ext: str) -> str:
    return f"kairos-impact-{plant}-{period}-{date.today().isoformat()}.{ext}"


@router.get("/export.xlsx")
def export_xlsx(
    period: Period = Query("month"),
    plant: str = Query("all"),
    state: AppState = Depends(get_state),
) -> Response:
    body = to_xlsx(_impact(state, period, plant))
    return Response(
        body,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": f'attachment; filename="{_filename(period, plant, "xlsx")}"'
        },
    )


@router.get("/export.pdf")
def export_pdf(
    period: Period = Query("month"),
    plant: str = Query("all"),
    state: AppState = Depends(get_state),
) -> Response:
    body = to_pdf(_impact(state, period, plant))
    return Response(
        body,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="{_filename(period, plant, "pdf")}"'
        },
    )
