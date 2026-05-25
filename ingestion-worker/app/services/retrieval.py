"""
InsightHub API — Retrieval service
Vector similarity search trên pgvector dùng HNSW index + cosine distance.
"""
import logging

from app.core.config import get_settings
from app.core.db import get_conn
from app.services.embeddings import embed

logger = logging.getLogger("insighthub.retrieval")
settings = get_settings()


def retrieve(question: str, top_k: int | None = None) -> list[dict]:
    """Embed câu hỏi → tìm top-k chunk gần nhất bằng cosine distance."""
    k = top_k or settings.retrieval_top_k
    query_vec = embed([question], input_type="query")[0]

    with get_conn() as conn:
        # Tune HNSW search width cho recall
        conn.execute(f"SET hnsw.ef_search = {settings.hnsw_ef_search}")
        rows = conn.execute(
            """
            SELECT
                c.id,
                c.chunk_text,
                d.filename AS source,
                1 - (c.embedding <=> %s::vector) AS similarity
            FROM chunks c
            JOIN documents d ON d.id = c.document_id
            WHERE d.status = 'ready'
            ORDER BY c.embedding <=> %s::vector
            LIMIT %s
            """,
            (query_vec, query_vec, k),
        ).fetchall()

    return [
        {
            "id": r[0],
            "chunk_text": r[1],
            "source": r[2],
            "similarity": round(float(r[3]), 4),
        }
        for r in rows
    ]
