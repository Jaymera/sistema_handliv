from __future__ import annotations

import logging
from datetime import date, datetime, timezone
from decimal import Decimal

import pandas as pd
import pandas_ta as ta  # type: ignore
from backtesting import Backtest, Strategy
from sqlalchemy import select

from app.infrastructure.database.models import Asset, Backtest, BacktestStatus, BacktestTrade
from app.infrastructure.database.session import SessionLocal
from app.infrastructure.providers.market_data import provider as market_data
from app.infrastructure.queue.celery_app import celery_app

logger = logging.getLogger(__name__)


class _MotorStrategy(Strategy):
    """Backtest lib strategy using RSI + EMA cross entry, exit when opposite EMA cross."""

    rsi_period = 14
    ema_fast = 20
    ema_slow = 50

    def init(self):
        close = pd.Series(self.data.Close, index=self.data.index)
        self.rsi = self.I(lambda: ta.rsi(close, length=self.rsi_period).values)
        self.ema_fast_i = self.I(lambda: ta.ema(close, length=self.ema_fast).values)
        self.ema_slow_i = self.I(lambda: ta.ema(close, length=self.ema_slow).values)

    def next(self):
        if self.rsi[-1] is None or pd.isna(self.ema_fast_i[-1]) or pd.isna(self.ema_slow_i[-1]):
            return
        long_signal = self.ema_fast_i[-1] > self.ema_slow_i[-1] and self.rsi[-1] < 70
        short_signal = self.ema_fast_i[-1] < self.ema_slow_i[-1] and self.rsi[-1] > 30

        if long_signal and not self.position:
            self.buy()
        elif short_signal and self.position:
            self.position.close()


@celery_app.task(name="app.infrastructure.queue.tasks.run_backtest.run_backtest")
def run_backtest(backtest_id: str) -> str:
    db = SessionLocal()
    try:
        bt = db.get(Backtest, backtest_id)
        if bt is None:
            return "missing"
        bt.status = BacktestStatus.RUNNING
        db.commit()
        try:
            base_period = "5y"
            bars = market_data.fetch_history(bt.asset.symbol, timeframe=bt.timeframe, period=base_period)
            if not bars:
                bt.status = BacktestStatus.FAILED
                bt.error = "no market data"
                db.commit()
                return "failed"

            df = pd.DataFrame(bars)
            for col in ("open", "high", "low", "close"):
                df[col] = pd.to_numeric(df[col], errors="coerce")
            df["volume"] = pd.to_numeric(df["volume"], errors="coerce")
            df["date"] = pd.to_datetime(df["trade_date"])
            df = df.set_index("date").sort_index()
            df = df.rename(columns={"open": "Open", "high": "High", "low": "Low", "close": "Close", "volume": "Volume"})
            df = df[(df.index >= pd.to_datetime(bt.start_date)) & (df.index <= pd.to_datetime(bt.end_date))]
            df = df.dropna(subset=["Close", "High", "Low"])

            if len(df) < 60:
                bt.status = BacktestStatus.FAILED
                bt.error = "not enough history in window"
                db.commit()
                return "failed"

            bt_run = Backtest(df, _MotorStrategy, cash=100_000, commission=0.0, exclusive_orders=True)
            stats = bt_run.run()

            bt.total_return_pct = Decimal(str(round(float(stats["Return [%]"]), 4)))
            bt.sharpe = Decimal(str(round(float(stats["Sharpe Ratio"]), 4))) if stats["Sharpe Ratio"] == stats["Sharpe Ratio"] else None
            bt.max_drawdown_pct = Decimal(str(round(abs(float(stats["Max. Drawdown [%]"])), 4)))
            bt.win_rate = Decimal(str(round(float(stats["Win Rate [%]"]), 4))) if stats["# Trades"] else Decimal("0")
            bt.profit_factor = Decimal(str(round(float(stats["Profit Factor"]), 4))) if stats["Profit Factor"] == stats[ "Profit Factor"] else None
            bt.num_trades = int(stats["# Trades"])

            equity_curve = stats["_equity_curve"].reset_index().to_dict("records")
            bt.equity_curve_json = [
                {"date": str(idx), "equity": float(row["Equity"])}
                for idx, row in zip(stats["_equity_curve"].index, stats["_equity_curve"].itertuples(index=False))
            ][:2000]
            bt.drawdown_curve_json = []

            trades = stats["_trades"]
            for t in trades:
                db.add(
                    BacktestTrade(
                        backtest_id=bt.id,
                        entry_date=getattr(t, "EntryTime", datetime.now(timezone.utc)),
                        exit_date=getattr(t, "ExitTime", None),
                        side="buy",
                        entry_price=Decimal(str(float(getattr(t, "EntryPrice", 0)))),
                        exit_price=Decimal(str(float(getattr(t, "ExitPrice", 0)))) if getattr(t, "ExitPrice", None) else None,
                        quantity=Decimal(str(float(getattr(t, "Size", 0)))),
                        pnl=Decimal(str(float(getattr(t, "PnL", 0)))),
                    )
                )

            bt.status = BacktestStatus.COMPLETED
            bt.completed_at = datetime.now(timezone.utc)
            db.commit()
            return "completed"
        except Exception as exc:
            logger.exception("Backtest %s failed: %s", backtest_id, exc)
            db.rollback()
            bt = db.get(Backtest, backtest_id)
            if bt is not None:
                bt.status = BacktestStatus.FAILED
                bt.error = str(exc)[:480]
                db.commit()
            return "failed"
    finally:
        db.close()