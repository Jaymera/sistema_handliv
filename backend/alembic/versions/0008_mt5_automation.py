"""MT5 favorite automation: durable rules, unique signal epochs, protected commands.

Revision ID: 0008_mt5_automation
Revises: 0007_mt5_robot_stats
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

revision = "0008_mt5_automation"
down_revision = "0007_mt5_robot_stats"
branch_labels = None
depends_on = None

_ID = mysql.CHAR(36, charset="ascii")


def _stamps() -> list:
    return [
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    ]


def _sqlite() -> bool:
    """op.get_bind() is unavailable in offline mode; the context dialect is not."""
    return op.get_context().dialect.name == "sqlite"


def upgrade() -> None:
    op.create_table(
        "mt5_automation_rules",
        sa.Column("id", _ID, primary_key=True),
        sa.Column("user_id", _ID, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("account_id", _ID, sa.ForeignKey("mt5_accounts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("asset_id", _ID, sa.ForeignKey("assets.id", ondelete="CASCADE"), nullable=False),
        sa.Column("symbol", sa.String(32), nullable=False),
        sa.Column("broker_symbol", sa.String(32), nullable=False),
        sa.Column("direction", sa.String(4), nullable=False, server_default="both"),
        sa.Column("volume", sa.Numeric(10, 2), nullable=False),
        sa.Column("sl_atr_multiplier", sa.Numeric(4, 2), nullable=False, server_default="2.00"),
        sa.Column("tp_atr_multiplier", sa.Numeric(4, 2), nullable=False, server_default="3.00"),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("initialized", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("ready", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("generation", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_signal", sa.String(32), nullable=True),
        sa.Column("last_status", sa.String(64), nullable=True),
        *_stamps(),
        sa.UniqueConstraint("user_id", "account_id", "asset_id", name="uq_automation_rule"),
    )
    op.create_table(
        "mt5_automation_events",
        sa.Column("id", _ID, primary_key=True),
        sa.Column("rule_id", _ID, sa.ForeignKey("mt5_automation_rules.id", ondelete="CASCADE"), nullable=False),
        sa.Column("generation", sa.Integer(), nullable=False),
        sa.Column("signal", sa.String(32), nullable=False),
        *_stamps(),
        sa.UniqueConstraint("rule_id", "generation", name="uq_automation_event"),
    )
    op.add_column("mt5_commands", sa.Column("rule_id", _ID, nullable=True))  # FK added below
    op.add_column("mt5_commands", sa.Column("automation", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.add_column("mt5_commands", sa.Column("sl_atr_multiplier", sa.Numeric(4, 2), nullable=True))
    op.add_column("mt5_commands", sa.Column("tp_atr_multiplier", sa.Numeric(4, 2), nullable=True))
    op.add_column("mt5_commands", sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True))
    if _sqlite():
        with op.batch_alter_table("mt5_commands") as batch:
            batch.create_foreign_key("fk_mt5_commands_rule_id", "mt5_automation_rules", ["rule_id"], ["id"], ondelete="SET NULL")
    else:
        op.create_foreign_key("fk_mt5_commands_rule_id", "mt5_commands", "mt5_automation_rules", ["rule_id"], ["id"], ondelete="SET NULL")
    op.create_index("ix_mt5_commands_rule_id", "mt5_commands", ["rule_id"])
    op.add_column("mt5_account_stats", sa.Column("automation_v1", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.add_column("mt5_account_stats", sa.Column("automation_ready", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.add_column("mt5_account_stats", sa.Column("automation_protection_v1", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.add_column("mt5_account_stats", sa.Column("automation_positions", sa.JSON(), nullable=True))


def downgrade() -> None:
    op.drop_column("mt5_account_stats", "automation_positions")
    op.drop_column("mt5_account_stats", "automation_protection_v1")
    op.drop_column("mt5_account_stats", "automation_ready")
    op.drop_column("mt5_account_stats", "automation_v1")
    op.drop_index("ix_mt5_commands_rule_id", table_name="mt5_commands")
    if _sqlite():
        with op.batch_alter_table("mt5_commands") as batch:
            batch.drop_constraint("fk_mt5_commands_rule_id", type_="foreignkey")
    else:
        op.drop_constraint("fk_mt5_commands_rule_id", "mt5_commands", type_="foreignkey")
    op.drop_column("mt5_commands", "expires_at")
    op.drop_column("mt5_commands", "tp_atr_multiplier")
    op.drop_column("mt5_commands", "sl_atr_multiplier")
    op.drop_column("mt5_commands", "automation")
    op.drop_column("mt5_commands", "rule_id")
    op.drop_table("mt5_automation_events")
    op.drop_table("mt5_automation_rules")
