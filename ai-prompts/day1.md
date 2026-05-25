# Day 1 AI Prompts - Refactor Ingestion Async

## Prompt 1 — Create CLAUDE.md

**Tool**: Gemini CLI Agent
**Time**: 2026-05-25 14:00

**Prompt**:
Hãy tạo file CLAUDE.md giúp tôi với đầy đủ 6 phần: Architecture, Conventions, Commands, Constraints, Domain, References. Đảm bảo file ngắn gọn dưới 200 dòng.

**Why it worked**:
- Yêu cầu rõ ràng về cấu trúc và ràng buộc (dưới 200 dòng).
- Agent hiểu ngữ cảnh dự án InsightHub để điền thông tin chính xác.

## Prompt 2 — Refactor Ingestion to Async

**Tool**: Gemini CLI Agent
**Time**: 2026-05-25 14:15

**Prompt**:
Hãy giúp tôi refactor hệ thống để tách phần ingestion đồng bộ hiện tại thành một service 'ingestion-worker' riêng sử dụng Redis và ARQ. 
1. Cập nhật docker-compose.yml thêm redis và worker.
2. Tạo thư mục ingestion-worker với Dockerfile và worker.py.
3. Sửa API endpoint upload để enqueue job thay vì xử lý trực tiếp.
4. Trình bày PLAN trước khi làm.

**Why it worked**:
- Phân rã nhiệm vụ thành các bước nhỏ.
- Yêu cầu trình bày PLAN giúp kiểm soát rủi ro trước khi thực hiện thay đổi lớn.
- Sử dụng đúng các công nghệ yêu cầu (Redis, ARQ).

## Prompt 3 — Add Source Citations and Retry Logic

**Tool**: Gemini CLI Agent
**Time**: 2026-05-25 14:45

**Prompt**:
Thêm tính năng mới cho Day 1:
1. Nâng cấp Chat API để trả về thêm độ tương đồng (similarity) của từng nguồn tài liệu.
2. Thêm cơ chế retry cho worker (sử dụng tenacity) để tăng độ bền vững.

**Why it worked**:
- Tận dụng khả năng của agent để cải thiện code hiện có.
- Tập trung vào các yếu tố DevOps (reliability qua retry, observability qua similarity).
