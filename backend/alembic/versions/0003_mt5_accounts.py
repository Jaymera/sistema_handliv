"""add mt5 accounts table

Revision ID: 0003_mt5_accounts
Revises: 0002_stripe_products
Create Date: 2026-07-17 23:00:00
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

revision: str = "0003_mt5_accounts"
down_revision: str | None = "0002_stripe_products"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "mt5_accounts",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("user_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("account_number", sa.String(64), nullable=False),
        sa.Column("broker", sa.String(128), nullable=True),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.text("1")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("mt5_accounts")