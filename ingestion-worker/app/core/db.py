"""
InsightHub API — Database layer
psycopg3 connection pool + pgvector. Schema khởi tạo từ infra/db/init.sql.
"""
import logging
from contextlib import contextmanager

from psycopg_pool import ConnectionPool
from pgvector.psycopg import register_vector

from app.core.config import get_settings

logger = logging.getLogger("insighthub.db")
settings = get_settings()

_pool: ConnectionPool | None = None


def _configure(conn):
    """Đăng ký pgvector type cho mỗi connection mới."""
    register_vector(conn)


def get_pool() -> ConnectionPool:
    global _pool
    if _pool is None:
        _pool = ConnectionPool(
            conninfo=settings.database_url,
            min_size=2,
            max_size=10,
            configure=_configure,
            open=True,
        )
        logger.info("Database pool initialized")
    return _pool


@contextmanager
def get_conn():
    pool = get_pool()
    with pool.connection() as conn:
        yield conn


def healthcheck() -> bool:
    try:
        with get_conn() as conn:
            conn.execute("SELECT 1")
        return True
    except Exception as exc:  # noqa: BLE001
        logger.error("DB healthcheck failed: %s", exc)
        return False


def close_pool():
    global _pool
    if _pool is not None:
        _pool.close()
        _pool = None
