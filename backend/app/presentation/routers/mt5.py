from __future__ import annotations

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.infrastructure.database.models import MT5Account, MT5AccountStats, MT5Command, TradeRecord, User
from app.infrastructure.database.session import get_db
from app.presentation.deps.auth import get_current_user
from app.presentation.routers.subscriptions import check_user_plan

router = APIRouter()

MT5_MAX_ACCOUNTS = 2


def _require_ea_token(account: str, token: str | None) -> None:
    """Valida o token gerado pelo EA: SHA256(account + MT5_API_TOKEN)."""
    import hashlib

    expected = settings.mt5_api_token.get_secret_value()
    if not expected:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "mt5 token not configured")
    expected_hash = hashlib.sha256((account + expected).encode()).hexdigest()
    if token != expected_hash:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid mt5 token")


@router.get("/mt5/ea/status")
def ea_account_status(
    account: str = Query(...),
    token: str | None = Query(None),
    db: Session = Depends(get_db),
) -> dict:
    """Endpoint público para o EA verificar se a conta MT5 está cadastrada e ativa.

    Auth: ?token=SHA256(account + MT5_API_TOKEN), gerado pelo próprio EA.
    """
    _require_ea_token(account, token)
    acc = db.scalar(select(MT5Account).where(MT5Account.account_number == account))
    if acc is None:
        return {"account_number": account, "registered": False, "is_active": False}
    return {
        "account_number": acc.account_number,
        "registered": True,
        "is_active": acc.is_active,
    }


# ===== Painel de Trading remoto (web -> EA) =====


def _cmd_to_dict(c: MT5Command) -> dict:
    return {
        "id": str(c.id),
        "account_number": c.account_number,
        "action": c.action,
        "symbol": c.symbol,
        "volume": float(c.volume) if c.volume is not None else None,
        "status": c.status,
        "result_message": c.result_message,
        "created_at": c.created_at.isoformat() if c.created_at else None,
        "executed_at": c.executed_at.isoformat() if c.executed_at else None,
    }


@router.post("/mt5/orders", status_code=status.HTTP_201_CREATED)
def create_order(payload: dict, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    """Cria um comando (buy/sell/close) para ser executado pelo EA na conta MT5 informada."""
    _require_feature(db, user, "trading_panel", "Painel de Execução MT5 disponível nos planos Start e Ultimate")
    action = (payload.get("action") or "").strip().lower()
    if action not in ("buy", "sell", "close"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "action deve ser buy, sell ou close")
    symbol = (payload.get("symbol") or "").strip().upper()
    volume = payload.get("volume")
    if action in ("buy", "sell"):
        if not symbol:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "symbol é obrigatório para buy/sell")
        try:
            vol = round(float(str(volume).replace(",", ".")), 2) if volume not in (None, "") else None
        except ValueError:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "volume inválido")
        if vol is None or vol <= 0:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "volume deve ser maior que zero")
    else:
        symbol = symbol or None
        vol = None

    # aceita account (número) ou account_id
    account = (payload.get("account") or "").strip()
    account_id = (payload.get("account_id") or "").strip()
    acc = None
    if account_id:
        acc = db.get(MT5Account, account_id)
    elif account:
        acc = db.scalar(select(MT5Account).where(MT5Account.user_id == user.id, MT5Account.account_number == account))
    if acc is None or acc.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "conta MT5 não encontrada")
    if not acc.is_active:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "conta MT5 inativa")

    from decimal import Decimal

    cmd = MT5Command(
        user_id=user.id,
        account_number=acc.account_number,
        action=action,
        symbol=symbol,
        volume=Decimal(str(vol)) if vol is not None else None,
        status="pending",
    )
    db.add(cmd)
    db.commit()
    return _cmd_to_dict(cmd)


@router.get("/mt5/orders")
def list_orders(user: User = Depends(get_current_user), db: Session = Depends(get_db), limit: int = Query(20, le=100)) -> dict:
    _require_feature(db, user, "trading_panel", "Painel de Execução MT5 disponível nos planos Start e Ultimate")
    rows = db.scalars(
        select(MT5Command)
        .where(MT5Command.user_id == user.id)
        .order_by(MT5Command.created_at.desc())
        .limit(limit)
    ).all()
    return {"items": [_cmd_to_dict(c) for c in rows]}


@router.get("/mt5/ea/commands")
def ea_poll_commands(
    account: str = Query(...),
    token: str | None = Query(None),
    db: Session = Depends(get_db),
) -> dict:
    """O EA consulta este endpoint (a cada segundo) para receber comandos pendentes da conta."""
    _require_ea_token(account, token)
    rows = db.scalars(
        select(MT5Command)
        .where(MT5Command.account_number == account, MT5Command.status == "pending")
        .order_by(MT5Command.created_at.asc())
        .limit(10)
    ).all()
    from datetime import datetime, timezone

    items = []
    for c in rows:
        c.status = "sent"
        c.sent_at = datetime.now(timezone.utc)
        items.append(_cmd_to_dict(c))
    db.commit()
    return {"items": items}


@router.post("/mt5/ea/results")
def ea_report_result(payload: dict, db: Session = Depends(get_db)) -> dict:
    """O EA reporta o resultado da execução do comando (sucesso ou falha)."""
    cmd_id = (payload.get("id") or "").strip()
    token = payload.get("token")
    if not cmd_id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "id é obrigatório")
    cmd = db.get(MT5Command, cmd_id)
    if cmd is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "comando não encontrado")
    _require_ea_token(cmd.account_number, token)
    success = bool(payload.get("success"))
    cmd.status = "executed" if success else "failed"
    cmd.result_message = (payload.get("message") or "")[:500] or None
    from datetime import datetime, timezone

    cmd.executed_at = datetime.now(timezone.utc)
    db.commit()
    return {"status": cmd.status}


def _require_feature(db: Session, user: User, feature: str, message: str) -> None:
    """Bloqueia o recurso se o plano do usuário não o incluir (super_admin sempre passa)."""
    if user.role.value == "super_admin":
        return
    plan_info = check_user_plan(db, user)
    if not plan_info.get("limits", {}).get(feature, False):
        raise HTTPException(status.HTTP_403_FORBIDDEN, message)


@router.get("/mt5/accounts")
def list_mt5_accounts(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    _require_feature(db, user, "trading_panel", "Contas MT5 disponíveis nos planos Start e Ultimate")
    rows = db.scalars(select(MT5Account).where(MT5Account.user_id == user.id).order_by(MT5Account.created_at.desc())).all()
    return {"items": [{"id": str(r.id), "account_number": r.account_number, "broker": r.broker, "is_active": r.is_active} for r in rows]}


@router.post("/mt5/accounts", status_code=status.HTTP_201_CREATED)
def add_mt5_account(payload: dict, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    _require_feature(db, user, "trading_panel", "Contas MT5 disponíveis nos planos Start e Ultimate")
    accounts_str = payload.get("accounts", "").strip()
    if not accounts_str:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "accounts é obrigatório")
    broker = payload.get("broker", "")
    # Permite múltiplas contas separadas por vírgula
    account_numbers = [a.strip() for a in accounts_str.split(",") if a.strip()]
    current = len(list(db.scalars(select(MT5Account).where(MT5Account.user_id == user.id)).all()))
    created = []
    for num in account_numbers:
        existing = db.scalar(select(MT5Account).where(MT5Account.user_id == user.id, MT5Account.account_number == num))
        if existing:
            continue
        if current + len(created) >= MT5_MAX_ACCOUNTS:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                f"Limite de {MT5_MAX_ACCOUNTS} contas MT5 atingido no plano Ultimate",
            )
        acc = MT5Account(user_id=user.id, account_number=num, broker=broker, is_active=True)
        db.add(acc)
        created.append(num)
    db.commit()
    return {"created": created, "count": len(created), "max": MT5_MAX_ACCOUNTS}


@router.delete("/mt5/accounts/{account_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def delete_mt5_account(account_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    acc = db.get(MT5Account, account_id)
    if acc is None or acc.user_id != user.id:
        return
    db.delete(acc)
    # Remove também as estatísticas e comandos vinculados ao número da conta
    st = db.scalar(select(MT5AccountStats).where(MT5AccountStats.account_number == acc.account_number))
    if st is not None:
        db.delete(st)
    db.commit()


# ===== Estatísticas da conta MT5 (reportadas pelo EA HandlivPanel) =====

_MONEY_FIELDS = (
    "equity",
    "balance",
    "margin",
    "margin_level",
    "floating_pl",
    "dd_percent",
    "profit_day",
    "profit_week",
    "profit_month",
    "profit_total",
)


def _stats_to_dict(s: MT5AccountStats) -> dict:
    return {
        "login": s.login,
        "currency": s.currency,
        "equity": float(s.equity),
        "balance": float(s.balance),
        "margin": float(s.margin),
        "margin_level": float(s.margin_level),
        "floating_pl": float(s.floating_pl),
        "dd_percent": float(s.dd_percent),
        "profit_day": float(s.profit_day),
        "profit_week": float(s.profit_week),
        "profit_month": float(s.profit_month),
        "profit_total": float(s.profit_total),
        "win_trades": s.win_trades,
        "loss_trades": s.loss_trades,
        "total_trades": s.total_trades,
        "open_positions": s.open_positions,
        "updated_at": s.updated_at.isoformat() if s.updated_at else None,
    }


@router.post("/mt5/ea/stats")
def ea_report_stats(payload: dict, db: Session = Depends(get_db)) -> dict:
    """O EA HandlivPanel reporta periodicamente as estatísticas da conta (DD, P/L, win rate)."""
    from decimal import Decimal

    account = (str(payload.get("account") or payload.get("login") or "")).strip()
    token = payload.get("token")
    if not account:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "account é obrigatório")
    _require_ea_token(account, token)

    def _num(key: str) -> Decimal:
        try:
            return Decimal(str(round(float(str(payload.get(key) or 0).replace(",", ".")), 2)))
        except (TypeError, ValueError):
            return Decimal("0")

    def _int(key: str) -> int:
        try:
            return int(float(str(payload.get(key) or 0)))
        except (TypeError, ValueError):
            return 0

    row = db.scalar(select(MT5AccountStats).where(MT5AccountStats.account_number == account))
    if row is None:
        row = MT5AccountStats(account_number=account)
        db.add(row)
    row.login = str(payload.get("login") or account)
    row.currency = (str(payload.get("currency") or "USD"))[:16]
    for key in _MONEY_FIELDS:
        setattr(row, key, _num(key))
    row.win_trades = _int("win_trades")
    row.loss_trades = _int("loss_trades")
    row.total_trades = _int("total_trades")
    row.open_positions = _int("open_positions")
    db.commit()
    return {"status": "ok"}


@router.get("/mt5/stats")
def my_mt5_stats(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    """Estatísticas das contas MT5 do usuário (P/L dia/semana/mês/total, DD, win rate). Start e Ultimate."""
    _require_feature(db, user, "trading_panel", "Estatísticas MT5 disponíveis nos planos Start e Ultimate")
    accounts = db.scalars(select(MT5Account).where(MT5Account.user_id == user.id).order_by(MT5Account.created_at.desc())).all()
    items = []
    for acc in accounts:
        st = db.scalar(select(MT5AccountStats).where(MT5AccountStats.account_number == acc.account_number))
        items.append(
            {
                "id": str(acc.id),
                "account_number": acc.account_number,
                "broker": acc.broker,
                "is_active": acc.is_active,
                "stats": _stats_to_dict(st) if st is not None else None,
            }
        )
    return {"items": items}


@router.get("/me/features")
def my_features(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    """Retorna as features liberadas para o plano do usuário."""
    plan_info = check_user_plan(db, user)
    limits = plan_info["limits"]

    # Uso diário de ativos analisados (mesma chave de cache do live-analysis)
    assets_used: int | None = None
    if limits.get("assets_analyzed") and user.role.value != "super_admin":
        try:
            from app.infrastructure.cache import cache

            key = f"analyzed_assets:{user.id}"
            assets_used = len(cache.client.smembers(key) or set())
        except Exception:
            assets_used = None

    mt5_count = len(list(db.scalars(select(MT5Account).where(MT5Account.user_id == user.id)).all()))

    return {
        "plan_code": plan_info["code"],
        "plan_status": plan_info["status"],
        "payment_ok": plan_info["payment_ok"],
        "features": {
            "assets_analyzed_limit": limits.get("assets_analyzed"),
            "assets_analyzed_used": assets_used,
            "mt5_accounts_used": mt5_count,
            "mt5_accounts_max": MT5_MAX_ACCOUNTS,
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
    _require_feature(db, user, "trading_panel", "Painel de Trading disponível nos planos Start e Ultimate")
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
    _require_feature(db, user, "trading_panel", "Painel de Trading disponível nos planos Start e Ultimate")
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