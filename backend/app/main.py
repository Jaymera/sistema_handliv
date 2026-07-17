from contextlib import asynccontextmanager
from collections.abc import AsyncIterator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.infrastructure.database.session import engine
from app.infrastructure.database.bootstrap import bootstrap_super_admin
from app.presentation.routers import auth, assets, watchlist, alerts, backtests, files, admin, notifications, health, plans, subscriptions, ws
from app.presentation.middleware.logging import LoggingMiddleware


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    try:
        bootstrap_super_admin()
    except Exception as exc:  # don't crash the app if DB is unavailable at startup
        import logging

        logging.getLogger("handliv.startup").warning("bootstrap_super_admin skipped: %s", exc)
    try:
        from app.infrastructure.database.bootstrap import seed_assets
        seed_assets()
    except Exception as exc:
        import logging

        logging.getLogger("handliv.startup").warning("seed_assets skipped: %s", exc)
    yield


def create_app() -> FastAPI:
    app = FastAPI(
        title="Handliv Trading Intelligence",
        version="0.1.0",
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(LoggingMiddleware)

    app.include_router(health.router, prefix="/api/v1", tags=["health"])
    app.include_router(auth.router, prefix="/api/v1", tags=["auth"])
    app.include_router(plans.router, prefix="/api/v1", tags=["plans"])
    app.include_router(subscriptions.router, prefix="/api/v1", tags=["subscriptions"])
    app.include_router(assets.router, prefix="/api/v1", tags=["assets"])
    app.include_router(watchlist.router, prefix="/api/v1", tags=["watchlist"])
    app.include_router(alerts.router, prefix="/api/v1", tags=["alerts"])
    app.include_router(backtests.router, prefix="/api/v1", tags=["backtests"])
    app.include_router(files.router, prefix="/api/v1", tags=["files"])
    app.include_router(notifications.router, prefix="/api/v1", tags=["notifications"])
    app.include_router(admin.router, prefix="/api/v1/admin", tags=["admin"])
    app.include_router(ws.router, prefix="/api/v1", tags=["ws"])

    return app


app = create_app()