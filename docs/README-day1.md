# Day 1 — RAG Notebook: Foundation

## Mục tiêu

Xây dựng core RAG pipeline: upload tài liệu → chunk → embed → lưu vào pgvector → hỏi đáp bằng LLM.

## Kiến trúc 5 services

```
┌─────────┐     POST /documents      ┌──────────┐     enqueue      ┌──────────────────┐
│   Web   │ ────────────────────────→ │   API    │ ──────────────→ │ Ingestion Worker │
│ :3000   │                            │ :8000    │                  │ (background)     │
└─────────┘                            └──────────┘                  └────────┬─────────┘
                                                                           │
  POST /chat ←──────────────────────────────────────────────────────────────┘
  retrieve(pgvector) + generate(LLM)
```

| Service | Image | Port | Role |
|---------|-------|------|------|
| postgres | pgvector/pgvector:0.8.2-pg16 | 5432 | Vector DB + metadata |
| redis | redis:7-alpine | 6379 | ARQ job queue |
| api | ./api | 8000 | FastAPI: upload → enqueue, /chat retrieve+generate |
| ingestion-worker | ./ingestion-worker | — | ARQ worker: chunk+embed+store |
| web | ./web | 3000 | Next.js 15 dashboard |

## Data Flow

```
Upload:  Web → POST /documents → API → enqueue(redis) → Worker → extract → chunk → embed → pgvector
Query:   Web → POST /chat → API → embed(question) → HNSW cosine search top-k=5 → LLM generate → response
```

## RAG Pipeline

### Ingest
1. `extract_text()` — PDF/TXT/MD → plain text
2. `chunk_text()` — token-based (chunk_size=800, overlap=100)
3. `embed()` — gọi embedding provider → vector float[1024]
4. Lưu vào `chunks` table với pgvector HNSW index

### Query
1. Embed câu hỏi (`input_type='query'`)
2. Vector similarity search HNSW cosine distance, top-k=5
3. LLM generate với context chunks

## LLM Providers

| Provider | Default Model | API Key Env |
|----------|--------------|-------------|
| gemini (default) | gemini-2.0-flash | GEMINI_API_KEY |
| anthropic | claude-sonnet-4-6 | ANTHROPIC_API_KEY |
| ollama | local model | — |

## Embedding Providers

| Provider | Default | Dim | API Key Env |
|----------|---------|-----|-------------|
| gemini (default) | text-embedding-004 | 1024 | GEMINI_API_KEY |
| voyage | voyage-3.5 | 1024 | VOYAGE_API_KEY |
| openai | text-embedding-3-small | 1536 | OPENAI_API_KEY |
| ollama | nomic-embed-text | 768 | — |
| local | hash fallback | 1024 | — |

> **⚠️ EMBEDDING_DIM phải khớp VECTOR(n) trong DB schema.** Đổi provider sang OpenAI → phải đổi thành 1536 + rebuild index.

## DB Schema

```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE documents (
  id BIGSERIAL PRIMARY KEY,
  filename TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','ready','failed')),
  chunk_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE chunks (
  id BIGSERIAL PRIMARY KEY,
  document_id BIGINT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  chunk_text TEXT NOT NULL,
  embedding VECTOR(1024),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- HNSW index — chuẩn production RAG
CREATE INDEX chunks_embedding_hnsw_idx ON chunks USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);
CREATE INDEX chunks_document_id_idx ON chunks(document_id);
CREATE INDEX documents_status_idx ON documents(status);
```

## Commands

```bash
# Start stack
docker compose up --build

# View logs
docker compose logs -f api
docker compose logs -f ingestion-worker

# Run tests
cd api && pytest -xvs

# Format + lint
cd api && ruff format . && ruff check .

# Smoke test (6 checks)
bash scripts/smoke-test.sh

# Verify Day 1
bash scripts/verify-day-1.sh
```

## Artifacts

| Artifact | Description |
|----------|-------------|
| `docker-compose.yml` | 5-service stack |
| `infra/db/init.sql` | DB schema + HNSW index |
| `api/` | FastAPI app |
| `web/` | Next.js 15 dashboard |
| `ingestion-worker/` | ARQ worker |

## Security Notes

- pgvector >= 0.8.2 (CVE-2026-3172, CVSS 8.1)
- `process_document()` phải idempotent — worker retry tối đa 3 lần
- API không sync-call embedding — mọi ingest đi qua queue
