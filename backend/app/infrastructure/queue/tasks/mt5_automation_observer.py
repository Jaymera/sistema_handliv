# Persistent periodic automation runner using Celery beat
from app.infrastructure.queue.celery_app import celery_app
from app.infrastructure.database.session import SessionLocal
from app.application.mt5_automation import run_observations
from datetime import datetime, timezone

@celery_app.task(name='mt5_automation.observe_signals', ignore_result=True)
def mt5_automation_observe_signals():
    db = SessionLocal()
    try:
        run_observations(db, now=datetime.now(timezone.utc))
    except Exception:
        db.rollback()
        import logging
        logging.getLogger(__name__).exception('Automation runner task failed')
    finally:
        db.close()
