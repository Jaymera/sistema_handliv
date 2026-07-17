#!/usr/bin/env python
"""Script de inicializacao local (sem Docker).
Usa SQLite + fakeredis. Cria tabelas automaticamente e faz bootstrap do Super Admin.

Uso: python run_local.py
"""
from __future__ import annotations

import os
import uuid

# Forca configuracoes locais ANTES de importar qualquer modulo que le settings
os.environ["DATABASE_URL"] = "sqlite:///./handliv_local.db"
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/0")
os.environ.setdefault("APP_ENV", "development")
os.environ.setdefault("LLM_PROVIDER", "disabled")

# Recria settings singleton com os env vars acima
from app.config import Settings, get_settings

local_settings = Settings()
get_settings.cache_clear()
import app.config as cfg

cfg.settings = local_settings

# --- Patch session.py engine para SQLite ANTES de qualquer import de bootstrap/main ---
from sqlalchemy import create_engine, String
from sqlalchemy.dialects import mysql as _mysql_mod
from sqlalchemy.orm import sessionmaker
from sqlalchemy.types import TypeDecorator

from app.infrastructure.database.base import Base
from app.infrastructure.database import models  # noqa: F401 — registra metadata
from app.infrastructure.database import session as session_module


class PortableUUID(TypeDecorator):
    impl = String(36)
    cache = True

    def process_bind_param(self, value, dialect):
        if value is not None:
            return str(value) if isinstance(value, uuid.UUID) else value
        return value

    def process_result_value(self, value, dialect):
        if value is not None:
            try:
                return uuid.UUID(value)
            except (ValueError, AttributeError, TypeError):
                return value
        return value


# Substitui mysql.CHAR(36, charset="ascii") por PortableUUID no metadata
for tbl in Base.metadata.tables.values():
    for col in tbl.columns:
        if isinstance(col.type, _mysql_mod.CHAR) and getattr(col.type, "length", None) == 36:
            col.type = PortableUUID()

sqlite_engine = create_engine(
    "sqlite:///./handliv_local.db",
    connect_args={"check_same_thread": False},
    echo=False,
)
new_session_factory = sessionmaker(bind=sqlite_engine, autoflush=False, expire_on_commit=False)

# Patch in-place no modulo session (todos que importarem depois pegam SQLite)
session_module.engine = sqlite_engine
session_module.SessionLocal = new_session_factory

# Cria tabelas
print("Criando tabelas em SQLite...")
Base.metadata.create_all(sqlite_engine)
print(f"OK: {len(Base.metadata.tables)} tabelas")

# Bootstrap (importa DEPOIS do patch — pegara SessionLocal atualizado)
print("Bootstrap Super Admin...")
try:
    from app.infrastructure.database.bootstrap import bootstrap_super_admin

    bootstrap_super_admin()
    print("OK: Super Admin pronto (admin@handliv.com / samsung12)")
    from app.infrastructure.database.bootstrap import seed_assets
    seed_assets()
    print("OK: Assets populados")
except Exception as exc:
    print(f"Aviso: bootstrap falhou ({exc})")

print()
print("=" * 60)
print("  Handliv Backend rodando em http://localhost:8000")
print("  Swagger:  http://localhost:8000/docs")
print("  ReDoc:    http://localhost:8000/redoc")
print("  Login:    admin@handliv.com / samsung12")
print("=" * 60)
print()

import uvicorn

uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=False)