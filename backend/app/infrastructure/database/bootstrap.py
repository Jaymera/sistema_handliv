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
        "stripe_product_id": "prod_UyC28wT66ZpiCK",
        "price_monthly_cents": 0,
        "price_yearly_cents": 0,
        "limits_json": {
            "assets_analyzed": 3,
            "robots_indicators": False,
            "copy_trading": False,
            "live_trading_room": False,
            "course_discount": False,
            "trading_panel": False,
            "auto_robot": False,
            "markets": "all",
            "history_days": 30,
        },
    },
    {
        "code": PlanCode.START,
        "name": "Start",
        "stripe_product_id": "prod_UyC1XCU8KwqfR0",
        "price_monthly_cents": 9700,
        "price_yearly_cents": 97000,
        "limits_json": {
            "assets_analyzed": 10,
            "robots_indicators": True,
            "copy_trading": True,
            "live_trading_room": True,
            "course_discount": True,
            "trading_panel": True,
            "auto_robot": False,
            "markets": "all",
            "history_days": 365,
        },
    },
    {
        "code": PlanCode.ULTIMATE,
        "name": "Ultimate",
        "stripe_product_id": "prod_SWU1b4w9asl9Ed",
        "price_monthly_cents": 29700,
        "price_yearly_cents": 297000,
        "limits_json": {
            "assets_analyzed": None,
            "robots_indicators": True,
            "copy_trading": True,
            "live_trading_room": True,
            "course_discount": True,
            "trading_panel": True,
            "auto_robot": True,
            "markets": "all",
            "history_days": None,
        },
    },
]


def bootstrap_super_admin() -> None:
    db = SessionLocal()
    try:
        # Reparo de dados legados ANTES de qualquer SELECT (roles antigas quebram o ORM)
        try:
            _repair_data(db)
            db.commit()
        except Exception:
            db.rollback()
        admin_email = settings.admin_email.lower()
        existing = None
        try:
            existing = db.scalar(select(User).where(User.email == admin_email))
        except Exception:
            db.rollback()
        if existing is None:
            admin = User(
                name=settings.admin_name,
                email=admin_email,
                password_hash=hash_password(settings.admin_password.get_secret_value()),
                role=Role.SUPER_ADMIN,
                force_password_change=True,
                is_active=True,
            )
            db.add(admin)
            logger.info("Super admin created %s", admin_email)
        # Reparos idempotentes rodam sempre (planos desatualizados)
        _seed_plans(db)
        _seed_score_weights(db)
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def _seed_plans(db) -> None:
    existing = {p.code: p for p in db.scalars(select(Plan)).all()}
    # Migração de códigos legados: pro -> start, premium -> ultimate
    legacy_map = {"pro": "start", "premium": "ultimate"}
    for legacy, new_code in legacy_map.items():
        legacy_plan = existing.get(legacy)
        if legacy_plan is not None and new_code not in existing:
            legacy_plan.code = new_code
            legacy_plan.name = new_code.capitalize()
            existing[new_code] = legacy_plan
            existing.pop(legacy)
    for p in DEFAULT_PLANS:
        row = existing.get(p["code"])
        if row is None:
            db.add(Plan(**p))
        else:
            # Repara planos antigos: nome, preços, stripe product e limits atualizados
            row.name = p["name"]
            row.stripe_product_id = p["stripe_product_id"]
            row.price_monthly_cents = p["price_monthly_cents"]
            row.price_yearly_cents = p["price_yearly_cents"]
            row.limits_json = p["limits_json"]
            row.is_active = True


def _repair_data(db) -> None:
    """Repara dados legados: enums gravados com NAME em vez do value e colunas faltantes."""
    from sqlalchemy import inspect, text

    try:
        db.execute(text("UPDATE users SET role='super_admin' WHERE role='SUPER_ADMIN'"))
        db.execute(text("UPDATE users SET role='user' WHERE role='USER'"))
        # assets: asset_type legado em maiúsculas -> valores do enum (market já é maiúsculo por padrão)
        db.execute(text("UPDATE assets SET asset_type=LOWER(asset_type) WHERE asset_type <> LOWER(asset_type)"))
    except Exception:
        pass

    # Colunas adicionadas por migrations que bancos locais (create_all) podem não ter
    try:
        inspector = inspect(db.bind)
        plan_cols = {c["name"] for c in inspector.get_columns("plans")}
        if "stripe_product_id" not in plan_cols:
            db.execute(text("ALTER TABLE plans ADD COLUMN stripe_product_id VARCHAR(128)"))
    except Exception:
        pass


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