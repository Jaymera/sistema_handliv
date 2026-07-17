"""initial schema

Revision ID: 0001_initial
Revises:
Create Date: 2026-07-09 18:00:00
"""
from __future__ import annotations

import uuid
from typing import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

revision: str = "0001_initial"
down_revision: str | None = None
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def _uuid() -> str:
    return str(uuid.uuid4())


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("phone", sa.String(32), nullable=True),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("role", sa.Enum("user", "super_admin", name="role_enum"), nullable=False),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.text("1")),
        sa.Column("force_password_change", sa.Boolean, nullable=False, server_default=sa.text("0")),
        sa.Column("locale", sa.String(8), nullable=False, server_default="pt-BR"),
        sa.Column("theme", sa.String(8), nullable=False, server_default="dark"),
        sa.Column("expo_push_token", sa.String(255), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_login_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("email", name="uq_users_email"),
    )
    op.create_index("ix_users_email", "users", ["email"])
    op.create_index("ix_users_role", "users", ["role"])
    op.create_index("ix_users_deleted_at", "users", ["deleted_at"])

    op.create_table(
        "plans",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("code", sa.String(32), nullable=False),
        sa.Column("name", sa.String(64), nullable=False),
        sa.Column("stripe_price_id", sa.String(128), nullable=True),
        sa.Column("price_monthly_cents", sa.Integer, nullable=False, server_default="0"),
        sa.Column("price_yearly_cents", sa.Integer, nullable=False, server_default="0"),
        sa.Column("limits_json", sa.JSON, nullable=False),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.text("1")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("code", name="uq_plans_code"),
    )

    op.create_table(
        "subscriptions",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("user_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("plan_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("plans.id"), nullable=False),
        sa.Column("stripe_customer_id", sa.String(128), nullable=True),
        sa.Column("stripe_subscription_id", sa.String(128), nullable=True),
        sa.Column("status", sa.Enum("active", "past_due", "canceled", "trialing", name="sub_status_enum"), nullable=False, server_default="active"),
        sa.Column("current_period_end", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancel_at_period_end", sa.Boolean, nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("user_id", name="uq_subscriptions_user_id"),
    )
    op.create_index("ix_subscriptions_user_id", "subscriptions", ["user_id"])
    op.create_index("ix_subscriptions_stripe_subscription_id", "subscriptions", ["stripe_subscription_id"])

    op.create_table(
        "payment_events",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("subscription_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("subscriptions.id", ondelete="SET NULL"), nullable=True),
        sa.Column("stripe_event_id", sa.String(255), nullable=False),
        sa.Column("event_type", sa.String(64), nullable=False),
        sa.Column("payload_json", sa.JSON, nullable=False),
        sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("stripe_event_id", name="uq_payment_events_stripe_event_id"),
    )

    op.create_table(
        "refresh_tokens",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("user_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("token_hash", sa.String(64), nullable=False),
        sa.Column("device_info", sa.String(255), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("token_hash", name="uq_refresh_tokens_token_hash"),
    )
    op.create_index("ix_refresh_tokens_user_id", "refresh_tokens", ["user_id"])
    op.create_index("ix_refresh_tokens_token_hash", "refresh_tokens", ["token_hash"])

    op.create_table(
        "password_resets",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("user_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("token_hash", sa.String(64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("token_hash", name="uq_password_resets_token_hash"),
    )
    op.create_index("ix_password_resets_user_id", "password_resets", ["user_id"])
    op.create_index("ix_password_resets_token_hash", "password_resets", ["token_hash"])

    op.create_table(
        "assets",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("symbol", sa.String(32), nullable=False),
        sa.Column("display_symbol", sa.String(32), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("market", sa.Enum("B3", "NYSE", "NASDAQ", "FOREX", "CRYPTO", "COMMODITY", name="market_enum"), nullable=False),
        sa.Column("asset_type", sa.Enum("stock", "fii", "etf", "bdr", "reit", "forex", "crypto", "commodity", name="asset_type_enum"), nullable=False),
        sa.Column("sector", sa.String(64), nullable=True),
        sa.Column("industry", sa.String(64), nullable=True),
        sa.Column("currency", sa.String(8), nullable=False),
        sa.Column("logo_url", sa.String(512), nullable=True),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.text("1")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("symbol", name="uq_assets_symbol"),
    )
    op.create_index("ix_assets_symbol", "assets", ["symbol"])
    op.create_index("ix_assets_market", "assets", ["market"])

    op.create_table(
        "asset_prices",
        sa.Column("id", mysql.BIGINT, primary_key=True, autoincrement=True),
        sa.Column("asset_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("assets.id", ondelete="CASCADE"), nullable=False),
        sa.Column("trade_date", sa.Date, nullable=False),
        sa.Column("timeframe", sa.String(8), nullable=False, server_default="1d"),
        sa.Column("open", mysql.DECIMAL(18, 6), nullable=True),
        sa.Column("high", mysql.DECIMAL(18, 6), nullable=True),
        sa.Column("low", mysql.DECIMAL(18, 6), nullable=True),
        sa.Column("close", mysql.DECIMAL(18, 6), nullable=True),
        sa.Column("volume", mysql.BIGINT, nullable=True),
        sa.Column("fetched_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("asset_id", "timeframe", "trade_date", name="uq_asset_prices"),
    )
    op.create_index("ix_asset_prices_lookup", "asset_prices", ["asset_id", "timeframe", "trade_date"])

    op.create_table(
        "asset_fundamentals",
        sa.Column("id", mysql.BIGINT, primary_key=True, autoincrement=True),
        sa.Column("asset_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("assets.id", ondelete="CASCADE"), nullable=False),
        sa.Column("snapshot_date", sa.Date, nullable=False),
        sa.Column("pe_ratio", mysql.DECIMAL(12, 4), nullable=True),
        sa.Column("pb_ratio", mysql.DECIMAL(12, 4), nullable=True),
        sa.Column("dividend_yield", mysql.DECIMAL(8, 4), nullable=True),
        sa.Column("roe", mysql.DECIMAL(8, 4), nullable=True),
        sa.Column("margin", mysql.DECIMAL(8, 4), nullable=True),
        sa.Column("revenue_growth", mysql.DECIMAL(8, 4), nullable=True),
        sa.Column("debt_to_equity", mysql.DECIMAL(12, 4), nullable=True),
        sa.Column("dcf_intrinsic_value", mysql.DECIMAL(18, 6), nullable=True),
        sa.Column("sub_score_valuation", sa.Integer, nullable=True),
        sa.Column("payload_json", sa.JSON, nullable=False),
        sa.Column("fetched_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )

    op.create_table(
        "scores",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("asset_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("assets.id", ondelete="CASCADE"), nullable=False),
        sa.Column("timeframe", sa.String(8), nullable=False, server_default="1d"),
        sa.Column("technical_score", sa.Integer, nullable=True),
        sa.Column("valuation_score", sa.Integer, nullable=True),
        sa.Column("sentiment_score", sa.Integer, nullable=True),
        sa.Column("final_score", sa.Integer, nullable=True),
        sa.Column("buyer_strength", sa.Integer, nullable=True),
        sa.Column("seller_strength", sa.Integer, nullable=True),
        sa.Column("confidence", sa.Integer, nullable=True),
        sa.Column("trend", sa.Enum("up", "down", "sideways", name="trend_enum"), nullable=True),
        sa.Column("horizon", sa.Enum("short", "medium", "long", name="horizon_enum"), nullable=True),
        sa.Column("weights_json", sa.JSON, nullable=False),
        sa.Column("inputs_log_json", sa.JSON, nullable=False),
        sa.Column("calculated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_scores_calculated_at", "scores", ["calculated_at"])

    op.create_table(
        "score_weights",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("name", sa.String(64), nullable=False),
        sa.Column("technical_weight", mysql.DECIMAL(5, 4), nullable=False, server_default="0.4000"),
        sa.Column("valuation_weight", mysql.DECIMAL(5, 4), nullable=False, server_default="0.3500"),
        sa.Column("sentiment_weight", mysql.DECIMAL(5, 4), nullable=False, server_default="0.2500"),
        sa.Column("min_confidence", sa.Integer, nullable=False, server_default="50"),
        sa.Column("is_active", sa.Integer, nullable=False, server_default=sa.text("1")),
    )

    op.create_table(
        "watchlist_items",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("user_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("asset_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("assets.id", ondelete="CASCADE"), nullable=False),
        sa.Column("sort_order", sa.Integer, nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("user_id", "asset_id", name="uq_watchlist_items_user_asset"),
    )

    op.create_table(
        "favorites",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("user_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("asset_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("assets.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("user_id", "asset_id", name="uq_favorites_user_asset"),
    )

    op.create_table(
        "alerts",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("user_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("asset_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("assets.id", ondelete="CASCADE"), nullable=False),
        sa.Column("type", sa.Enum("price_above", "price_below", "score_above", "score_below", name="alert_type_enum"), nullable=False),
        sa.Column("threshold", mysql.DECIMAL(12, 4), nullable=False),
        sa.Column("is_triggered", sa.Boolean, nullable=False, server_default=sa.text("0")),
        sa.Column("triggered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.text("1")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    op.create_index("ix_alerts_user_id", "alerts", ["user_id"])
    op.create_index("ix_alerts_asset_id", "alerts", ["asset_id"])

    op.create_table(
        "backtests",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("user_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("asset_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("assets.id", ondelete="CASCADE"), nullable=False),
        sa.Column("start_date", sa.Date, nullable=False),
        sa.Column("end_date", sa.Date, nullable=False),
        sa.Column("timeframe", sa.String(8), nullable=False, server_default="1d"),
        sa.Column("strategy_config_json", sa.JSON, nullable=False),
        sa.Column("total_return_pct", mysql.DECIMAL(12, 4), nullable=True),
        sa.Column("sharpe", mysql.DECIMAL(10, 4), nullable=True),
        sa.Column("sortino", mysql.DECIMAL(10, 4), nullable=True),
        sa.Column("max_drawdown_pct", mysql.DECIMAL(12, 4), nullable=True),
        sa.Column("win_rate", mysql.DECIMAL(8, 4), nullable=True),
        sa.Column("profit_factor", mysql.DECIMAL(12, 4), nullable=True),
        sa.Column("num_trades", sa.Integer, nullable=True),
        sa.Column("equity_curve_json", sa.JSON, nullable=False),
        sa.Column("drawdown_curve_json", sa.JSON, nullable=False),
        sa.Column("status", sa.Enum("queued", "running", "completed", "failed", name="backtest_status_enum"), nullable=False, server_default="queued"),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("error", sa.String(512), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    op.create_index("ix_backtests_user_id", "backtests", ["user_id"])

    op.create_table(
        "backtest_trades",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("backtest_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("backtests.id", ondelete="CASCADE"), nullable=False),
        sa.Column("entry_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("exit_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("side", sa.String(8), nullable=False),
        sa.Column("entry_price", mysql.DECIMAL(18, 6), nullable=False),
        sa.Column("exit_price", mysql.DECIMAL(18, 6), nullable=True),
        sa.Column("quantity", mysql.DECIMAL(18, 6), nullable=False),
        sa.Column("pnl", mysql.DECIMAL(18, 6), nullable=True),
    )
    op.create_index("ix_backtest_trades_backtest_id", "backtest_trades", ["backtest_id"])

    op.create_table(
        "rss_sources",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("name", sa.String(64), nullable=False),
        sa.Column("feed_url", sa.String(512), nullable=False),
        sa.Column("language", sa.String(8), nullable=False, server_default="pt-BR"),
        sa.Column("market", sa.String(32), nullable=True),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.text("1")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("feed_url", name="uq_rss_sources_feed_url"),
    )

    op.create_table(
        "news_articles",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("asset_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("assets.id", ondelete="SET NULL"), nullable=True),
        sa.Column("source", sa.String(64), nullable=False),
        sa.Column("url", sa.String(512), nullable=False),
        sa.Column("title", sa.String(512), nullable=False),
        sa.Column("summary", sa.Text, nullable=True),
        sa.Column("language", sa.String(8), nullable=False, server_default="pt-BR"),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("sentiment_label", sa.Enum("positive", "neutral", "negative", name="sent_label_enum"), nullable=True),
        sa.Column("sentiment_score", mysql.DECIMAL(6, 4), nullable=True),
        sa.Column("fetched_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.UniqueConstraint("url", name="uq_news_articles_url"),
    )
    op.create_index("ix_news_articles_asset_id", "news_articles", ["asset_id"])
    op.create_index("ix_news_articles_published_at", "news_articles", ["published_at"])

    op.create_table(
        "files",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("version", sa.String(32), nullable=False),
        sa.Column("category", sa.Enum("robo_mt5", "indicador", "manual", "outros", name="file_category_enum"), nullable=False),
        sa.Column("storage_key", sa.String(512), nullable=False),
        sa.Column("size_bytes", mysql.BIGINT, nullable=False),
        sa.Column("mime_type", sa.String(128), nullable=False),
        sa.Column("min_plan", sa.Enum("free", "pro", "premium", name="min_plan_enum"), nullable=False, server_default="free"),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.text("1")),
        sa.Column("uploaded_by", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )

    op.create_table(
        "file_downloads",
        sa.Column("id", mysql.BIGINT, primary_key=True, autoincrement=True),
        sa.Column("file_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("files.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("downloaded_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    op.create_index("ix_file_downloads_file_id", "file_downloads", ["file_id", "downloaded_at"])
    op.create_index("ix_file_downloads_user_id", "file_downloads", ["user_id"])

    op.create_table(
        "notifications",
        sa.Column("id", mysql.CHAR(36, charset="ascii"), primary_key=True),
        sa.Column("user_id", mysql.CHAR(36, charset="ascii"), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("type", sa.String(64), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("body", sa.Text, nullable=True),
        sa.Column("payload_json", sa.String(2048), nullable=False, server_default="{}"),
        sa.Column("channel", sa.Enum("push", "email", name="notif_channel_enum"), nullable=False, server_default="push"),
        sa.Column("status", sa.Enum("pending", "sent", "failed", name="notif_status_enum"), nullable=False, server_default="pending"),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    op.create_index("ix_notifications_user_id", "notifications", ["user_id"])

    op.create_table(
        "audit_logs",
        sa.Column("id", mysql.BIGINT, primary_key=True, autoincrement=True),
        sa.Column("actor_user_id", mysql.CHAR(36, charset="ascii"), nullable=True),
        sa.Column("action", sa.String(64), nullable=False),
        sa.Column("target_type", sa.String(32), nullable=True),
        sa.Column("target_id", mysql.CHAR(36, charset="ascii"), nullable=True),
        sa.Column("details_json", sa.String(4096), nullable=False, server_default="{}"),
        sa.Column("ip", sa.String(64), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    op.create_index("ix_audit_logs_actor_user_id", "audit_logs", ["actor_user_id", "created_at"])
    op.create_index("ix_audit_logs_action", "audit_logs", ["action", "created_at"])

    op.create_table(
        "app_logs",
        sa.Column("id", mysql.BIGINT, primary_key=True, autoincrement=True),
        sa.Column("level", sa.Enum("debug", "info", "warning", "error", name="log_level_enum"), nullable=False),
        sa.Column("source", sa.Enum("app", "webhook", "celery", name="log_source_enum"), nullable=False),
        sa.Column("message", sa.Text, nullable=False),
        sa.Column("context_json", sa.String(8192), nullable=False, server_default="{}"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    op.create_index("ix_app_logs_level_created_at", "app_logs", ["level", "created_at"])
    op.create_index("ix_app_logs_source_created_at", "app_logs", ["source", "created_at"])


def downgrade() -> None:
    for tbl in (
        "app_logs", "audit_logs", "notifications", "file_downloads", "files",
        "news_articles", "rss_sources", "backtest_trades", "backtests",
        "alerts", "favorites", "watchlist_items", "score_weights", "scores",
        "asset_fundamentals", "asset_prices", "assets", "password_resets",
        "refresh_tokens", "payment_events", "subscriptions", "plans", "users",
    ):
        op.drop_table(tbl)