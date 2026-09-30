"""Executable route contract against a real in-memory SQLAlchemy database."""
import ast
import hashlib
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from sqlalchemy import Boolean, DateTime, Integer, Numeric, String, create_engine, select
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column

ROOT = Path(__file__).resolve().parents[1]
ROUTE = ROOT / 'app/presentation/routers/mt5.py'

class Base(DeclarativeBase):
    pass

class MT5Account(Base):
    __tablename__ = 'accounts'
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer)
    account_number: Mapped[str] = mapped_column(String)
    broker: Mapped[str] = mapped_column(String, default='')
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc))

class MT5AccountStats(Base):
    __tablename__ = 'stats'
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    account_number: Mapped[str] = mapped_column(String, unique=True)
    login: Mapped[str] = mapped_column(String, default='')
    currency: Mapped[str] = mapped_column(String, default='USD')
    equity: Mapped[Decimal] = mapped_column(Numeric, default=0)
    balance: Mapped[Decimal] = mapped_column(Numeric, default=0)
    margin: Mapped[Decimal] = mapped_column(Numeric, default=0)
    margin_level: Mapped[Decimal] = mapped_column(Numeric, default=0)
    floating_pl: Mapped[Decimal] = mapped_column(Numeric, default=0)
    dd_percent: Mapped[Decimal] = mapped_column(Numeric, default=0)
    profit_day: Mapped[Decimal] = mapped_column(Numeric, default=0)
    profit_week: Mapped[Decimal] = mapped_column(Numeric, default=0)
    profit_month: Mapped[Decimal] = mapped_column(Numeric, default=0)
    profit_total: Mapped[Decimal] = mapped_column(Numeric, default=0)
    win_trades: Mapped[int] = mapped_column(Integer, default=0)
    loss_trades: Mapped[int] = mapped_column(Integer, default=0)
    total_trades: Mapped[int] = mapped_column(Integer, default=0)
    open_positions: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc))

class MT5RobotStats(Base):
    __tablename__ = 'robots'
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    account_number: Mapped[str] = mapped_column(String)
    magic: Mapped[str] = mapped_column(String)
    symbol: Mapped[str | None] = mapped_column(String, nullable=True)
    open_positions: Mapped[int] = mapped_column(Integer)
    floating_pl: Mapped[Decimal] = mapped_column(Numeric)
    profit_total: Mapped[Decimal | None] = mapped_column(Numeric, nullable=True)
    win_trades: Mapped[int | None] = mapped_column(Integer, nullable=True)
    loss_trades: Mapped[int | None] = mapped_column(Integer, nullable=True)
    total_trades: Mapped[int | None] = mapped_column(Integer, nullable=True)
    history_scope: Mapped[str | None] = mapped_column(String, nullable=True)
    heartbeat: Mapped[bool] = mapped_column(Boolean, default=False)
    is_present: Mapped[bool] = mapped_column(Boolean, default=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc))

@pytest.fixture
def api():
    tree = ast.parse(ROUTE.read_text(encoding='utf-8'))
    names = {'_MONEY_FIELDS', '_stats_to_dict', '_robot_to_dict', '_validate_robots', '_require_ea_token', 'ea_report_stats', 'my_mt5_stats'}
    selected = [n for n in tree.body if (isinstance(n, (ast.FunctionDef, ast.Assign)) and
                 ((isinstance(n, ast.FunctionDef) and n.name in names) or
                  (isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id in names for t in n.targets))))]
    for n in selected:
        if isinstance(n, ast.FunctionDef): n.decorator_list = []
    env = dict(Decimal=Decimal, select=select, MT5Account=MT5Account, MT5AccountStats=MT5AccountStats,
               MT5RobotStats=MT5RobotStats, HTTPException=HTTPException, status=SimpleNamespace(HTTP_400_BAD_REQUEST=400, HTTP_401_UNAUTHORIZED=401),
               settings=SimpleNamespace(mt5_api_token=SimpleNamespace(get_secret_value=lambda: 'secret')),
               _require_feature=lambda *args: None, datetime=datetime, timezone=timezone, Session=Session, User=object,
               Depends=lambda x: None, get_db=lambda: None, get_current_user=lambda: None)
    code = compile(ast.fix_missing_locations(ast.Module(body=[ast.ImportFrom(module='__future__', names=[ast.alias(name='annotations')], level=0)] + selected, type_ignores=[])), str(ROUTE), 'exec')
    exec(code, env)
    engine = create_engine('sqlite://')
    Base.metadata.create_all(engine)
    with Session(engine) as db:
        db.add_all([MT5Account(id=1, user_id=1, account_number='123', broker='Broker'),
                    MT5Account(id=2, user_id=2, account_number='456', broker='Other')])
        db.commit()
        yield SimpleNamespace(db=db, post=env['ea_report_stats'], get=env['my_mt5_stats'])

def payload(account='123', robots=None):
    d = {'account': account, 'login': account,
         'token': hashlib.sha256((account + 'secret').encode()).hexdigest(),
         'balance': 1000, 'equity': 1010}
    if robots is not None: d['robots'] = robots
    return d

def robot(magic='42', **kwargs):
    return {'magic': magic, 'symbol': 'EURUSD', 'open_positions': 1, 'floating_pl': 12.5,
            'profit_total': 25.0, 'total_trades': 2, 'win_trades': 1, 'loss_trades': 1,
            'history_scope': 'account_history', **kwargs}

def test_account_and_distinct_magic_snapshots(api):
    api.post(payload(robots=[robot('42'), robot('84')]), api.db)
    item = api.get(SimpleNamespace(id=1), api.db)['items'][0]
    assert item['stats']['balance'] == 1000
    assert [r['magic'] for r in item['robots']] == ['42', '84']
    assert item['robots'][0]['floating_pl'] == 12.5
    assert item['robots'][0]['is_present'] is True
    assert item['robots'][0]['updated_at']

def test_legacy_payload_keeps_existing_robot_snapshot(api):
    api.post(payload(robots=[robot()]), api.db)
    api.post(payload(), api.db)
    assert len(api.get(SimpleNamespace(id=1), api.db)['items'][0]['robots']) == 1

def test_new_snapshot_marks_absent_magic_without_deleting_history(api):
    api.post(payload(robots=[robot('42'), robot('84')]), api.db)
    api.post(payload(robots=[robot('84')]), api.db)
    robots = api.get(SimpleNamespace(id=1), api.db)['items'][0]['robots']
    assert [(r['magic'], r['is_present']) for r in robots] == [('42', False), ('84', True)]

def test_rejects_duplicate_or_invalid_robot_without_partial_account_write(api):
    for robots in ([robot(), robot()], [robot(magic='-1')], [robot(floating_pl=float('inf'))],
                   [robot(open_positions=-1)], [robot(total_trades=3)]):
        with pytest.raises(HTTPException) as exc:
            api.post(payload(robots=robots), api.db)
        assert exc.value.status_code == 400
    assert api.db.scalar(select(MT5AccountStats)) is None

def test_scopes_robots_to_owned_account(api):
    api.post(payload(robots=[robot()]), api.db)
    api.post(payload('456', robots=[robot('99')]), api.db)
    assert [r['magic'] for r in api.get(SimpleNamespace(id=2), api.db)['items'][0]['robots']] == ['99']

def test_missing_realized_data_remains_null(api):
    r = robot()
    for k in ('profit_total', 'total_trades', 'win_trades', 'loss_trades', 'history_scope'): r.pop(k)
    api.post(payload(robots=[r]), api.db)
    result = api.get(SimpleNamespace(id=1), api.db)['items'][0]['robots'][0]
    assert result['profit_total'] is None and result['total_trades'] is None

def test_manual_magic_is_not_a_robot_and_heartbeat_is_explicit(api):
    with pytest.raises(HTTPException):
        api.post(payload(robots=[robot(magic='0')]), api.db)
    api.post(payload(robots=[robot(magic='42', heartbeat=True)]), api.db)
    r = api.get(SimpleNamespace(id=1), api.db)['items'][0]['robots'][0]
    assert r['magic'] == '42' and r['heartbeat'] is True
