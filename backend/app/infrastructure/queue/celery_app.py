from __future__ import annotations

from celery import Celery
from celery.schedules import crontab

from app.config import settings


celery_app = Celery(
    "handliv",
    broker=settings.redis_url,
    backend=settings.redis_url,
    include=[
        "app.infrastructure.queue.tasks.fetch_prices",
        "app.infrastructure.queue.tasks.compute_scores",
        "app.infrastructure.queue.tasks.fetch_news",
        "app.infrastructure.queue.tasks.run_backtest",
    ],
)

celery_app.conf.update(
    task_track_started=True,
    task_time_limit=1800,
    task_soft_time_limit=1500,
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="America/Sao_Paulo",
    enable_utc=True,
)


def _beat_schedule() -> dict:
    """Static beat schedule. yfinance fetches at HH:MM Brasília time, plus score computation
    after each fetch, and news refresh every 2 hours during business hours."""
    beat: dict = {}
    for i, hhmm in enumerate(settings.fetch_times_list):
        if ":" not in hhmm:
            continue
        hh, mm = hhmm.split(":", 1)
        try:
            beat[f"fetch-prices-{i}"] = crontab(hour=int(hh), minute=int(mm))
        except ValueError:
            continue
    schedule: dict = {}
    for name, crontab_v in beat.items():
        schedule[name] = {
            "task": "app.infrastructure.queue.tasks.fetch_prices.fetch_all_prices",
            "schedule": crontab_v,
        }
    schedule["fetch-news"] = {
        "task": "app.infrastructure.queue.tasks.fetch_news.fetch_all_news",
        "schedule": crontab(minute=0, hour="8,10,12,14,16,18"),
    }
    return schedule


celery_app.conf.beat_schedule = _beat_schedule()