from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.config import settings
from app.domain.security import hash_password
from app.infrastructure.database.models import Plan, PlanCode, Role, ScoreWeights, User
from app.infrastructure.database.session import SessionLocal

logger = logging.getLogger(__name__)

DEFAULT_PLANS = [
    {
        "code": PlanCode.FREE,
        "name": "Free",
        "price_monthly_cents": 0,
        "price_yearly_cents": 0,
        "limits_json": {
            "watchlist": 5,
            "alerts": 5,
            "ai": False,
            "mt5": False,
            "markets": ["B3"],
            "history_days": 30,
            "backtests_per_month": 1,
            "auto_trading": False,
        },
    },
    {
        "code": PlanCode.PRO,
        "name": "Pro",
        "price_monthly_cents": 4900,
        "price_yearly_cents": 49000,
        "limits_json": {
            "watchlist": 50,
            "alerts": 50,
            "ai": True,
            "mt5": True,
            "markets": ["B3", "NYSE", "NASDAQ", "FOREX"],
            "history_days": 365,
            "backtests_per_month": 50,
            "auto_trading": False,
        },
    },
    {
        "code": PlanCode.PREMIUM,
        "name": "Premium",
        "price_monthly_cents": 9900,
        "price_yearly_cents": 99000,
        "limits_json": {
            "watchlist": None,
            "alerts": None,
            "ai": True,
            "mt5": True,
            "markets": "all",
            "history_days": None,
            "backtests_per_month": None,
            "auto_trading": True,
        },
    },
]


def bootstrap_super_admin() -> None:
    db = SessionLocal()
    try:
        admin_email = settings.admin_email.lower()
        existing = db.scalar(select(User).where(User.email == admin_email))
        if existing is not None:
            return
        admin = User(
            name=settings.admin_name,
            email=admin_email,
            password_hash=hash_password(settings.admin_password.get_secret_value()),
            role=Role.SUPER_ADMIN,
            force_password_change=True,
            is_active=True,
        )
        db.add(admin)
        _seed_plans(db)
        _seed_score_weights(db)
        db.commit()
        logger.info("Super admin created %s", admin_email)
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def _seed_plans(db) -> None:
    existing = set(db.scalars(select(Plan.code)).all())
    for p in DEFAULT_PLANS:
        if p["code"] not in existing:
            db.add(Plan(**p))


def _seed_score_weights(db) -> None:
    active = db.scalar(select(ScoreWeights).where(ScoreWeights.is_active == True))  # noqa: E712
    if active is None:
        db.add(ScoreWeights(name="default", is_active=True))


def seed_assets() -> None:
    """Popula a tabela assets com os ativos sugeridos."""
    from app.domain.constants import ALL_ASSETS
    from app.infrastructure.database.models import Asset, AssetType, Market

    db = SessionLocal()
    try:
        existing = set(db.scalars(select(Asset.symbol)).all())
        created = 0
        for s in ALL_ASSETS:
            if s["symbol"] in existing:
                continue
            db.add(
                Asset(
                    symbol=s["symbol"],
                    display_symbol=s["display_symbol"],
                    name=s["name"],
                    market=Market(s["market"]),
                    asset_type=AssetType(s["asset_type"]),
                    currency=s["currency"],
                    is_active=True,
                )
            )
            created += 1
        if created:
            db.commit()
            logger.info("Seeded %d assets", created)
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()