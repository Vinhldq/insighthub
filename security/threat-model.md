# Day 6 — Threat Model: InsightHub

> STRIDE + OWASP LLM Top 10 (2025) + OWASP Agentic AI Top 10 (2026)
> Ngày: 2026-06-08

---

## 1. Tài sản (Assets)

| # | Tài sản | Mô tả | Mức độ |
|---|---|---|---|
| A1 | Vector store (pgvector) | Chứa embedding + text của tài liệu upload | **Cao** — chứa nội dung nội bộ |
| A2 | LLM API keys | Gemini / Anthropic / DeepSeek keys | **Cao** — chi phí + access |
| A3 | ChatOps bot (kubectl) | Có quyền đọc cluster K8s | **Cao** — cluster access |
| A4 | System prompt | Prompt hệ thống của RAG + ChatOps | **Trung bình** — lộ workflow |
| A5 | Redis queue | ARQ job queue cho ingestion | **Trung bình** — DoS vector |
| A6 | PostgreSQL | Metadata + document status | **Trung bình** — data integrity |

---

## 2. Vector tấn công (Threats)

### Mapped: OWASP LLM Top 10 (2025)

| ID | Rủi ro | Tài sản | STRIDE | Mô tả |
|---|---|---|---|---|
| **LLM01** | Prompt Injection | A1, A4 | T, S | Direct: user gõ payload vào chat. Indirect: tài liệu upload chứa payload → RAG poisoning |
| **LLM02** | Sensitive Info Disclosure | A1, A4 | I, S | LLM rò rỉ nội dung tài liệu nội bộ hoặc system prompt |
| **LLM05** | Improper Output Handling | A3 | T, E | Output LLM dùng thẳng làm kubectl command → command injection |
| **LLM06** | Excessive Agency | A3 | E, D | ChatOps bot có quyền kubectl đọc cluster — bị injection → hành động ngoài ý muốn |
| **LLM07** | System Prompt Leakage | A4 | I, S | Kẻ tấn công dụ LLM in ra system prompt → lộ API key, workflow |
| **LLM08** | Vector & Embedding Weaknesses | A1 | T, S | Đầu độc vector store: upload tài liệu chứa payload độc → retrieval kéo vào context |

### Mapped: OWASP Agentic AI Top 10 (2026)

| ID | Rủi ro | Tài sản | STRIDE | Mô tả |
|---|---|---|---|---|
| **ASI01** | Goal Hijack | A3 | T | Injection đổi mục tiêu ChatOps bot từ "trả lời câu hỏi" sang "chạy lệnh độc hại" |
| **ASI03** | Tool Misuse | A3 | T | Bot bị lừa dùng kubectl với tham số sai hoặc nguy hiểm |
| **ASI04** | Memory Poisoning | A1 | T | Đầu độc vector store → ảnh hưởng dài hạn đến mọi câu hỏi |

---

## 3. Biện pháp phòng vệ đã áp dụng

### Lớp 1: Input Sanitization
- **Trạng thái:** ✅ Đã implement (Day 6)
- **Mô tả:** Sanitize chunk text trước khi embed — lọc common injection patterns
- **File:** `api/app/services/llm.py` — `sanitize_chunk()`

### Lớp 2: Guardrails
- **Trạng thái:** 🔄 Config skeleton đã có (`security/nemo-config/`)
- **Mô tả:** NeMo Guardrails chống prompt injection + PII
- **File:** `security/nemo-config/config.yaml`

### Lớp 3: Prompt Hardening
- **Trạng thái:** ✅ Đã implement (Day 1)
- **Mô tả:** System prompt tách riêng, context bọc trong `<context>` + `<doc>` tags
- **File:** `api/app/services/llm.py` — `SYSTEM_PROMPT`, `_build_user_message()`

### Lớp 4: Least-Privilege Tool
- **Trạng thái:** ✅ Đã implement (Day 5)
- **Mô tả:** ChatOps bot 3-tier permissions (READ auto / WRITE token / DESTRUCTIVE deny)
- **File:** `chatops-bot/app/permissions.py`

### Lớp 5: Output Validation
- **Trạng thái:** ✅ Đã implement (Day 5)
- **Mô tả:** Tool-call allowlist, schema validation, deterministic output
- **File:** `chatops-bot/app/handler.py`

### Lớp 6: Audit + Red Team
- **Trạng thái:** ✅ Đã implement (Day 5) + 🔄 Day 6
- **Mô tả:** NDJSON audit log + Promptfoo OWASP scan
- **File:** `chatops-bot/app/audit.py`, `security/promptfooconfig.yaml`

### K8s Least-Privilege
- **Trạng thái:** ✅ Đã implement (Day 2)
- **Mô tả:** ServiceAccount `mcp-readonly` + ClusterRole read-only
- **File:** `infra/k8s/mcp-readonly/`

### Cost Governance
- **Trạng thái:** 🔄 Day 6
- **Mô tả:** Token metrics exposed → Grafana cost dashboard + budget alert
- **File:** `api/app/core/metrics.py`

---

## 4. Risk Register

| # | Rủi ro | Xác suất | Tác động | Mức | Biện pháp | Trạng thái |
|---|---|---|---|---|---|---|
| R1 | Indirect injection qua tài liệu upload | Cao | Cao | **HIGH** | Sanitize chunk + guardrails + prompt hardening | 🔄 Đang vá |
| R2 | Direct prompt injection vào chat | Cao | Trung bình | **MEDIUM** | Input filtering + guardrails | 🔄 Đang vá |
| R3 | System prompt leakage | Trung bình | Trung bình | **MEDIUM** | Prompt hardening + output validation | ✅ |
| R4 | RAG poisoning (vector store) | Trung bình | Cao | **HIGH** | Sanitize + red-team định kỳ | 🔄 Đang vá |
| R5 | ChatOps bot excessive agency | Trung bình | Cao | **HIGH** | 3-tier permission + deny-by-default | ✅ |
| R6 | LLM API key exposure | Thấp | Cao | **HIGH** | Env var only, không hardcode | ✅ |
| R7 | Bill shock (unbounded LLM cost) | Trung bình | Trung bình | **MEDIUM** | Token metrics + budget alert | 🔄 Day 6 |
| R8 | Output injection → kubectl command | Thấp | Cao | **HIGH** | Output validation + tool allowlist | ✅ |

---

## 5. Kế hoạch giảm rủi ro còn lại

| # | Hành động | Ưu tiên | Deadline |
|---|---|---|---|
| 1 | Vá indirect injection: sanitize chunk + re-run Promptfoo | P0 | Day 6 |
| 2 | Triển khai NeMo Guardrails runtime | P1 | Day 6 |
| 3 | Thêm cost panel vào Grafana dashboard | P1 | Day 6 |
| 4 | Đặt budget alert cho LLM API | P2 | Day 6 |
| 5 | Chạy indirect-injection test định kỳ (CI) | P2 | Day 7+ |

---

## 6. Liên kết

- OWASP LLM Top 10 (2025): https://genai.owasp.org
- OWASP Agentic AI Top 10 (2026): https://owasp.org/www-project-agentic-ai-top-10
- Promptfoo: https://promptfoo.dev
- STRIDE: https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats
