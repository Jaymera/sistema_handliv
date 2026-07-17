from __future__ import annotations

import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.infrastructure.database.models import Alert, AlertType, Asset
from app.infrastructure.database.session import get_db
from app.presentation.deps.auth import get_current_user

router = APIRouter()


class AlertCreate(BaseModel):
    symbol: str
    type: Literal["price_above", "price_below", "score_above", "score_below"]
    threshold: float


class AlertUpdate(BaseModel):
    is_active: bool | None = None


@router.get("/alerts")
def list_alerts(user=Depends(get_current_user), db: Session = Depends(get_db)) -> list[dict]:
    rows = db.scalars(select(Alert).where(Alert.user_id == user.id).order_by(Alert.created_at.desc())).all()
    return [
        {
            "id": a.id,
            "asset": {"id": a.asset_id, "symbol": a.asset.symbol, "name": a.asset.name},
            "type": a.type.value,
            "threshold": float(a.threshold),
            "is_triggered": a.is_triggered,
            "is_active": a.is_active,
        }
        for a in rows
    ]


@router.post("/alerts", status_code=status.HTTP_201_CREATED)
def create_alert(payload: AlertCreate, user=Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    asset = db.scalar(select(Asset).where(Asset.symbol == payload.symbol.upper()))
    if asset is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "asset not found")
    alert = Alert(
        user_id=user.id,
        asset_id=asset.id,
        type=AlertType(payload.type),
        threshold=Decimal(str(payload.threshold)),
    )
    db.add(alert)
    db.commit()
    return {"id": alert.id}


@router.patch("/alerts/{alert_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def update_alert(alert_id: uuid.UUID, payload: AlertUpdate, user=Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    a = db.get(Alert, alert_id)
    if a is None or a.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "alert not found")
    if payload.is_active is not None:
        a.is_active = payload.is_active
    db.commit()


@router.delete("/alerts/{alert_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def delete_alert(alert_id: uuid.UUID, user=Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    a = db.get(Alert, alert_id)
    if a is None or a.user_id != user.id:
        return
    db.delete(a)
    db.commit()