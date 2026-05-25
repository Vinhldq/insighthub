import logging
from arq.connections import RedisSettings
from tenacity import retry, stop_after_attempt, wait_exponential
from app.services.ingestion import process_document
from app.core.config import get_settings

logger = logging.getLogger("insighthub.worker")
settings = get_settings()

@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=2, max=10),
    reraise=True
)
def _process_with_retry(document_id: int, filename: str, content: bytes):
    return process_document(document_id, filename, content)

async def ingest_document_task(ctx, document_id: int, filename: str, content: bytes):
    """ARQ task để xử lý tài liệu với retry."""
    logger.info(f"Bắt đầu xử lý tài liệu {document_id}: {filename}")
    try:
        # Gọi hàm process với cơ chế retry
        result = _process_with_retry(document_id, filename, content)
        logger.info(f"Hoàn thành xử lý tài liệu {document_id}. Số chunk: {result}")
        return result
    except Exception as e:
        logger.error(f"Lỗi khi xử lý tài liệu {document_id} sau 3 lần thử: {e}")
        # Cập nhật trạng thái failed nếu tất cả các lần thử đều thất bại
        from app.services.ingestion import _update_status
        _update_status(document_id, "failed")
        raise

class WorkerSettings:
    """Cấu hình cho ARQ worker."""
    functions = [ingest_document_task]
    redis_settings = RedisSettings.from_dsn(settings.redis_url)
    on_startup = None
    on_shutdown = None
