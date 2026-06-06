# Day 1 AI Prompts — Refactor Ingestion Async

## Prompt 1 — Create CLAUDE.md

**Tool**: Claude Opus 4.6
**Time**: 2026-06-06 10:00

**Prompt**:
Tạo file CLAUDE.md cho dự án InsightHub — một ứng dụng RAG Notebook. File phải có đủ 6 phần: Architecture (Web/API/Worker/DB/Queue/LLM), Conventions (Python/ruff/mypy/async/commits/PRs), Commands (test/lint/type/docker/smoke/verify), Constraints (security/workflow/architecture/file-length/fallback), Domain Knowledge (RAG/pgvector/ARQ), References (FAQ/workflow/day1 task). Bắt buộc dưới 200 dòng, ngôn ngữ tiếng Việt, dùng tiếng Anh cho các thuật ngữ kỹ thuật.

**Why it worked**:
- Yêu cầu rõ ràng về cấu trúc 6 phần và giới hạn 200 dòng.
- Agent dùng context từ codebase để điền thông tin chính xác (tech stack, commands thực tế).

## Prompt 2 — Refactor Ingestion to Async

**Tool**: Claude Opus 4.6
**Time**: 2026-06-06 10:10

**Prompt**:
Phân tích code tại `api/app/routers/documents.py` và `api/app/services/ingestion.py`. Hàm `ingest_document_sync()` đang chạy đồng bộ trong request handler. Yêu cầu:
1. API endpoint upload đã có status_code=202 và gọi `redis.enqueue_job("ingest_document_task", ...)` — kiểm tra xem có đúng chưa.
2. Kiểm tra `ingestion-worker/worker.py` có ARQ task `ingest_document_task` với retry logic chưa.
3. Kiểm tra docker-compose.yml có 5 services (web/api/ingestion-worker/redis/postgres) chưa.
4. Trình bày PLAN trước khi sửa, bao gồm: thay đổi file nào, tại sao, rủi ro gì.

**Why it worked**:
- Yêu cầu PLAN giúp kiểm soát rủi ro trước khi thực hiện thay đổi lớn.
- Agent đọc code thực tế, xác nhận các thay đổi đã đúng và báo cáo kết quả.

## Prompt 3 — Add Retry Logic and Queue Depth Metric

**Tool**: Claude Opus 4.6
**Time**: 2026-06-06 10:30

**Prompt**:
Nâng cấp ingestion-worker cho Day 1:
1. Thêm cơ chế retry cho worker sử dụng `tenacity` (3 lần thử, exponential backoff: min=2s, max=10s). Task phải cập nhật status thành "failed" nếu tất cả lần thử đều thất bại.
2. Thêm Prometheus Gauge metric `insighthub_ingestion_queue_depth` trong API để theo dõi độ sâu hàng đợi Redis (chuẩn bị cho Day 4 observability).
3. Xác minh verify script (`scripts/verify-day-1.sh`) pass hết 7 checks.

**Why it worked**:
- Tách yêu cầu thành 3 mục cụ thể, agent xử lý từng phần.
- Retry logic tăng độ bền vững (reliability) — DevOps mindset.
- Queue depth metric là foundation cho Day 4 monitoring.
