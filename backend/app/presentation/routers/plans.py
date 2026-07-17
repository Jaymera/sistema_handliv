from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.infrastructure.database.models import Plan
from app.infrastructure.database.session import get_db
from app.presentation.schemas.auth import PlanOut

router = APIRouter()


@router.get("/plans", response_model=list[PlanOut])
def list_plans(db: Session = Depends(get_db)) -> list[Plan]:
    return list(db.scalars(select(Plan).where(Plan.is_active == True)).all())  # noqa: E712