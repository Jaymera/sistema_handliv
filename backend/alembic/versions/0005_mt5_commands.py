"""add mt5 commands table

Revision ID: 0005_mt5_commands
Revises: 0004_trade_records
Create Date: 2026-08-17 12:00:00
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

revision: str = "0005_mt5_commands"
down_revision: str | None = "0004_trade_records"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "mt5_commands",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("user_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("account_number", sa.String(64), nullable=False, index=True),
        sa.Column("action", sa.String(10), nullable=False),
        sa.Column("symbol", sa.String(32), nullable=True),
        sa.Column("volume", sa.Numeric(10, 2), nullable=True),
        sa.Column("status", sa.String(16), nullable=False, server_default="pending", index=True),
        sa.Column("result_message", sa.Text(), nullable=True),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("executed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("mt5_commands")
