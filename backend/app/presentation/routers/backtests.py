from __future__ import annotations

import uuid
from datetime import date
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.infrastructure.database.models import Asset, Backtest, BacktestStatus
from app.infrastructure.database.session import get_db
from app.infrastructure.queue.tasks.run_backtest import run_backtest
from app.presentation.deps.auth import get_current_user

router = APIRouter()


class BacktestCreate(BaseModel):
    symbol: str
    start_date: date
    end_date: date
    timeframe: Literal["1d", "1h", "15m", "5m"] = "1d"


@router.post("/backtests", status_code=status.HTTP_202_ACCEPTED)
def enqueue_backtest(payload: BacktestCreate, user=Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    asset = db.scalar(select(Asset).where(Asset.symbol == payload.symbol.upper()))
    if asset is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "asset not found")
    if payload.start_date >= payload.end_date:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "invalid date range")
    bt = Backtest(
        user_id=user.id,
        asset_id=asset.id,
        start_date=payload.start_date,
        end_date=payload.end_date,
        timeframe=payload.timeframe,
        strategy_config_json={"use_motor": True},
        status=BacktestStatus.QUEUED,
    )
    db.add(bt)
    db.commit()
    run_backtest.delay(str(bt.id))
    return {"id": str(bt.id), "status": bt.status.value}


@router.get("/backtests")
def list_backtests(user=Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    rows = db.scalars(select(Backtest).where(Backtest.user_id == user.id).order_by(Backtest.created_at.desc())).all()
    return {
        "items": [
            {
                "id": b.id,
                "asset_symbol": b.asset.symbol,
                "status": b.status.value,
                "created_at": b.created_at.isoformat(),
                "total_return_pct": float(b.total_return_pct) if b.total_return_pct else None,
            }
            for b in rows
        ]
    }


@router.get("/backtests/{backtest_id}")
def get_backtest(backtest_id: uuid.UUID, user=Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    b = db.get(Backtest, backtest_id)
    if b is None or b.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "backtest not found")
    return {
        "id": b.id,
        "asset_symbol": b.asset.symbol,
        "start_date": b.start_date.isoformat(),
        "end_date": b.end_date.isoformat(),
        "strategy_config": b.strategy_config_json,
        "metrics": {
            "total_return_pct": float(b.total_return_pct) if b.total_return_pct else None,
            "sharpe": float(b.sharpe) if b.sharpe else None,
            "sortino": float(b.sortino) if b.sortino else None,
            "max_drawdown_pct": float(b.max_drawdown_pct) if b.max_drawdown_pct else None,
            "win_rate": float(b.win_rate) if b.win_rate else None,
            "profit_factor": float(b.profit_factor) if b.profit_factor else None,
            "num_trades": b.num_trades,
        },
        "equity_curve": b.equity_curve_json,
        "drawdown_curve": b.drawdown_curve_json,
        "trades": [
            {
                "entry_date": t.entry_date.isoformat(),
                "exit_date": t.exit_date.isoformat() if t.exit_date else None,
                "side": t.side,
                "entry_price": float(t.entry_price),
                "exit_price": float(t.exit_price) if t.exit_price else None,
                "quantity": float(t.quantity),
                "pnl": float(t.pnl) if t.pnl else None,
            }
            for t in b.trades  # type: ignore[attr-defined]
        ],
        "status": b.status.value,
    }


@router.delete("/backtests/{backtest_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def delete_backtest(backtest_id: uuid.UUID, user=Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    b = db.get(Backtest, backtest_id)
    if b is None or b.user_id != user.id:
        return
    db.delete(b)
    db.commit()