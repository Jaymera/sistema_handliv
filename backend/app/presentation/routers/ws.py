from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy import select

from app.domain.security import decode_access_token
from app.infrastructure.database.session import SessionLocal

logger = logging.getLogger(__name__)

router = APIRouter()


class ConnectionManager:
    """In-memory connection manager. Pods behind a load balancer require
    an external pubsub (Redis) for proper fan-out — out of MVP scope."""

    def __init__(self) -> None:
        self._connections: dict[str, list[WebSocket]] = {}

    async def connect(self, user_id: str, ws: WebSocket) -> None:
        await ws.accept()
        self._connections.setdefault(user_id, []).append(ws)
        logger.info("WS connect user=%s total=%d", user_id, len(self._connections[user_id]))

    async def disconnect(self, user_id: str, ws: WebSocket) -> None:
        conns = self._connections.get(user_id) or []
        if ws in conns:
            conns.remove(ws)
        if not conns:
            self._connections.pop(user_id, None)

    async def push(self, user_id: str, event: str, payload: dict[str, Any]) -> None:
        for ws in list(self._connections.get(user_id, [])):
            try:
                await ws.send_json({"event": event, "payload": payload})
            except Exception:
                pass


manager = ConnectionManager()


@router.websocket("/ws")
async def websocket_endpoint(ws: WebSocket) -> None:
    token = ws.query_params.get("token") or ""
    try:
        payload = decode_access_token(token)
        user_id = payload["sub"]
    except Exception:
        await ws.close(code=4401)
        return

    await manager.connect(user_id, ws)
    try:
        while True:
            data = await ws.receive_text()
            if data == "ping":
                await ws.send_json({"event": "pong"})
    except WebSocketDisconnect:
        pass
    finally:
        await manager.disconnect(user_id, ws)