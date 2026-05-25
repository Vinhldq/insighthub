from arq import create_pool
from arq.connections import RedisSettings
from app.core.config import get_settings

settings = get_settings()

async def get_redis_pool():
    """Tạo hoặc lấy Redis pool cho ARQ."""
    return await create_pool(RedisSettings.from_dsn(settings.redis_url))
