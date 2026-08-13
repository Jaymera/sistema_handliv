"""add trade records table

Revision ID: 0004_trade_records
Revises: 0003_mt5_accounts
Create Date: 2026-07-17 24:00:00
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

revision: str = "0004_trade_records"
down_revision: str | None = "0003_mt5_accounts"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "trade_records",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("user_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("asset_symbol", sa.String(32), nullable=False),
        sa.Column("result_pct", sa.Numeric(8, 2), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("trade_records")