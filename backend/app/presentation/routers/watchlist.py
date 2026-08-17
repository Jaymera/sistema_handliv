from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.infrastructure.database.models import Asset, WatchlistItem
from app.infrastructure.database.session import get_db
from app.presentation.deps.auth import get_current_user
from app.presentation.routers.subscriptions import check_user_plan

router = APIRouter()


def _limit_reached(db: Session, user) -> bool:
    count = db.scalar(select(func.count()).select_from(WatchlistItem).where(WatchlistItem.user_id == user.id)) or 0
    plan_info = check_user_plan(db, user)
    limits = {"free": 5, "start": 50, "ultimate": 999999}
    return count >= limits.get(plan_info.get("code", "free"), 5)


@router.get("/watchlist")
def list_watchlist(user=Depends(get_current_user), db: Session = Depends(get_db)) -> list[dict]:
    items = db.scalars(select(WatchlistItem).where(WatchlistItem.user_id == user.id).order_by(WatchlistItem.sort_order)).all()
    return [
        {
            "asset": {"id": w.asset_id, "symbol": w.asset.symbol, "name": w.asset.name, "market": w.asset.market.value},
            "sort_order": w.sort_order,
        }
        for w in items
    ]


@router.post("/watchlist", status_code=status.HTTP_201_CREATED)
def add_to_watchlist(symbol: str, user=Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    asset = db.scalar(select(Asset).where(Asset.symbol == symbol.upper()))
    if asset is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "asset not found")
    existing = db.scalar(select(WatchlistItem).where(WatchlistItem.user_id == user.id, WatchlistItem.asset_id == asset.id))
    if existing is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "already in watchlist")
    if _limit_reached(db, user):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "plan_limit_exceeded")
    next_order = db.scalar(select(WatchlistItem).where(WatchlistItem.user_id == user.id).order_by(WatchlistItem.sort_order.desc())) or 0
    item = WatchlistItem(user_id=user.id, asset_id=asset.id, sort_order=next_order + 1)
    db.add(item)
    db.commit()
    return {"id": item.id, "symbol": asset.symbol}


@router.delete("/watchlist/{symbol}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def remove_from_watchlist(symbol: str, user=Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    asset = db.scalar(select(Asset).where(Asset.symbol == symbol.upper()))
    if asset is None:
        return
    item = db.scalar(select(WatchlistItem).where(WatchlistItem.user_id == user.id, WatchlistItem.asset_id == asset.id))
    if item is not None:
        db.delete(item)
        db.commit()


@router.get("/watchlist/suggested")
def suggested(db: Session = Depends(get_db)) -> list[dict]:
    from app.domain.constants import SUGGESTED_ASSETS

    rows = []
    for s in SUGGESTED_ASSETS:
        asset = db.scalar(select(Asset).where(Asset.symbol == s["symbol"]))
        if asset is None:
            continue
        rows.append({"id": asset.id, "symbol": asset.symbol, "name": asset.name, "market": asset.market.value})
    return rows


@router.patch("/watchlist/reorder", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def reorder(items: list[dict], user=Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    for entry in items:
        asset = db.scalar(select(Asset).where(Asset.symbol == entry["symbol"].upper()))
        if asset is None:
            continue
        item = db.scalar(select(WatchlistItem).where(WatchlistItem.user_id == user.id, WatchlistItem.asset_id == asset.id))
        if item is not None:
            item.sort_order = entry["sort_order"]
    db.commit()