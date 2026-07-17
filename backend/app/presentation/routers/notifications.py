from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.infrastructure.database.models import Notification, User
from app.infrastructure.database.session import get_db
from app.presentation.deps.auth import get_current_user

router = APIRouter()


class PushTokenRequest(BaseModel):
    token: str


@router.get("/notifications")
def list_notifications(user=Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    rows = db.scalars(select(Notification).where(Notification.user_id == user.id).order_by(Notification.created_at.desc()).limit(50)).all()
    return {"items": [{"id": n.id, "type": n.type, "title": n.title, "body": n.body, "sent_at": n.sent_at.isoformat() if n.sent_at else None, "read": False} for n in rows]}


@router.post("/notifications/{notification_id}/read", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def mark_read(notification_id: uuid.UUID, user=Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    n = db.get(Notification, notification_id)
    if n is None or n.user_id != user.id:
        return
    # naive: reuse payload_json to store read status as {"read": True}
    n.payload_json = {**(n.payload_json or {}), "read": True}
    db.commit()


@router.post("/notifications/read-all", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def mark_all_read(user=Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    rows = db.scalars(select(Notification).where(Notification.user_id == user.id)).all()
    for n in rows:
        n.payload_json = {**(n.payload_json or {}), "read": True}
    db.commit()


@router.post("/notifications/push-token", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def register_push_token(payload: PushTokenRequest, user=Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    user.expo_push_token = payload.token
    db.commit()