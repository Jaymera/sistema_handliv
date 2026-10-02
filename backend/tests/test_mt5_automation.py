"""Safety contracts, isolated SQLite only: never production or broker calls."""
from datetime import datetime, timezone, timedelta
from decimal import Decimal
import pytest


def test_volume_is_exact_finite_positive_numeric_two():
    from app.application.mt5_automation import parse_volume
    assert parse_volume('0.10') == Decimal('0.10')
    for value in ['NaN', 'Infinity', '-1', '0', '0.001', '100000000', True, None]:
        with pytest.raises(ValueError):
            parse_volume(value)


@pytest.fixture
def db():
    from sqlalchemy import create_engine
    from sqlalchemy.orm import Session
    from app.infrastructure.database.base import Base
    import app.infrastructure.database.models
    engine = create_engine('sqlite://')
    Base.metadata.create_all(engine)
    with Session(engine) as session:
        yield session


def rule(db, **changes):
    from app.infrastructure.database.models import MT5AutomationRule
    obj = MT5AutomationRule(id='r', user_id='u', account_id='a', asset_id='s',
        symbol='EURUSD', broker_symbol='EURUSD.a', direction='both', volume=Decimal('0.10'), enabled=True,
        generation=0, initialized=False, ready=False, **changes)
    db.add(obj)
    db.flush()
    return obj


def test_durable_baseline_and_only_new_strong_after_valid_neutral(db):
    from app.application.mt5_automation import observe_signal
    from app.infrastructure.database.models import MT5Command, MT5AutomationEvent
    from sqlalchemy import select
    r = rule(db)
    now = datetime.now(timezone.utc)
    assert observe_signal(db, r, 'COMPRA FORTE', '123', now) is None
    assert observe_signal(db, r, None, '123', now) is None
    assert observe_signal(db, r, 'VENDA FORTE', '123', now) is None
    assert observe_signal(db, r, 'NEUTRO', '123', now) is None
    cmd = observe_signal(db, r, 'VENDA FORTE', '123', now)
    assert cmd.action == 'sell' and cmd.symbol == 'EURUSD.a'
    assert cmd.volume == Decimal('0.10') and cmd.rule_id == 'r'
    assert cmd.expires_at == now + timedelta(seconds=120)
    assert observe_signal(db, r, 'VENDA FORTE', '123', now) is None
    assert len(db.scalars(select(MT5Command)).all()) == 1
    assert len(db.scalars(select(MT5AutomationEvent)).all()) == 1
    db.commit()
    assert r.last_signal == 'VENDA FORTE' and r.last_status == 'pending'


@pytest.fixture
def owned(db):
    from app.infrastructure.database.models import User, Role, MT5Account, Asset, Market, AssetType, WatchlistItem
    u = User(id='u', name='Test', email='test@example.invalid', password_hash='unused', role=Role.SUPER_ADMIN)
    a = MT5Account(id='a', user_id='u', account_number='123', is_active=True)
    s = Asset(id='s', symbol='EURUSD', display_symbol='EURUSD', name='Euro', market=Market.FOREX, asset_type=AssetType.FOREX, currency='USD')
    db.add_all([u,a,s,WatchlistItem(id='w', user_id='u', asset_id='s')])
    db.commit()
    return u,a,s


def test_put_list_disabled_and_explicit_broker_with_owner_and_favorite_guards(db, owned):
    from app.application.mt5_automation import put_rule, list_rules
    from fastapi import HTTPException
    from app.infrastructure.database.models import WatchlistItem
    u,a,s = owned
    payload = dict(account_id='a', broker_symbol='EURUSD.a', direction='both', volume='0.10', enabled=False)
    result = put_rule(db,u,'eurusd',payload)
    assert result['enabled'] is False and result['volume'] == '0.10'
    assert result['broker_symbol'] == 'EURUSD.a' and result['last_signal'] is None
    assert list_rules(db,u,'a') == {'items':[result]}
    with pytest.raises(HTTPException):
        put_rule(db,u,'EURUSD',{**payload, 'broker_symbol':''})
    with pytest.raises(HTTPException):
        put_rule(db,u,'EURUSD',{**payload, 'account_id':'unknown'})
    db.delete(db.get(WatchlistItem,'w')); db.flush()
    assert list_rules(db,u,'a') == {'items':[]}
    with pytest.raises(HTTPException):
        put_rule(db,u,'EURUSD',payload)


def test_dispatch_requires_fresh_capability_readiness_and_poll_revokes_removed(db, owned):
    from app.application.mt5_automation import dispatch_allowed, command_allowed
    from app.infrastructure.database.models import MT5AccountStats, WatchlistItem, MT5Command
    r = rule(db)
    now = datetime.now(timezone.utc)
    assert not dispatch_allowed(db,r,now)
    st = MT5AccountStats(id='st', account_number='123', automation_v1=True, automation_ready=False, automation_protection_v1=True, automation_positions=[], updated_at=now)
    db.add(st); db.flush()
    assert not dispatch_allowed(db,r,now)
    st.automation_ready = True
    assert dispatch_allowed(db,r,now)
    st.updated_at = now-timedelta(seconds=121)
    assert not dispatch_allowed(db,r,now)
    st.updated_at = now
    observe = __import__('app.application.mt5_automation', fromlist=['observe_signal']).observe_signal
    observe(db,r,'NEUTRO','123',now)
    cmd = observe(db,r,'COMPRA FORTE','123',now)
    assert command_allowed(db,cmd,now)
    db.delete(db.get(WatchlistItem,'w')); db.flush()
    assert not command_allowed(db,cmd,now)
    assert cmd.status == 'revoked'
    manual = MT5Command(id='m',user_id='u',account_number='123',action='buy',symbol='EURUSD',volume=Decimal('0.10'),status='pending')
    db.add(manual); db.flush()
    assert command_allowed(db,manual,now)


def test_pending_sent_and_executed_commands_prevent_second_entry(db):
    from app.application.mt5_automation import observe_signal
    r = rule(db); now = datetime.now(timezone.utc)
    observe_signal(db,r,'NEUTRO','123',now)
    cmd = observe_signal(db,r,'COMPRA FORTE','123',now)
    for state in ('pending','sent','executed'):
        cmd.status = state
        observe_signal(db,r,'NEUTRO','123',now)
        assert observe_signal(db,r,'VENDA FORTE','123',now) is None
    assert r.last_status == 'position_unconfirmed'


def route_functions():
    import ast
    from pathlib import Path
    from types import SimpleNamespace
    from sqlalchemy import select
    from fastapi import HTTPException
    import app.infrastructure.database.models as models
    path = Path(__file__).parents[1]/'app/presentation/routers/mt5.py'
    names = {'_cmd_to_dict','list_automation','put_automation','ea_poll_commands','ea_report_result','ea_report_stats'}
    nodes = [n for n in ast.parse(path.read_text(encoding='utf-8')).body if isinstance(n,ast.FunctionDef) and n.name in names]
    for n in nodes: n.decorator_list=[]
    env = dict(vars(models), _MONEY_FIELDS=('balance',), select=select, Session=object, Depends=lambda _:None,
        Query=lambda *a,**k:None,get_current_user=lambda:None,get_db=lambda:None,
        _require_ea_token=lambda *a:None,HTTPException=HTTPException,
        status=SimpleNamespace(HTTP_400_BAD_REQUEST=400,HTTP_404_NOT_FOUND=404,HTTP_409_CONFLICT=409))
    exec(compile(ast.fix_missing_locations(ast.Module(body=[ast.ImportFrom(module='__future__',names=[ast.alias(name='annotations')],level=0)]+nodes,type_ignores=[])),str(path),'exec'),env)
    return env


def test_routes_poll_metadata_and_results_are_idempotent(db, owned):
    from app.infrastructure.database.models import MT5AccountStats
    from app.application.mt5_automation import observe_signal
    api=route_functions(); u,a,s=owned
    data=api['put_automation']('EURUSD',dict(account_id='a',broker_symbol='EURUSD.a',direction='both',volume='0.10',enabled=True,stop_mode='atr',atr_period=14,atr_timeframe='H1',sl_atr_multiplier='2.00',tp_atr_multiplier='3.00'),u,db)
    assert api['list_automation']('a',u,db)['items'][0] == data
    from app.infrastructure.database.models import MT5AutomationRule
    r=db.get(MT5AutomationRule,data['id']); now=datetime.now(timezone.utc)
    db.add(MT5AccountStats(id='st',account_number='123',automation_v1=True,automation_ready=True,automation_protection_v1=True,automation_positions=[],updated_at=now)); db.flush()
    observe_signal(db,r,'NEUTRO','123',now); cmd=observe_signal(db,r,'COMPRA FORTE','123',now)
    assert api['ea_poll_commands']('123','test',db)['items']==[]
    items=api['ea_poll_commands']('123','test',db, '1', '1', '1')['items']
    assert items[0]['automation'] is True and items[0]['magic']=='20261002'
    assert items[0]['rule_id']==r.id and items[0]['expires_at'].endswith('+00:00')
    assert api['ea_poll_commands']('123','test',db)['items']==[]
    assert api['ea_report_result']({'id':cmd.id,'success':True,'message':'ok'},db)['status']=='executed'
    assert r.last_status=='executed'
    assert api['ea_report_result']({'id':cmd.id,'success':False},db)['status']=='executed'


def test_mandatory_protection_persisted_validated_and_capability_blocks(db,owned):
    from app.application.mt5_automation import put_rule, dispatch_allowed, observe_signal
    from app.infrastructure.database.models import MT5AccountStats, MT5AutomationRule
    from fastapi import HTTPException
    u,a,s=owned
    base=dict(account_id='a',broker_symbol='EURUSD.a',direction='buy',volume='0.10',enabled=True)
    with pytest.raises(HTTPException): put_rule(db,u,'EURUSD',base)
    protection=dict(stop_mode='atr',atr_period=14,atr_timeframe='H1',sl_atr_multiplier='2.00',tp_atr_multiplier='3.00')
    for bad in ['NaN','0','20.01','-1',True,'2.001']:
        with pytest.raises(HTTPException): put_rule(db,u,'EURUSD',{**base,**protection,'sl_atr_multiplier':bad})
    data=put_rule(db,u,'EURUSD',{**base,**protection})
    assert all(data[k]==v for k,v in protection.items())
    r=db.get(MT5AutomationRule,data['id']); now=datetime.now(timezone.utc)
    st=MT5AccountStats(id='st',account_number='123',automation_v1=True,automation_ready=True,automation_positions=[],updated_at=now)
    db.add(st);db.flush()
    assert not dispatch_allowed(db,r,now)
    st.automation_protection_v1=True
    assert dispatch_allowed(db,r,now)
    observe_signal(db,r,'NEUTRO','123',now);cmd=observe_signal(db,r,'COMPRA FORTE','123',now)
    obj=route_functions()['_cmd_to_dict'](cmd)
    assert all(obj[k]==v for k,v in protection.items())


def test_fresh_complete_flat_snapshot_releases_executed_but_not_sent(db,owned):
    from app.application.mt5_automation import observe_signal, dispatch_allowed
    from app.infrastructure.database.models import MT5AccountStats
    now=datetime.now(timezone.utc);r=rule(db)
    st=MT5AccountStats(id='st',account_number='123',automation_v1=True,automation_ready=True,
        automation_protection_v1=True,automation_positions=[],updated_at=now)
    db.add(st);db.flush()
    observe_signal(db,r,'NEUTRO','123',now);cmd=observe_signal(db,r,'COMPRA FORTE','123',now)
    cmd.status='executed';cmd.executed_at=now
    st.automation_positions=[{'symbol':'OTHER.a','open_positions':1}]
    st.updated_at=now+timedelta(seconds=1)
    now+=timedelta(seconds=2)
    assert dispatch_allowed(db,r,now)
    observe_signal(db,r,'NEUTRO','123',now)
    second=observe_signal(db,r,'VENDA FORTE','123',now)
    assert second is not None
    second.status='sent'
    observe_signal(db,r,'NEUTRO','123',now)
    assert observe_signal(db,r,'COMPRA FORTE','123',now) is None
    st.automation_positions=None
    assert not dispatch_allowed(db,r,now)
    st.automation_positions=[{'symbol':'EURUSD.a','open_positions':1}]
    assert not dispatch_allowed(db,r,now)


def test_stats_strict_capabilities_complete_position_snapshot_and_legacy_clears(db,owned):
    api=route_functions()
    from app.infrastructure.database.models import MT5AccountStats
    base=dict(account='123',automation_v1=True,automation_ready=True,automation_protection_v1=True,automation_positions=[])
    api['ea_report_stats'](base,db)
    st=db.query(MT5AccountStats).one()
    assert st.automation_positions==[] and st.automation_protection_v1 is True
    from fastapi import HTTPException
    for changes in [dict(automation_v1='true'),dict(automation_positions=None),dict(automation_positions=[{'symbol':'EURUSD.a','open_positions':-1}]),dict(automation_positions=[{'symbol':'EURUSD.a','open_positions':1},{'symbol':'EURUSD.a','open_positions':0}])]:
        with pytest.raises(HTTPException):api['ea_report_stats']({**base,**changes},db)
    api['ea_report_stats']({'account':'123'},db)
    assert st.automation_v1 is False and st.automation_positions is None



def analysis(now, score=80, recommendation='COMPRA FORTE'):
    return dict(symbol='EURUSD', recommendation=recommendation, last_price=1.1,
        score=dict(final_score=score, confidence=40), technical_votes={'rsi':1},
        price_history=[dict(trade_date=(now-timedelta(days=i)).date().isoformat(),
                            open=1.1, high=1.2, low=1, close=1.1) for i in range(29,-1,-1)])


def test_valid_analysis_requires_real_recent_bars_and_consistent_measured_score():
    from app.application.mt5_automation import validated_signal
    now=datetime.now(timezone.utc); data=analysis(now)
    assert validated_signal(data,'EURUSD',now)=='COMPRA FORTE'
    for changed in [dict(price_history=[]), dict(price_history=data['price_history'][:13]),
                    dict(last_price=None),dict(technical_votes={}),dict(symbol='OTHER'),
                    dict(score=dict(final_score=float('nan'),confidence=40)),
                    dict(score=dict(final_score=69,confidence=40)),
                    dict(score=dict(final_score=80,confidence=None)),
                    dict(price_history=analysis(now-timedelta(days=10))['price_history'])]:
        assert validated_signal({**data,**changed},'EURUSD',now) is None
    assert validated_signal(analysis(now,29,'VENDA FORTE'),'EURUSD',now)=='VENDA FORTE'
    assert validated_signal(analysis(now,30,'VENDA FORTE'),'EURUSD',now) is None


def test_runner_persists_baseline_failed_analysis_does_not_rearm_and_revokes(db,owned):
    from app.application.mt5_automation import run_observations
    from app.infrastructure.database.models import MT5AccountStats, MT5Command, WatchlistItem
    from sqlalchemy import select
    now=datetime.now(timezone.utc);r=rule(db)
    db.add(MT5AccountStats(id='st',account_number='123',automation_v1=True,automation_ready=True,
        automation_protection_v1=True,automation_positions=[],updated_at=now)); db.commit()
    run=lambda data: run_observations(db,lambda symbol,db,user:data,now)
    run(analysis(now));db.expire_all()
    assert r.initialized and not r.ready
    run(None);run(analysis(now))
    assert db.scalars(select(MT5Command)).all()==[]
    run(analysis(now,50,'NEUTRO'));run(analysis(now))
    cmd=db.scalars(select(MT5Command)).one()
    assert cmd.status=='pending'
    db.delete(db.get(WatchlistItem,'w')); db.commit()
    run(analysis(now))
    assert cmd.status=='revoked'


def test_poll_legacy_and_zero_flags_skip_auto_but_deliver_manual(db,owned):
    from app.application.mt5_automation import observe_signal
    from app.infrastructure.database.models import MT5AccountStats,MT5Command
    now=datetime.now(timezone.utc);r=rule(db)
    db.add(MT5AccountStats(id='st',account_number='123',automation_v1=True,automation_ready=True,
        automation_protection_v1=True,automation_positions=[],updated_at=now));db.flush()
    observe_signal(db,r,'NEUTRO','123',now);auto=observe_signal(db,r,'COMPRA FORTE','123',now)
    manual=MT5Command(id='manual',user_id='u',account_number='123',action='buy',symbol='OTHER',volume=Decimal('.10'),status='pending')
    db.add(manual);db.flush();poll=route_functions()['ea_poll_commands']
    assert [c['id'] for c in poll('123','test',db)['items']]==['manual']
    assert auto.status=='pending'
    for flags in [('1','1','0'),('1',None,'1'),('true','1','1')]:
        assert poll('123','test',db,*flags)['items']==[]
    assert auto.status=='pending'
    assert poll('123','test',db,'1','1','1')['items'][0]['id']==auto.id
