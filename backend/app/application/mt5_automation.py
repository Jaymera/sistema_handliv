"""Fail-closed favorite automation; all database changes share the caller transaction."""
from decimal import Decimal, InvalidOperation
from datetime import datetime, timezone, timedelta
from sqlalchemy import select
from app.infrastructure.database.models import MT5AutomationRule, MT5AutomationEvent, MT5Command

STRONG = {'COMPRA FORTE': 'buy', 'VENDA FORTE': 'sell'}
VALID_SIGNALS = {*STRONG, 'NEUTRO', 'COMPRA MODERADA', 'VENDA MODERADA'}
MAGIC = '20261002'


def observe_signal(db, rule, signal, account_number, now):
    if signal not in VALID_SIGNALS:
        rule.last_status = 'invalid_analysis'
        return None
    rule.last_signal = signal
    if not rule.initialized:
        rule.initialized = True
        rule.ready = signal not in STRONG
        rule.last_status = 'baseline'
        return None
    if signal not in STRONG:
        if not rule.ready:
            rule.generation += 1
        rule.ready = True
        rule.last_status = 'armed'
        return None
    if not rule.ready:
        return None
    rule.ready = False
    action = STRONG[signal]
    if rule.direction not in ('both', action):
        rule.last_status = 'direction_blocked'
        return None
    if has_occupancy(db, rule, account_number, now):
        rule.last_status = 'position_unconfirmed'
        return None
    event = MT5AutomationEvent(rule_id=rule.id, generation=rule.generation, signal=signal)
    db.add(event)
    db.flush()  # Unique epoch is a durable second defense in addition to row locking.
    cmd = MT5Command(id=str(__import__('uuid').uuid4()), user_id=rule.user_id,
        account_number=account_number, action=action, symbol=rule.broker_symbol,
        volume=rule.volume, status='pending', automation=True, rule_id=rule.id,
        expires_at=now + timedelta(seconds=120), sl_atr_multiplier=rule.sl_atr_multiplier,
        tp_atr_multiplier=rule.tp_atr_multiplier)
    db.add(cmd)
    rule.last_status = 'pending'
    db.flush()
    return cmd


def parse_volume(value):
    try:
        if isinstance(value, bool) or value is None:
            raise ValueError('volume inválido')
        amount = Decimal(str(value))
        if not amount.is_finite() or not Decimal('0') < amount <= Decimal('99999999.99'):
            raise ValueError('volume inválido')
        if amount != amount.quantize(Decimal('0.01')):
            raise ValueError('volume deve ter no máximo 2 casas decimais')
        return amount.quantize(Decimal('0.01'))
    except (InvalidOperation, TypeError):
        raise ValueError('volume inválido')


def require_plan(db, user):
    from fastapi import HTTPException
    if user is None or not user.is_active or user.deleted_at is not None:
        raise HTTPException(403, 'usuário inativo')
    if user.role.value != 'super_admin':
        from app.presentation.routers.subscriptions import check_user_plan
        if not check_user_plan(db, user).get('limits', {}).get('auto_robot', False):
            raise HTTPException(403, 'Automação disponível no plano Ultimate')


def account_for(db, user, account_id):
    from fastapi import HTTPException
    from app.infrastructure.database.models import MT5Account
    acc = db.scalar(select(MT5Account).where(MT5Account.id == account_id).with_for_update())
    if acc is None or str(acc.user_id) != str(user.id):
        raise HTTPException(404, 'conta MT5 não encontrada')
    if not acc.is_active:
        raise HTTPException(403, 'conta MT5 inativa')
    return acc


def is_favorite(db, user_id, asset_id):
    # UI favorites are /watchlist, not the currently unused favorites table.
    from app.infrastructure.database.models import WatchlistItem
    return db.scalar(select(WatchlistItem.id).where(WatchlistItem.user_id == user_id, WatchlistItem.asset_id == asset_id)) is not None


def rule_dict(r):
    return dict(id=str(r.id), account_id=str(r.account_id), symbol=r.symbol,
        broker_symbol=r.broker_symbol, direction=r.direction, volume=format(r.volume, '.2f'),
        enabled=r.enabled, last_signal=r.last_signal, last_status=r.last_status, **protection_dict(r))


def list_rules(db, user, account_id):
    require_plan(db, user)
    account_for(db, user, account_id)
    rows = db.scalars(select(MT5AutomationRule).where(MT5AutomationRule.user_id == user.id,
        MT5AutomationRule.account_id == account_id).order_by(MT5AutomationRule.symbol)).all()
    return {'items': [rule_dict(r) for r in rows if is_favorite(db, user.id, r.asset_id)]}


def put_rule(db, user, symbol, payload):
    from fastapi import HTTPException
    from app.infrastructure.database.models import Asset
    require_plan(db, user)
    acc = account_for(db, user, payload.get('account_id'))
    asset = db.scalar(select(Asset).where(Asset.symbol == symbol.upper(), Asset.is_active == True))
    if asset is None or not is_favorite(db, user.id, asset.id):
        raise HTTPException(404, 'ativo favorito não encontrado')
    broker = payload.get('broker_symbol')
    direction = payload.get('direction')
    enabled = payload.get('enabled', False)
    if not isinstance(broker, str) or not broker or broker != broker.strip() or len(broker) > 32 or any(ord(c) < 33 for c in broker):
        raise HTTPException(400, 'broker_symbol exato é obrigatório')
    if direction not in ('buy', 'sell', 'both') or not isinstance(enabled, bool):
        raise HTTPException(400, 'direction/enabled inválido')
    try:
        sl, tp = parse_protection(payload, enabled)
        volume = parse_volume(payload.get('volume'))
    except ValueError as exc:
        raise HTTPException(400, str(exc))
    r = db.scalar(select(MT5AutomationRule).where(MT5AutomationRule.user_id == user.id,
        MT5AutomationRule.account_id == acc.id, MT5AutomationRule.asset_id == asset.id).with_for_update())
    if r is None:
        r = MT5AutomationRule(user_id=user.id, account_id=acc.id, asset_id=asset.id,
            symbol=asset.symbol, enabled=False, initialized=False, ready=False, generation=0)
        db.add(r)
    changed = (r.broker_symbol, r.direction, r.volume, r.sl_atr_multiplier, r.tp_atr_multiplier) != (broker, direction, volume, sl, tp)
    if not enabled or changed or not r.enabled:
        if r.id:
            revoke_pending(db, r, 'revoked')
        r.initialized = False
        r.ready = False
        r.generation += 1
        r.last_signal = None
        r.last_status = 'awaiting_baseline' if enabled else 'disabled'
    r.broker_symbol, r.direction, r.volume, r.enabled = broker, direction, volume, enabled
    r.sl_atr_multiplier, r.tp_atr_multiplier = sl, tp
    db.flush()
    return rule_dict(r)


def revoke_pending(db, rule, reason):
    for cmd in db.scalars(select(MT5Command).where(MT5Command.rule_id == rule.id,
            MT5Command.automation == True, MT5Command.status == 'pending').with_for_update()):
        cmd.status = reason
        cmd.result_message = reason
    rule.last_status = reason


def utc(value):
    return value.replace(tzinfo=timezone.utc) if value and value.tzinfo is None else value


def dispatch_allowed(db, rule, now):
    from fastapi import HTTPException
    from app.infrastructure.database.models import User, MT5AccountStats, Asset
    try:
        user = db.get(User, rule.user_id)
        require_plan(db, user)
        acc = account_for(db, user, rule.account_id)
    except HTTPException:
        rule.last_status = 'account_or_plan_blocked'
        return False
    asset = db.get(Asset, rule.asset_id)
    if not rule.enabled or asset is None or not asset.is_active or not is_favorite(db, rule.user_id, rule.asset_id):
        rule.last_status = 'disabled_or_removed'
        return False
    st = db.scalar(select(MT5AccountStats).where(MT5AccountStats.account_number == acc.account_number))
    if st is None or st.automation_v1 is not True or st.automation_ready is not True or st.automation_protection_v1 is not True or not st.updated_at or not 0 <= (now-utc(st.updated_at)).total_seconds() <= 90:
        rule.last_status = 'ea_not_ready'
        return False
    if not flat_snapshot(st, rule.broker_symbol, now):
        rule.last_status = 'position_open_or_unknown'
        return False
    return True


def command_allowed(db, cmd, now):
    if not cmd.automation:
        return True
    rule = db.scalar(select(MT5AutomationRule).where(MT5AutomationRule.id == cmd.rule_id).with_for_update())
    reason = None
    if cmd.expires_at is None or utc(cmd.expires_at) <= now:
        reason = 'expired'
    elif rule is None or not dispatch_allowed(db, rule, now):
        reason = 'revoked'
    else:
        from app.infrastructure.database.models import MT5Account
        acc = db.get(MT5Account, rule.account_id)
        if cmd.account_number != acc.account_number or str(cmd.user_id) != str(rule.user_id) or cmd.symbol != rule.broker_symbol or cmd.volume != rule.volume or rule.direction not in ('both', cmd.action):
            reason = 'revoked'
    if reason:
        cmd.status = reason
        cmd.result_message = reason
        if rule:
            rule.last_status = reason
        return False
    return True


def parse_protection(payload, enabled):
    keys = ('stop_mode', 'atr_period', 'atr_timeframe', 'sl_atr_multiplier', 'tp_atr_multiplier')
    if enabled and any(k not in payload for k in keys):
        raise ValueError('proteção SL/TP obrigatória')
    if payload.get('stop_mode', 'atr') != 'atr' or type(payload.get('atr_period', 14)) is not int or payload.get('atr_period', 14) != 14 or payload.get('atr_timeframe', 'H1') != 'H1':
        raise ValueError('proteção deve usar ATR14 H1')
    sl = parse_volume(payload.get('sl_atr_multiplier', '2.00'))
    tp = parse_volume(payload.get('tp_atr_multiplier', '3.00'))
    if not Decimal('.10') <= sl <= Decimal('20') or not Decimal('.10') <= tp <= Decimal('20'):
        raise ValueError('multiplicador ATR deve estar entre 0.10 e 20.00')
    return sl, tp


def protection_dict(obj):
    return dict(stop_mode='atr', atr_period=14, atr_timeframe='H1',
        sl_atr_multiplier=format(obj.sl_atr_multiplier, '.2f'),
        tp_atr_multiplier=format(obj.tp_atr_multiplier, '.2f'))


def flat_snapshot(st, symbol, now, after=None):
    """An explicit, fresh, complete magic snapshot newer than the execution.

    A missing/legacy field is never read as flat, and positions of other symbols
    never block. Pending/sent occupancy is handled separately (always blocking).
    """
    if st is None or st.automation_v1 is not True or st.automation_ready is not True or st.automation_protection_v1 is not True or not isinstance(st.automation_positions, list):
        return False
    if not st.updated_at or not 0 <= (now-utc(st.updated_at)).total_seconds() <= 90:
        return False
    if after is not None and utc(st.updated_at) <= utc(after):
        return False
    return not any(p.get('symbol') == symbol and (p.get('open_positions') or 0) > 0 for p in st.automation_positions)


def has_occupancy(db, rule, account_number, now):
    from app.infrastructure.database.models import MT5AccountStats
    commands = db.scalars(select(MT5Command).where(MT5Command.automation == True,
        MT5Command.account_number == account_number, MT5Command.symbol == rule.broker_symbol,
        MT5Command.status.in_(('pending','sent','executed')))).all()
    st = db.scalar(select(MT5AccountStats).where(MT5AccountStats.account_number == account_number))
    for cmd in commands:
        if cmd.status == 'pending' and cmd.expires_at and utc(cmd.expires_at) <= now:
            cmd.status = 'expired'
            continue
        if cmd.status in ('pending','sent') or not cmd.executed_at or not flat_snapshot(st, rule.broker_symbol, now, cmd.executed_at):
            return True
    return False


def validate_stats_automation(payload):
    """Explicit complete magic snapshot; legacy packets erase stored readiness."""
    from fastapi import HTTPException
    keys = ('automation_v1', 'automation_protection_v1', 'automation_ready')
    result = {}
    for key in keys:
        value = payload.get(key, False)
        if type(value) is not bool:
            raise HTTPException(400, f'{key} inválido')
        result[key] = value
    positions = payload.get('automation_positions')
    if 'automation_positions' in payload:
        if not isinstance(positions, list) or len(positions) > 256:
            raise HTTPException(400, 'automation_positions deve ser a lista completa')
        seen = set()
        for item in positions:
            if not isinstance(item, dict):
                raise HTTPException(400, 'posição inválida')
            symbol, count = item.get('symbol'), item.get('open_positions')
            if not isinstance(symbol, str) or not symbol or len(symbol) > 32 or any(ord(c) < 33 for c in symbol) or symbol in seen:
                raise HTTPException(400, 'posição inválida ou duplicada')
            if type(count) is not int or not 0 <= count <= 2147483647:
                raise HTTPException(400, 'open_positions inválido')
            seen.add(symbol)
        positions = [dict(symbol=p['symbol'], open_positions=p['open_positions']) for p in positions]
    if 'automation_positions' not in payload:
        positions = None
    result['automation_positions'] = positions
    if not all(k in payload for k in keys) or positions is None:
        result['automation_ready'] = False
    return result


def validated_signal(data, symbol, now):
    """Validate canonical live-analysis evidence, not its empty-data fallbacks.

    Daily provider bars allow weekends (latest <= four days) and require 14
    actual distinct dated OHLC bars; the canonical response exposes 30.
    """
    import math
    from datetime import date
    def number(value, low, high):
        return type(value) in (int, float) and math.isfinite(value) and low <= value <= high
    if not isinstance(data, dict) or data.get('symbol') != symbol:
        return None
    score = data.get('score')
    if not isinstance(score, dict) or not number(score.get('final_score'), 0, 100) or not number(score.get('confidence'), 0, 100):
        return None
    if not number(data.get('last_price'), 0.000000000001, float('inf')):
        return None
    votes = data.get('technical_votes')
    if not isinstance(votes, dict) or not votes or any(type(v) is not int or v not in (-1, 0, 1) for v in votes.values()):
        return None
    bars = data.get('price_history')
    if not isinstance(bars, list) or len(bars) < 14:
        return None
    dates = []
    try:
        for bar in bars:
            day = date.fromisoformat(bar['trade_date'])
            if any(not number(bar.get(k), 0.000000000001, float('inf')) for k in ('open', 'high', 'low', 'close')):
                return None
            if bar['low'] > bar['high'] or bar['low'] > min(bar['open'], bar['close']) or bar['high'] < max(bar['open'], bar['close']):
                return None
            dates.append(day)
        if dates != sorted(set(dates)) or not 0 <= (now.date() - dates[-1]).days <= 4 or (dates[-1] - dates[-14]).days > 45:
            return None
    except (KeyError, TypeError, ValueError):
        return None
    value = score['final_score']
    expected = ('COMPRA FORTE' if value >= 70 else 'COMPRA MODERADA' if value >= 55 else
                'NEUTRO' if value >= 45 else 'VENDA MODERADA' if value >= 30 else 'VENDA FORTE')
    return expected if data.get('recommendation') == expected else None


def run_observations(db, analyze=None, now=None):
    """Existing worker entrypoint: account then rule locks serialize every consumer.

    Analysis failure never changes the durable baseline/edge latch, and each
    account commits independently. No new scheduler process or trading engine.
    """
    import logging
    from app.infrastructure.database.models import MT5Account, User
    if analyze is None:
        from app.presentation.routers.assets import live_analysis
        analyze = live_analysis
    now = now or datetime.now(timezone.utc)
    account_ids = list(db.scalars(select(MT5AutomationRule.account_id).distinct()))
    db.commit()
    observed = commands = 0
    for account_id in account_ids:
        try:
            acc = db.scalar(select(MT5Account).where(MT5Account.id == account_id).with_for_update())
            rules = db.scalars(select(MT5AutomationRule).where(MT5AutomationRule.account_id == account_id)
                               .order_by(MT5AutomationRule.id).with_for_update()).all()
            for rule in rules:
                for cmd in db.scalars(select(MT5Command).where(MT5Command.rule_id == rule.id,
                        MT5Command.automation == True, MT5Command.status == 'pending').with_for_update()):
                    command_allowed(db, cmd, now)
                if acc is None or not dispatch_allowed(db, rule, now):
                    if rule.last_status in ('disabled_or_removed', 'account_or_plan_blocked'):
                        revoke_pending(db, rule, 'revoked')
                        if rule.initialized:
                            rule.generation += 1
                        rule.initialized = rule.ready = False
                    continue
                try:
                    data = analyze(symbol=rule.symbol, db=db, user=db.get(User, rule.user_id))
                    signal = validated_signal(data, rule.symbol, now)
                except Exception:
                    logging.getLogger(__name__).exception('Automation analysis failed for rule %s', rule.id)
                    signal = None
                cmd = observe_signal(db, rule, signal, acc.account_number, now)
                observed += 1
                commands += int(cmd is not None)
            db.commit()
        except Exception:
            db.rollback()
            logging.getLogger(__name__).exception('Automation observation rolled back for account %s', account_id)
    return dict(observed=observed, commands=commands)
