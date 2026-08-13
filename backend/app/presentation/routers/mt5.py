from __future__ import annotations

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.infrastructure.database.models import MT5Account, TradeRecord, User
from app.infrastructure.database.session import get_db
from app.presentation.deps.auth import get_current_user
from app.presentation.routers.subscriptions import check_user_plan

router = APIRouter()


def _require_ea_token(token: str) -> None:
    """Autentica chamadas do Expert Advisor via MT5_API_TOKEN (compartilhado)."""
    expected = settings.mt5_api_token.get_secret_value()
    if not expected or token != expected:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid mt5 token")


@router.get("/mt5/ea/status")
def ea_account_status(
    account: str = Query(...),
    token: str = Query(...),
    db: Session = Depends(get_db),
) -> dict:
    """Endpoint público para o EA verificar se a conta MT5 está cadastrada e ativa.

    Auth: ?token=<MT5_API_TOKEN> (mesmo valor do .env).
    """
    _require_ea_token(token)
    acc = db.scalar(select(MT5Account).where(MT5Account.account_number == account))
    if acc is None:
        return {"account_number": account, "registered": False, "is_active": False}
    return {
        "account_number": acc.account_number,
        "registered": True,
        "is_active": acc.is_active,
    }


@router.get("/mt5/accounts")
def list_mt5_accounts(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    rows = db.scalars(select(MT5Account).where(MT5Account.user_id == user.id).order_by(MT5Account.created_at.desc())).all()
    return {"items": [{"id": str(r.id), "account_number": r.account_number, "broker": r.broker, "is_active": r.is_active} for r in rows]}


@router.post("/mt5/accounts", status_code=status.HTTP_201_CREATED)
def add_mt5_account(payload: dict, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    accounts_str = payload.get("accounts", "").strip()
    if not accounts_str:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "accounts é obrigatório")
    broker = payload.get("broker", "")
    # Permite múltiplas contas separadas por vírgula
    account_numbers = [a.strip() for a in accounts_str.split(",") if a.strip()]
    created = []
    for num in account_numbers:
        existing = db.scalar(select(MT5Account).where(MT5Account.user_id == user.id, MT5Account.account_number == num))
        if existing:
            continue
        acc = MT5Account(user_id=user.id, account_number=num, broker=broker, is_active=True)
        db.add(acc)
        created.append(num)
    db.commit()
    return {"created": created, "count": len(created)}


@router.delete("/mt5/accounts/{account_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def delete_mt5_account(account_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    acc = db.get(MT5Account, account_id)
    if acc is None or acc.user_id != user.id:
        return
    db.delete(acc)
    db.commit()


@router.get("/me/features")
def my_features(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    """Retorna as features liberadas para o plano do usuário."""
    plan_info = check_user_plan(db, user)
    limits = plan_info["limits"]
    return {
        "plan_code": plan_info["code"],
        "plan_status": plan_info["status"],
        "payment_ok": plan_info["payment_ok"],
        "features": {
            "assets_analyzed_limit": limits.get("assets_analyzed"),
            "robots_indicators": limits.get("robots_indicators", False),
            "copy_trading": limits.get("copy_trading", False),
            "live_trading_room": limits.get("live_trading_room", False),
            "course_discount": limits.get("course_discount", False),
            "trading_panel": limits.get("trading_panel", False),
            "auto_robot": limits.get("auto_robot", False),
        },
        "links": {
            "whatsapp": settings.whatsapp_url,
            "discord": settings.discord_url,
            "cursos": settings.cursos_url,
            "copy_trading": settings.copy_trading_url,
            "robots_indicators": settings.robots_indicators_url,
            "trading_panel": settings.trading_panel_url,
            "auto_robot": settings.auto_robot_url,
        },
    }


# ===== Trade Records (ganhos/perdas) =====

@router.get("/trades")
def list_trades(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    rows = db.scalars(
        select(TradeRecord).where(TradeRecord.user_id == user.id).order_by(TradeRecord.created_at.desc())
    ).all()
    return {
        "items": [
            {
                "id": str(r.id),
                "asset_symbol": r.asset_symbol,
                "result_pct": float(r.result_pct),
                "note": r.note,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in rows
        ]
    }


@router.post("/trades", status_code=status.HTTP_201_CREATED)
def add_trade(payload: dict, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    asset_symbol = payload.get("asset_symbol", "").strip()
    result_pct = payload.get("result_pct")
    note = payload.get("note", "")
    if not asset_symbol or result_pct is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "asset_symbol e result_pct são obrigatórios")
    from decimal import Decimal
    trade = TradeRecord(
        user_id=user.id,
        asset_symbol=asset_symbol.upper(),
        result_pct=Decimal(str(result_pct)),
        note=note or None,
    )
    db.add(trade)
    db.commit()
    return {"id": str(trade.id), "status": "created"}


@router.delete("/trades/{trade_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def delete_trade(trade_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    trade = db.get(TradeRecord, trade_id)
    if trade is None or trade.user_id != user.id:
        return
    db.delete(trade)
    db.commit()