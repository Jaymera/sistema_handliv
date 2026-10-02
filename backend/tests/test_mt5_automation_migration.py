"""Migration contract: complete up/down on a temporary SQLite database plus offline SQL.

Never touches production MySQL; the offline run only renders DDL from history.
"""
import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
PY = sys.executable


def alembic(tmp_path, *args, url):
    env = dict(os.environ, DATABASE_URL=url, PYTHONPATH=str(ROOT))
    return subprocess.run([PY, "-m", "alembic", "-c", "alembic.ini", *args], cwd=ROOT, env=env,
                          capture_output=True, text=True, timeout=300)


@pytest.mark.slow
def test_full_migration_chain_up_and_down_on_sqlite(tmp_path):
    db = tmp_path / "chain.db"
    url = f"sqlite:///{db.as_posix()}"
    assert alembic(tmp_path, "upgrade", "head", url=url).returncode == 0
    from sqlalchemy import create_engine, inspect
    names = set(inspect(create_engine(url)).get_table_names())
    assert {"mt5_automation_rules", "mt5_automation_events", "mt5_commands", "mt5_account_stats"} <= names
    rules = inspect(create_engine(url)).get_columns("mt5_automation_rules")
    assert {"broker_symbol", "sl_atr_multiplier", "tp_atr_multiplier", "initialized", "ready", "generation"} <= {c["name"] for c in rules}
    assert alembic(tmp_path, "downgrade", "base", url=url).returncode == 0
    assert not {"mt5_automation_rules", "mt5_automation_events"} & set(inspect(create_engine(url)).get_table_names())


@pytest.mark.slow
def test_offline_mysql_sql_is_complete_and_reversible():
    up = alembic(Path("."), "upgrade", "0007:head", "--sql", url="mysql+pymysql://u:p@localhost:3306/db")
    assert up.returncode == 0, up.stderr
    sql = up.stdout
    assert "CREATE TABLE mt5_automation_rules" in sql
    assert "uq_automation_event" in sql and "automation_positions" in sql
    down = alembic(Path("."), "downgrade", "0008:0007", "--sql", url="mysql+pymysql://u:p@localhost:3306/db")
    assert down.returncode == 0, down.stderr
    assert "DROP TABLE mt5_automation_rules" in down.stdout
