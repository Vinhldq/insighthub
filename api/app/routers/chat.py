"""
InsightHub API — Chat router
RAG query: retrieve → generate.
"""
import asyncio
import logging
import time
from functools import partial

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.core.metrics import (
    embedding_tokens_total,
    llm_call_latency,
    llm_tokens_total,
    rag_query_latency,
)
from app.services.llm import generate
from app.services.retrieval import retrieve

logger = logging.getLogger("insighthub.routers.chat")
router = APIRouter(prefix="/chat", tags=["chat"])


class ChatRequest(BaseModel):
    question: str = Field(min_length=1, max_length=2000)
    top_k: int | None = Field(default=None, ge=1, le=20)


class Source(BaseModel):
    filename: str
    similarity: float


class ChatResponse(BaseModel):
    answer: str
    sources: list[Source]
    contexts: list[dict]
    latency_ms: int


@router.post("", response_model=ChatResponse)
async def chat(req: ChatRequest):
    start = time.perf_counter()
    with rag_query_latency.time():
        # Run blocking I/O operations in thread pool to avoid blocking event loop
        loop = asyncio.get_event_loop()
        retrieve_fn = partial(retrieve, req.question, top_k=req.top_k)
        contexts = await loop.run_in_executor(None, retrieve_fn)
        
        if not contexts:
            raise HTTPException(
                404, "Chưa có tài liệu nào sẵn sàng. Hãy upload tài liệu trước."
            )

        llm_start = time.perf_counter()
        generate_fn = partial(generate, req.question, contexts)
        result = await loop.run_in_executor(None, generate_fn)
        llm_call_latency.observe(time.perf_counter() - llm_start)

    # Metrics cho FinOps Day 6
    usage = result.get("usage", {})
    llm_tokens_total.labels(direction="input").inc(usage.get("input_tokens", 0))
    llm_tokens_total.labels(direction="output").inc(usage.get("output_tokens", 0))
    # Embedding token approx (1 query ~ số từ)
    embedding_tokens_total.inc(len(req.question.split()))

    # Build sources with similarity
    # Group by filename, lấy similarity cao nhất
    source_map: dict[str, float] = {}
    for c in contexts:
        fname = c["source"]
        sim = c["similarity"]
        if fname not in source_map or sim > source_map[fname]:
            source_map[fname] = sim
    
    sources = [Source(filename=f, similarity=s) for f, s in source_map.items()]

    latency_ms = int((time.perf_counter() - start) * 1000)
    return ChatResponse(
        answer=result["answer"],
        sources=sources,
        contexts=contexts,
        latency_ms=latency_ms,
    )
