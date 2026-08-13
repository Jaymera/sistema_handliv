"""add stripe product id and update plan codes

Revision ID: 0002_stripe_products
Revises: 0001_initial
Create Date: 2026-07-17 22:00:00
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision: str = "0002_stripe_products"
down_revision: str | None = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("plans", sa.Column("stripe_product_id", sa.String(128), nullable=True))


def downgrade() -> None:
    op.drop_column("plans", "stripe_product_id")