"""add mt5 account stats table

Revision ID: 0006_mt5_stats
Revises: 0005_mt5_commands
Create Date: 2026-08-18 12:00:00
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

revision: str = "0006_mt5_stats"
down_revision: str | None = "0005_mt5_commands"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "mt5_account_stats",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("account_number", sa.String(64), nullable=False, index=True),
        sa.Column("login", sa.String(64), nullable=False, server_default=""),
        sa.Column("currency", sa.String(16), nullable=False, server_default="USD"),
        sa.Column("equity", sa.Numeric(16, 2), nullable=False, server_default="0"),
        sa.Column("balance", sa.Numeric(16, 2), nullable=False, server_default="0"),
        sa.Column("margin", sa.Numeric(16, 2), nullable=False, server_default="0"),
        sa.Column("margin_level", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("floating_pl", sa.Numeric(16, 2), nullable=False, server_default="0"),
        sa.Column("dd_percent", sa.Numeric(8, 2), nullable=False, server_default="0"),
        sa.Column("profit_day", sa.Numeric(16, 2), nullable=False, server_default="0"),
        sa.Column("profit_week", sa.Numeric(16, 2), nullable=False, server_default="0"),
        sa.Column("profit_month", sa.Numeric(16, 2), nullable=False, server_default="0"),
        sa.Column("profit_total", sa.Numeric(16, 2), nullable=False, server_default="0"),
        sa.Column("win_trades", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("loss_trades", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("total_trades", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("open_positions", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("account_number", name="uq_mt5_stats_account"),
    )


def downgrade() -> None:
    op.drop_table("mt5_account_stats")
