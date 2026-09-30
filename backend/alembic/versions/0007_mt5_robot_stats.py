"""Persist per-Magic snapshots independently of legacy account stats.

Revision ID: 0007_mt5_robot_stats
Revises: 0006_mt5_stats
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

revision = "0007_mt5_robot_stats"
down_revision = "0006_mt5_stats"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "mt5_robot_stats",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("account_number", sa.String(64), nullable=False),
        sa.Column("magic", sa.String(20), nullable=False),
        sa.Column("symbol", sa.String(32), nullable=True),
        sa.Column("open_positions", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("floating_pl", sa.Numeric(16, 2), nullable=False, server_default="0"),
        sa.Column("profit_total", sa.Numeric(16, 2), nullable=True),
        sa.Column("win_trades", sa.Integer(), nullable=True),
        sa.Column("loss_trades", sa.Integer(), nullable=True),
        sa.Column("total_trades", sa.Integer(), nullable=True),
        sa.Column("history_scope", sa.String(32), nullable=True),
        sa.Column("heartbeat", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("is_present", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("account_number", "magic", name="uq_mt5_robot_account_magic"),
    )
    op.create_index("ix_mt5_robot_stats_account_number", "mt5_robot_stats", ["account_number"])


def downgrade() -> None:
    op.drop_index("ix_mt5_robot_stats_account_number", table_name="mt5_robot_stats")
    op.drop_table("mt5_robot_stats")
