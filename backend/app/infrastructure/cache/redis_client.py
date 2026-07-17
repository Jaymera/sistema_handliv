"""Redis cache client (sync, with fakeredis fallback for local dev)."""

from __future__ import annotations

import json
import logging
from typing import Any

import redis
from redis.exceptions import RedisError

from app.config import settings

logger = logging.getLogger(__name__)


def _make_client() -> redis.Redis:
    try:
        c = redis.Redis.from_url(settings.redis_url, decode_responses=True)
        c.ping()
        return c
    except Exception as exc:
        logger.warning("Redis indisponivel (%s), usando fakeredis como fallback local", exc)
        try:
            import fakeredis

            return fakeredis.FakeRedis(decode_responses=True)
        except ImportError:
            raise RuntimeError("Redis e fakeredis ambos indisponiveis") from exc


_client = _make_client()


def get_redis() -> redis.Redis:
    return _client


class Cache:
    """Tiny wrapper around redis with JSON serialization and graceful failures."""

    def __init__(self, client: redis.Redis) -> None:
        self.client = client

    def get_json(self, key: str, default: Any = None) -> Any:
        try:
            raw = self.client.get(key)
        except RedisError:
            return default
        if raw is None:
            return default
        try:
            return json.loads(raw)
        except (TypeError, ValueError):
            return default

    def set_json(self, key: str, value: Any, ttl_seconds: int | None = None) -> None:
        try:
            data = json.dumps(value, default=str)
            if ttl_seconds:
                self.client.setex(key, ttl_seconds, data)
            else:
                self.client.set(key, data)
        except (TypeError, RedisError):
            pass

    def delete(self, *keys: str) -> None:
        try:
            self.client.delete(*keys)
        except RedisError:
            pass

    def invalidate_pattern(self, pattern: str) -> None:
        try:
            for k in self.client.scan_iter(pattern):
                self.client.delete(k)
        except RedisError:
            pass


cache = Cache(_client)