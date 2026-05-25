"""
InsightHub API — Embeddings service (provider-agnostic)

Provider: gemini (default) | voyage | openai | ollama | local
Đổi qua env EMBEDDING_PROVIDER, không sửa call-site.

EMBEDDING_DIM phải khớp VECTOR(n) trong infra/db/init.sql.
- Gemini: Matryoshka, hỗ trợ output_dimensionality tùy chỉnh (default code = 1024).
- Voyage 3.5: native 1024.
- OpenAI text-embedding-3-small: native 1536 (đổi schema nếu dùng).
- Ollama deepseek-r1:14b: native ~5120, truncate xuống EMBEDDING_DIM với L2-normalize.
- local: hash-based fallback, deterministic, chất lượng kém — chỉ để smoke test.
"""
import hashlib
import logging
import struct
from typing import Iterable

import httpx
from tenacity import retry, stop_after_attempt, wait_exponential

from app.core.config import get_settings

logger = logging.getLogger("insighthub.embeddings")
settings = get_settings()


# ============================================================
# Local fallback (hash-based, KHÔNG dùng production)
# ============================================================
def _local_embed(texts: list[str], dim: int) -> list[list[float]]:
    """
    Fallback embedding deterministic. Pipeline chạy được mà không cần API key
    hay Ollama. Chất lượng retrieval rất thấp — chỉ phù hợp smoke test.
    """
    vectors = []
    for text in texts:
        digest = hashlib.sha256(text.encode("utf-8")).digest()
        raw = (digest * ((dim * 4 // len(digest)) + 1))[: dim * 4]
        vec = list(struct.unpack(f"{dim}f", raw))
        norm = sum(v * v for v in vec) ** 0.5 or 1.0
        vectors.append([v / norm for v in vec])
    return vectors


# ============================================================
# Helper: truncate + L2-normalize (cho Ollama / Matryoshka adjust)
# ============================================================
def _truncate_normalize(vec: Iterable[float], dim: int) -> list[float]:
    """
    Lấy `dim` chiều đầu tiên + L2-normalize. Đây là cách rút gọn embedding
    chuẩn (Matryoshka-style) khi model trả nhiều chiều hơn target schema.
    """
    truncated = list(vec)[:dim]
    # Pad nếu vec ngắn hơn dim
    if len(truncated) < dim:
        truncated += [0.0] * (dim - len(truncated))
    norm = sum(v * v for v in truncated) ** 0.5 or 1.0
    return [v / norm for v in truncated]


# ============================================================
# Gemini provider (default)
# ============================================================
@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
def _gemini_embed(texts: list[str], input_type: str) -> list[list[float]]:
    """
    Gemini Embeddings API. Hỗ trợ Matryoshka — config output_dimensionality
    để khớp VECTOR(n) trong DB.
    Ref: https://ai.google.dev/gemini-api/docs/embeddings
    """
    from google import genai
    from google.genai import types

    client = genai.Client(api_key=settings.gemini_api_key)
    model_name = settings.resolved_embedding_model

    # Gemini task_type: 'RETRIEVAL_DOCUMENT' khi ingest, 'RETRIEVAL_QUERY' khi search.
    task_type = "RETRIEVAL_QUERY" if input_type == "query" else "RETRIEVAL_DOCUMENT"

    resp = client.models.embed_content(
        model=model_name,
        contents=texts,
        config=types.EmbedContentConfig(
            task_type=task_type,
            output_dimensionality=settings.embedding_dim,
        ),
    )
    # resp.embeddings là list ContentEmbedding(values=[...])
    return [list(emb.values) for emb in resp.embeddings]


# ============================================================
# Voyage provider
# ============================================================
@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
def _voyage_embed(texts: list[str], input_type: str) -> list[list[float]]:
    import voyageai

    client = voyageai.Client(api_key=settings.voyage_api_key)
    result = client.embed(
        texts, model=settings.resolved_embedding_model, input_type=input_type
    )
    return result.embeddings


# ============================================================
# OpenAI provider
# ============================================================
@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
def _openai_embed(texts: list[str]) -> list[list[float]]:
    from openai import OpenAI

    client = OpenAI(api_key=settings.openai_api_key)
    resp = client.embeddings.create(model=settings.resolved_embedding_model, input=texts)
    return [d.embedding for d in resp.data]


# ============================================================
# Ollama provider (local — deepseek-r1:14b mặc định)
# ============================================================
@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
def _ollama_embed(texts: list[str]) -> list[list[float]]:
    """
    Ollama embedding qua /api/embed. Model phải đã pull trước:
       ollama pull deepseek-r1:14b
    Ref: https://github.com/ollama/ollama/blob/main/docs/api.md#generate-embeddings

    LƯU Ý: deepseek-r1:14b là model reasoning, dim native ~5120. Ta truncate
    xuống EMBEDDING_DIM (1024) bằng Matryoshka-style. Chất lượng retrieval
    không bằng embedding model chuyên dụng — nhưng đủ cho lab on-prem.
    """
    url = f"{settings.ollama_base_url.rstrip('/')}/api/embed"
    model_name = settings.resolved_embedding_model

    with httpx.Client(timeout=120.0) as client:
        resp = client.post(url, json={"model": model_name, "input": texts})
        resp.raise_for_status()
        data = resp.json()

    raw_embeddings = data.get("embeddings", [])
    return [_truncate_normalize(vec, settings.embedding_dim) for vec in raw_embeddings]


# ============================================================
# Dispatcher
# ============================================================
def embed(texts: list[str], input_type: str = "document") -> list[list[float]]:
    """
    input_type: 'document' khi ingest, 'query' khi search.
    Provider-specific: Gemini + Voyage tận dụng input_type; OpenAI/Ollama/local bỏ qua.

    Khi provider config thiếu credentials hoặc lỗi runtime → fallback local.
    """
    if not texts:
        return []

    provider = settings.embedding_provider.lower()

    try:
        if provider == "gemini":
            if not settings.gemini_api_key:
                logger.warning("EMBEDDING_PROVIDER=gemini nhưng GEMINI_API_KEY trống — fallback local")
                return _local_embed(texts, settings.embedding_dim)
            return _gemini_embed(texts, input_type)

        if provider == "voyage":
            if not settings.voyage_api_key:
                logger.warning("EMBEDDING_PROVIDER=voyage nhưng VOYAGE_API_KEY trống — fallback local")
                return _local_embed(texts, settings.embedding_dim)
            return _voyage_embed(texts, input_type)

        if provider == "openai":
            if not settings.openai_api_key:
                logger.warning("EMBEDDING_PROVIDER=openai nhưng OPENAI_API_KEY trống — fallback local")
                return _local_embed(texts, settings.embedding_dim)
            return _openai_embed(texts)

        if provider == "ollama":
            return _ollama_embed(texts)

        if provider == "local":
            return _local_embed(texts, settings.embedding_dim)

        logger.warning("Unsupported EMBEDDING_PROVIDER='%s' — fallback local", provider)
        return _local_embed(texts, settings.embedding_dim)

    except Exception as exc:  # noqa: BLE001
        logger.error("Embedding failed (%s): %s — fallback local", provider, exc)
        return _local_embed(texts, settings.embedding_dim)
