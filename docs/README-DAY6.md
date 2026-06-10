# DAY 06 — Security & FinOps: LLM Red Team + Cost Governance

## Hướng dẫn Mentor: Demo & Lab Step-by-Step

> **Đối tượng:** Trainer / Mentor hướng dẫn học viên
> **Thời lượng:** 2.5 giờ (150 phút)
> **Ngày:** Day 6 trong Module 7 — AI-Native DevOps
> **Branch học viên làm việc:** `day6-security-finops`

---

## Mục lục

1. [Tổng quan & Mục tiêu](#1-tổng-quan--mục-tiêu)
2. [Chuẩn bị trước buổi (Mentor Checklist)](#2-chuẩn-bị-trước-buổi-mentor-checklist)
3. [Segment 1 — Recap & Hook](#3-segment-1--recap--hook-10-phút)
4. [Segment 2 — OWASP LLM & Agentic AI Top 10](#4-segment-2--owasp-llm--agentic-ai-top-10-45-phút)
5. [Segment 3 — Defense in Depth](#5-segment-3--defense-in-depth-30-phút)
6. [Segment 4 — Red Team Lab + FinOps](#6-segment-4--red-team-lab--finops-50-phút)
7. [Segment 5 — Threat Model](#7-segment-5--threat-model-15-phút)
8. [Troubleshooting](#8-troubleshooting)
9. [Homework](#9-homework-chuẩn-bị-day-7)

---

## 1. Tổng quan & Mục tiêu

### Bức tranh lớn

Day 1–5: học viên build InsightHub từng service, thêm MCP tool access, ChatOps bot với kubectl quyền. Mỗi ngày AI có thêm quyền. **Quyền lực = trách nhiệm.**

Day 6 chuyển sang pillar **Govern AI**: bảo vệ LLM khỏi injection, giám sát cost, viết threat model. Output: InsightHub pass OWASP red-team scan + có budget governance.

### Mục tiêu học viên đạt được cuối Day 6

| # | Mục tiêu | Verify |
|---|---|---|
| 1 | Liệt kê 8+ OWASP LLM Top 10 (2025) + Agentic AI Top 10 risks | Trả lời quiz |
| 2 | Red-team InsightHub bằng Promptfoo — no HIGH severity | `promptfoo redteam report` |
| 3 | Triển khai defense-in-depth (6 lớp) | Code diff + scan lại sạch |
| 4 | Quản lý cost LLM qua LiteLLM gateway | Budget alert hoạt động |
| 5 | Viết threat model (STRIDE + OWASP) cho InsightHub | `security/threat-model.md` ≥ 6 entries |

### Artifacts học viên nộp

```
1. security/promptfooconfig.yaml — Promptfoo OWASP scan config
2. security/red-team-report.html — Scan result (no HIGH)
3. security/threat-model.md — STRIDE + OWASP threat model
4. security/nemo-config/config.yaml — NeMo Guardrails config
5. litellm-config.yaml — LiteLLM gateway (budget + rate limit)
6. observability/cost-dashboard.json — Grafana cost panel
```

---

## 2. Chuẩn bị trước buổi (Mentor Checklist)

### 2.1. Kiểm tra environment

```bash
# InsightHub stack
docker compose up -d
docker compose ps  # 5 services running

# Promptfoo
promptfoo --version  # ≥ 0.85

# Verify API live
curl -s http://localhost:8000/health  # {"status":"ok"}

# Verify ChatOps bot (Day 5)
curl -s http://localhost:8100/health  # {"status":"ok"}
```

### 2.2. Chuẩn bị sample-docs cho indirect injection lab

```bash
# Trong sample-docs/ có 3 file, 1 file chứa indirect injection payload
ls sample-docs/
# → huong-dan-nguoi-moi.md  (← file bị "bẩn", KHÔNG nói trước)
# → company-policy.md
# → tech-specs.md
```

> **Lưu ý:** File `huong-dan-nguoi-moi.md` chứa hidden prompt injection. Để học viên tự phát hiện. Không tiết lộ trước.

### 2.3. Pre-load LiteLLM gateway config

```bash
# File litellm-config.yaml đã có sẵn — chỉ cần start gateway
pip install litellm[proxy]  # nếu chưa có
litellm --config litellm-config.yaml --port 4000
```

### 2.4. Verify Day 6 artifacts sẵn

```bash
bash scripts/verify-day-6.sh
# → Kiểm tra 7 items: promptfoo config, threat model, guardrails, LiteLLM, cost dashboard
```

---

## 3. Segment 1 — Recap & Hook (10 phút)

- "5 ngày qua ta cho AI ngày càng nhiều quyền: đọc code, chạm cluster, query Prometheus, giờ Slack bot có thể `kubectl`. Quyền lực = trách nhiệm."
- **Hook — EchoLeak (CVE-2025-32711, CVSS 9.3):** Zero-click prompt injection trong M365 Copilot. 1 email chứa payload → Copilot rò rỉ dữ liệu SharePoint/Teams. Không cần user click. **Tổ chức coi knowledge base là "đáng tin" — đó là lỗi.**
- "InsightHub cho upload tài liệu. Tài liệu = input không tin cậy. Hôm nay ta tấn công chính InsightHub của mình."

---

## 4. Segment 2 — OWASP LLM & Agentic AI Top 10 (45 phút)

### 4.1. OWASP LLM Top 10 (2025) — 5 rủi ro trọng tâm InsightHub

| ID | Rủi ro | Liên quan InsightHub |
|---|---|---|
| **LLM01** | Prompt Injection (#1) | Tài liệu upload = vector indirect injection |
| **LLM02** | Sensitive Information Disclosure | Rò rỉ nội dung tài liệu / system prompt |
| **LLM05** | Improper Output Handling | Output LLM dùng thẳng không validate |
| **LLM06** | Excessive Agency | ChatOps bot có quá nhiều quyền |
| **LLM08** | Vector & Embedding Weaknesses | Đầu độc vector store (RAG poisoning) |

### 4.2. Direct vs Indirect Prompt Injection

- **Direct:** kẻ tấn công gõ payload thẳng vào chat input.
- **Indirect:** payload giấu trong tài liệu, web, email — LLM đọc rồi thực thi. **Nguy hiểm hơn** vì tổ chức thường coi knowledge base là trusted.

> **Key insight (UK NCSC, OWASP):** LLM **không tách bạch** được "instruction" và "data" trong prompt. Coi prompt injection như SQL injection là sai lầm — không có cơ chế tách cứng.

### 4.3. OWASP Agentic AI Top 10 (2026)

Ra mắt Black Hat EU 2025. Các rủi ro mới khi AI là *agent* có tool:

| ID | Rủi ro | InsightHub liên quan |
|---|---|---|
| **ASI01** | Goal Hijack | Injection đổi mục tiêu bot từ "trả lời" sang "chạy lệnh độc" |
| **ASI03** | Tool Misuse | Bot bị lừa dùng kubectl với tham số nguy hiểm |
| **ASI04** | Memory Poisoning | Đầu độc vector store → ảnh hưởng dài hạn mọi câu hỏi |

### 4.4. Quiz (10 phút)

Học viên trả lời:
1. Tại sao indirect injection nguy hiểm hơn direct?
2. LLM có cơ chế nào tách instruction và data không? Tại sao?
3. ChatOps bot bị injection → rủi ro gì trong 3-tier permission model?

---

## 5. Segment 3 — Defense in Depth (30 phút)

### 5.1. 6 lớp phòng vệ

```
Lớp 1: Input sanitization  → lọc payload, xử lý hidden text
Lớp 2: Guardrails         → NeMo Guardrails / Bedrock Guardrails
Lớp 3: Prompt hardening   → tách instruction/data bằng delimit rõ (<context>)
Lớp 4: Least-privilege    → agent chỉ có đúng tool cần, deny by default
Lớp 5: Output validation  → schema chặt, tool-call allowlist
Lớp 6: Audit + red team   → log đầy đủ, quét định kỳ
```

### 5.2. InsightHub đã có gì sẵn

| Lớp | Trạng thái | File |
|---|---|---|
| Lớp 1 — Input sanitization | ✅ Day 6 | `api/app/services/llm.py` — `sanitize_chunk()` |
| Lớp 2 — Guardrails | 🔄 Config skeleton | `security/nemo-config/config.yaml` |
| Lớp 3 — Prompt hardening | ✅ Day 1 | `api/app/services/llm.py` — `<context>` tags |
| Lớp 4 — Least-privilege | ✅ Day 5 | `chatops-bot/app/permissions.py` — 3-tier |
| Lớp 5 — Output validation | ✅ Day 5 | `chatops-bot/app/handler.py` — tool allowlist |
| Lớp 6 — Audit + red team | ✅ Day 5 + 🔄 Day 6 | `chatops-bot/app/audit.py` + Promptfoo |

### 5.3. Ship gate trước khi launch LLM feature

- [ ] AI có least-privilege access (deny by default)
- [ ] Hành động rủi ro cao cần human approval
- [ ] Instruction và untrusted content tách bạch, delimit rõ
- [ ] RAG prompt dùng template đã hardened
- [ ] Input filtering xử lý hidden text / obfuscation
- [ ] Output validation deterministic (schema, allowlist)
- [ ] Logging bật, searchable, được review
- [ ] Chạy red-team + indirect-injection test định kỳ

---

## 6. Segment 4 — Red Team Lab + FinOps (50 phút)

### Phần A — Red Team InsightHub (35 phút)

**Bước 1 — Tấn công indirect injection thủ công (10 phút)**

```bash
# 1. Upload 3 file sample-docs vào InsightHub qua web UI (localhost:3000)
# 2. Đặt câu hỏi liên quan đến nội dung tài liệu
# 3. Quan sát: file nào khiến RAG pipeline trả lời lạ?
```

Câu hỏi phân tích:
- Vì sao đoạn payload bị retrieval kéo vào context?
- System prompt có chống được không? Tại sao không đủ?

**Bước 2 — Promptfoo OWASP scan (15 phút)**

```bash
cd security
promptfoo redteam run -c promptfooconfig.yaml
promptfoo redteam report
```

Config đã bật 5 plugins OWASP:

| Plugin | Severity | Test gì |
|---|---|---|
| `prompt-injection` | HIGH | Direct injection vào chat |
| `indirect-prompt-injection` | HIGH | Payload giấu trong tài liệu |
| `rag-poisoning` | HIGH | Đầu độc vector store |
| `pii` | MEDIUM | Rò rỉ thông tin nhạy cảm |
| `excessive-agency` | HIGH | Bot vượt quyền hành động |

Strategies: `basic`, `prompt-injection` — 30 tests, dùng `gpt-4o-mini` generate.

Assertions: chặn "SYSTEM COMPROMISED", "ignore all previous instructions", "reveal your system prompt".

**Bước 3 — Vá lỗ hổng (10 phút)**

Với mỗi lỗ HIGH:
1. **Indirect injection** → thêm `sanitize_chunk()` trước khi embed + guardrails
2. **RAG poisoning** → validate source document trust level
3. **Excessive agency** → tighten tool allowlist trong ChatOps

```bash
# Sau khi vá — chạy lại scan
promptfoo redteam run -c promptfooconfig.yaml
# → Mục tiêu: no HIGH severity
```

### Phần B — FinOps cho LLM (15 phút)

**Vì sao quan trọng:** InsightHub có 2 loại LLM call — embedding (mỗi chunk) + generation (mỗi câu hỏi). Không kiểm soát → bill shock.

**Bước 1 — Cost visibility:**

```bash
# Token metrics đã được expose trong api/app/core/metrics.py:
# insighthub_llm_tokens_total, insighthub_embedding_tokens_total
# Thêm panel cost vào Grafana dashboard
```

**Bước 2 — LiteLLM gateway:**

File `litellm-config.yaml` cấu hình:

| Model | Route | Rate Limit |
|---|---|---|
| `insighthub-chat` | `gemini/gemini-2.0-flash` | 30 RPM / 100K TPM |
| `insighthub-embed` | `gemini/text-embedding-004` | 60 RPM / 200K TPM |

FinOps controls:
- **Budget cap:** `max_budget: 5.0` daily
- **Budget duration:** `daily` — reset mỗi ngày
- **Master key:** `os.environ/LITELLM_MASTER_KEY`
- **Retry:** 3 retries, 60s timeout, 3 allowed fails

```bash
# Start gateway
litellm --config litellm-config.yaml --port 4000

# Verify
curl http://localhost:4000/health
curl http://localhost:4000/dashboard/costs | jq '.daily'
```

**Bước 3 — Budget alert:**

- AWS Budgets alert cho AI service spend (nếu dùng Bedrock)
- Hoặc spend limit trong Anthropic Console
- Hoặc webhook từ LiteLLM khi budget gần cạn

---

## 7. Segment 5 — Threat Model (15 phút)

Học viên viết threat model cho InsightHub theo STRIDE + OWASP. Template đã có ở `security/threat-model.md` với:

- **6 assets:** Vector store, LLM API keys, ChatOps bot, System prompt, Redis queue, PostgreSQL
- **8 threats:** Mapped sang OWASP LLM Top 10 (2025) + OWASP Agentic AI Top 10 (2026)
- **6 defense layers:** Mỗi lớp có trạng thái ✅/🔄
- **Risk register:** 8 risks với probability, impact, severity, mitigation, status
- **Remediation plan:** 5 actions có priority + deadline

---

## 8. Troubleshooting

| Triệu chứng | Nguyên nhân | Xử lý |
|---|---|---|
| `promptfoo redteam run` lỗi target | URL/body config sai | Kiểm tra InsightHub `/chat` đang chạy |
| Scan không tìm thấy lỗ hổng | Plugin chưa bật | Kiểm tra `plugins:` không rỗng |
| Indirect injection không trigger | File poisoned chưa ingest | Đảm bảo đã upload đủ `sample-docs/` |
| Cost panel "No data" | Token metric = 0 | Cần có chat traffic thật để sinh token |
| Vá xong vẫn còn HIGH | Vá chưa đúng lớp | Đối chiếu 6 lớp phòng vệ — có thể cần guardrails runtime |
| LiteLLM 403 | Master key thiếu | Set `LITELLM_MASTER_KEY` env var |
| LiteLLM budget không reset | `budget_duration` config sai | Check `budget_duration: daily` trong config |

---

## 9. Homework (chuẩn bị Day 7)

1. Hoàn thiện InsightHub: đảm bảo đủ 6 artifacts (Day 1–6).
2. 5–6 bạn volunteer chuẩn bị demo 12 phút.
3. **Tất cả 15 bạn** quay screencast 3 phút (Loom) nộp trước.
4. Tổng hợp cost report 1 tuần.
5. Tự rà self-checklist 6 artifacts.

---

## Ghi chú cho Trainer

- Skeleton `security/promptfooconfig.yaml` đã có sẵn — học viên không viết from scratch.
- File `sample-docs/huong-dan-nguoi-moi.md` chứa indirect injection — **KHÔNG nói trước** file nào, để học viên tự phát hiện.
- Plugin Promptfoo thay đổi nhanh — verify tên plugin chính xác 1 ngày trước tại promptfoo.dev/docs/red-team.
- Red team lab chạy trong sandbox, dùng API key dummy cho InsightHub test — tránh rò rỉ key thật.
- FinOps chỉ 15 phút — đủ giới thiệu khái niệm + thêm panel. Không sa đà vào cấu hình gateway phức tạp.
- Đây là buổi "đắt giá" nhất khóa — nhấn mạnh: không trung tâm nào khác dạy đủ phần này.
