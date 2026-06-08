# Day 5 AI Prompts — ChatOps Bot: AI Incident Response

**Tool**: Claude Opus 4.6 (Anthropic SDK)
**Date**: 2026-06-08
**Workflow**: Skeleton-first → implement handler → implement permissions → implement audit → test

---

## Prompt 1 — System Prompt cho ChatOps Bot

**Tool**: Claude Opus 4.6
**Time**: 2026-06-08 09:00

**Prompt**:
Write `chatops-bot/prompts/system.md` cho InsightHub ChatOps Bot:

```
ROLE: InsightHub ChatOps Bot — AI assistant vận hành InsightHub qua Slack.

CAPABILITIES:
- Query Kubernetes: pod status, logs, events, deployments, nodes
- Query Prometheus: metrics, PromQL queries
- Query InsightHub API: health check, document stats

RULES:
- Trả lời ngắn gọn, súc tích bằng tiếng Việt (trừ tên tool/command giữ nguyên)
- Chỉ dùng tool cần thiết, không gọi thừa
- READ tier: auto-approve, thực hiện luôn
- WRITE tier: báo user cần approval, không tự thực hiện
- DESTRUCTIVE: từ chối hoàn toàn, giải thích lý do
- Nếu tool lỗi → báo lỗi rõ ràng, đề xuất cách fix
- Không báo API key, credential, hoặc thông tin nhạy cảm
```

**Why it worked**:
- Role-first prompt → LLM hiểu ngay context InsightHub.
- Tier rules explicit → bot tự phân loại hành động mà không cần extra prompt.
- "Không gọi thừa" → tiết kiệm token, tránh tool spam.

---

## Prompt 2 — Multi-Provider LLM Client

**Tool**: Claude Opus 4.6
**Time**: 2026-06-08 09:30

**Prompt**:
Implement `chatops-bot/app/llm.py` — multi-provider LLM client với tool-calling:

```
REQUIREMENTS:
- Support 3 providers: deepseek (default), gemini, anthropic
- DeepSeek: OpenAI-compatible API, model deepseek-v4-flash
- Gemini: OpenAI-compatible API via Google endpoint, model gemini-3-flash-preview
- Anthropic: Native SDK, model claude-sonnet-4-6
- Load system prompt từ prompts/system.md
- Format tools as OpenAI function-calling schema
- extract_text(): lấy text response từ bất kỳ provider
- extract_tool_calls(): parse tool calls từ bất kỳ provider

CONSTRAINTS:
- API key từ env var: {PROVIDER}_API_KEY
- Base URL từ env var: {PROVIDER}_BASE_URL (optional, có default)
- Timeout 60s cho mọi call
- max_tokens 2048
```

**Why it worked**:
- Provider-agnostic design → đổi LLM chỉ cần đổi env var, không đổi code.
- OpenAI-compatible path cho DeepSeek/Gemini → reuse format_tools logic.
- Anthropic native SDK → xử lý content blocks (text + tool_use) riêng.
- `extract_text` và `extract_tool_calls` là bridge layer giữa provider differences.

**What I changed**:
- Thêm fallback chain cho API key: `DEEPSEEK_API_KEY` → `GEMINI_API_KEY` → `ANTHROPIC_API_KEY` → "".
- Tool format: empty `properties` + `required: []` → LLM tự infer params từ description.

---

## Prompt 3 — Tool-Calling Handler Loop

**Tool**: Claude Opus 4.6
**Time**: 2026-06-08 10:00

**Prompt**:
Implement `chatops-bot/app/handler.py` — tool-calling loop với permission enforcement:

```
REQUIREMENTS:
- handle_question(question, user) → str answer
- Loop tối đa 5 rounds:
  1. Gọi LLM với messages history
  2. Parse tool calls từ response
  3. Nếu không có tool call → return text answer
  4. Với mỗi tool call:
     a. Kiểm tra permission tier (READ/WRITE/DESTRUCTIVE)
     b. Nếu WRITE: trả "Denied — cần approval"
     c. Nếu DESTRUCTIVE: trả "Denied — không được phép"
     d. Nếu READ: thực thi tool
     e. Gọi log_tool_call() để audit
     f. Append result vào messages
  5. Gọi LLM lại với tool results → final answer

CONSTRAINTS:
- Mặc định namespace từ K8S_NAMESPACE env var
- API health tool dùng INSIGHTHUB_API_URL
- Tool result truncate 4000 chars để tránh overflow
```

**Why it worked**:
- Classic ReAct loop: thought → action → observation → thought → answer.
- Permission check TRƯỚC khi execute → không bao giờ chạy tool không được phép.
- Audit log trong loop → mọi tool call đều có trace.
- `max_rounds=5` → chống infinite loop nếu LLM cứ gọi tool.

---

## Prompt 4 — 3-Tier Permission System

**Tool**: Claude Opus 4.6
**Time**: 2026-06-08 10:15

**Prompt**:
Implement `chatops-bot/app/permissions.py` — 3-tier permission system:

```
REQUIREMENTS:
- PermissionTier enum: READ, WRITE, DESTRUCTIVE
- DESTRUCTIVE_KEYWORDS: delete, destroy, drop, purge, drain, evict, terminate, shutdown, kill
- WRITE_KEYWORDS: scale, restart, rollout, apply, update, patch, create, exec, port-forward
- classify(tool, args) → PermissionTier:
  - Check destructive keywords first (trước write)
  - Then write keywords
  - Default: READ
- is_allowed(tier) → bool:
  - READ: True (auto-approve)
  - WRITE: False (cần approval, không tự thực hiện)
  - DESTRUCTIVE: False (từ chối hoàn toàn)

CONSTRAINTS:
- Keyword matching trên combined string: tool + args values
- Case-insensitive
- classify() dùng cho unknown tools (không có trong registry)
```

**Why it worked**:
- Keyword-based classification → đơn giản, không cần config file.
- Destructive check trước write → "delete pod" không bị classify nhầm thành write.
- `is_allowed` chỉ check destructive → write = cần approval nhưng không deny outright.

---

## Prompt 5 — K8s + Prometheus + API Health Tools

**Tool**: Claude Opus 4.6
**Time**: 2026-06-08 10:30

**Prompt**:
Implement `chatops-bot/app/tools.py` — K8s, Prometheus, API health tools:

```
REQUIREMENTS:

K8s tools (READ):
- get_pods(ns): kubectl get pods -n {ns} -o wide
- get_pod_logs(ns, pod, lines=100): kubectl logs -n {ns} {pod} --tail={lines}
- get_events(ns): kubectl get events -n {ns} --sort-by='.lastTimestamp'
- describe_pod(ns, pod): kubectl describe pod -n {ns} {pod}
- get_deployments(ns): kubectl get deployments -n {ns}
- get_nodes(): kubectl get nodes -o wide

K8s tools (WRITE):
- scale_deployment(ns, deploy, replicas): kubectl scale deployment -n {ns} {deploy} --replicas={replicas}
- restart_deployment(ns, deploy): kubectl rollout restart deployment -n {ns} {deploy}
- rollout_status(ns, deploy): kubectl rollout status deployment -n {ns} {deploy} --timeout=10s
- apply(ns, manifest): kubectl apply -n {ns} -f {manifest}

Prometheus (READ):
- prometheus_query(query): GET http://localhost:9090/api/v1/query?query={query}

API Health (READ):
- api_health(url): GET {url}/healthz, return response time ms

CONSTRAINTS:
- Mọi k8s command qua subprocess.run với timeout 15s
- shell=True để hỗ trợ pipe/filter (kubectl get pods có thể thêm -o json)
- Prometheus query qua urllib (không cần requests dependency)
- Register mọi tool với tier và function
- list_tools() trả list cho LLM function-calling schema
```

**Why it worked**:
- `shell=True` cho kubectl → hỗ trợ flags phức tạp.
- Timeout 15s → không block forever nếu k8s API lag.
- Tool registry pattern → dễ thêm tool mới, `list_tools()` auto-update.
- `classify_tool()` fallback → unknown tools vẫn được phân loại tier.

---

## Prompt 6 — Slack Signature Verification + FastAPI App

**Tool**: Claude Opus 4.6
**Time**: 2026-06-08 10:45

**Prompt**:
Implement `chatops-bot/app/main.py` — FastAPI app với Slack integration:

```
REQUIREMENTS:
- FastAPI app với 2 endpoints:
  1. GET /healthz → {"status": "ok"}
  2. POST /slack/events → Slack event handler

- Slack event handler:
  a. Verify signature: HMAC-SHA256 với SLACK_SIGNING_SECRET
     - Basestring: v0:{timestamp}:{body}
     - So sánh với X-Slack-Signature header
  b. Handle url_verification: return {"challenge": ...}
  c. Handle app_mention event:
     - Extract question (bỏ bot mention)
     - Post "Đang xử lý..." message
     - Gọi handle_question(question, user)
     - Post answer về Slack thread
  d. BackgroundTasks không cần (Slack expect response < 3s)

- verify_signature(body, timestamp, signature) → bool:
  - Nếu SLACK_SIGNING_SECRET trống → log warning, return True (dev mode)
  - Dùng hmac.compare_digest để chống timing attack

- post_message(channel, text, thread_ts):
  - Dùng slack_sdk WebClient
  - Catch SlackApiError, log error

CONSTRAINTS:
- ContextVar cho channel và user_id (thread-safe)
- Logger: chatops-bot.main
```

**Why it worked**:
- HMAC-SHA256 verification → chống request giả mạo.
- `hmac.compare_digest` → constant-time comparison, chống timing attack.
- `thread_ts` → reply trong thread thay vì channel mới → Slack UX tốt hơn.
- ContextVar → async-safe, không cần pass channel/user qua mọi hàm.

---

## Prompt 7 — NDJSON Audit Logging

**Tool**: Claude Opus 4.6
**Time**: 2026-06-08 11:00

**Prompt**:
Implement `chatops-bot/app/audit.py` — structured NDJSON audit log:

```
REQUIREMENTS:
- log_tool_call(user, tool, args, result_summary, approved=True)
- Mỗi record là 1 dòng JSON (NDJSON format)
- Fields:
  - ts: ISO8601 UTC timestamp
  - user: Slack user ID
  - tool: tool name
  - args: dict of arguments
  - result: truncated result summary (max 200 chars)
  - approved: bool
- Log path từ env var CHATOPS_AUDIT_LOG (default: chatops-audit.log)
- Append mode, UTF-8 encoding
- Cũng log qua logger.info("AUDIT ...")

CONSTRAINTS:
- ensure_ascii=False để hỗ trợ tiếng Việt
- default=str cho các object không JSON-serializable
```

**Why it worked**:
- NDJSON → mỗi dòng là valid JSON → dễ grep, jq, tail.
- `default=str` → không bao giờ fail serialize do custom objects.
- `ensure_ascii=False` → giữ tiếng Việt trong log.

---

## Lessons Learned

| Lesson | Detail |
|--------|--------|
| Skeleton trước | Có skeleton main.py + audit.py → prompt cụ thể hơn, LLM đúng hướng |
| Permission-first | Viết permissions.py TRƯỚC handler → handler chỉ cần gọi is_allowed() |
| Tool registry pattern | Register + list_tools() → auto-sync giữa tools và LLM schema |
| Provider abstraction | 1 interface, 3 backends → đổi LLM chỉ cần env var |
| Audit trong loop | Gọi log_tool_call() NGAY sau execute → không bao giờ quên |
| Signature verify đầu tiên | Request vào /slack/events → verify TRƯỚC khi parse body → chống injection |

---

## Artifacts Generated

| Artifact | Prompt | Status |
|----------|--------|--------|
| chatops-bot/prompts/system.md | Prompt 1 | ✅ |
| chatops-bot/app/llm.py | Prompt 2 | ✅ |
| chatops-bot/app/handler.py | Prompt 3 | ✅ |
| chatops-bot/app/permissions.py | Prompt 4 | ✅ |
| chatops-bot/app/tools.py | Prompt 5 | ✅ |
| chatops-bot/app/main.py | Prompt 6 | ✅ |
| chatops-bot/app/audit.py | Prompt 7 | ✅ |
| chatops-bot/requirements.txt | (manual) | ✅ |
| chatops-bot/Dockerfile | (manual) | ✅ |
| chatops-bot/env.example | (manual) | ✅ |
| scripts/verify-day-5.sh | (manual) | ✅ |

**Verification**: `bash scripts/verify-day-5.sh` → **PASS** ✅
