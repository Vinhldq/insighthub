# InsightHub AI Agent Instructions

## 1. Architecture
- **Web**: Next.js 15 App Router (Frontend UI).
- **API**: FastAPI + psycopg3 (API Gateway, Retrieval, LLM Generation).
- **Worker**: Python + ARQ (`ingestion-worker` xử lý chunking & embedding bất đồng bộ).
- **Database**: PostgreSQL 16 + pgvector (Lưu trữ vector và metadata).
- **Queue**: Redis 7 (Message broker quản lý hàng đợi công việc).
- **LLM/Embeddings**: Hỗ trợ nhiều provider (Gemini mặc định, có thể dùng Anthropic/Voyage hoặc Ollama).

## 2. Conventions
- **Python**: Sử dụng `ruff` để định dạng (formatting) và linting. Sử dụng `mypy` để kiểm tra kiểu dữ liệu (strict type checking).
- **Typing**: Bắt buộc phải có type hints đầy đủ trong Python.
- **Asynchronous**: Ưu tiên dùng `async`/`await` cho các thao tác I/O (FastAPI, truy vấn DB, Redis).
- **Commits**: Tuân thủ Conventional Commits (ví dụ: `feat(ingestion): ...`, `fix(api): ...`).
- **PRs**: Thêm tiền tố `[Day N]` vào tiêu đề PR (ví dụ: `[Day 1] Refactor ingestion async + Redis queue`).

## 3. Commands
- Chạy Unit tests: `pytest api/tests/ -xvs`
- Format & lint code: `ruff check . --fix && ruff format .`
- Kiểm tra type: `mypy .`
- Khởi động local stack: `docker compose up --build -d`
- Chạy smoke tests: `bash scripts/smoke-test.sh`
- Kiểm tra bài tập hàng ngày: `bash scripts/verify-day-1.sh` (thay số 1 bằng số ngày tương ứng).

## 4. Constraints
- **Security**: TUYỆT ĐỐI KHÔNG hardcode API keys, token hay thông tin nhạy cảm. Luôn sử dụng biến môi trường (`.env`).
- **Workflow**: Trình bày PLAN (kế hoạch) trước khi thực hiện các thay đổi phức tạp (như refactor) và chờ phê duyệt.
- **Architecture**: KHÔNG thay đổi schema của cơ sở dữ liệu (`VECTOR(1024)` là cố định, nếu đổi model phải map về 1024).
- **File Length**: File `CLAUDE.md` này BẮT BUỘC phải duy trì dưới 200 dòng.
- **Fallback**: Ứng dụng phải hoạt động được (dù chất lượng thấp) ngay cả khi không có API key.

## 5. Domain Knowledge
- **RAG (Retrieval-Augmented Generation)**: Quy trình cốt lõi là Upload -> Chunk -> Embed -> Store -> Query -> Retrieve -> Generate.
- **pgvector**: Dùng để lưu trữ vector nhúng, sử dụng HNSW index cho truy vấn tìm kiếm độ tương đồng.
- **ARQ**: Thư viện Python dùng cho Job queues và RPC, kết hợp hoàn hảo với `asyncio` và Redis.

## 6. References
- Các lỗi thường gặp: `docs/STUDENT-FAQ.md`
- Hướng dẫn quy trình nộp bài hàng ngày: `docs/DAILY-WORKFLOW.md`
- Nhiệm vụ Day 1: Tách xử lý ingestion đồng bộ thành bất đồng bộ (sử dụng Redis + `ingestion-worker`).