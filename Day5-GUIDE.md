# Day 5 — ChatOps Bot: AI Incident Response

## Mục tiêu

Build Slack bot AI-powered trả lời câu hỏi vận hành InsightHub qua MCP backend (k8s + prometheus), với human-in-the-loop approval và audit trail đầy đủ.

## Kiến trúc

```
Slack workspace
  │  app_mention event
  ▼
┌─────────────────────────────────────────┐
│  chatops-bot (FastAPI, port 8080)       │
│                                         │
│  ┌──────────────┐  ┌─────────────────┐ │
│  │ Slack SIG     │  │ Permissions     │ │
│  │ Verify        │  │ 3-tier check    │ │
│  └──────────────┘  └─────────────────┘ │
│         │                  │           │
│         ▼                  ▼           │
│  ┌─────────────────────────────────┐  │
│  │  handle_question()              │  │
│  │  - Query k8s (kubectl)          │  │
│  │  - Query Prometheus (PromQL)    │  │
│  │  - LLM generate answer          │  │
│  └─────────────────────────────────┘  │
│         │                             │
│         ▼                             │
│  ┌─────────────────────────────────┐  │
│  │  audit.log_tool_call()          │  │
│  │  NDJSON: ts, user, tool, result │  │
│  └─────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Stack

| Component | Tech | Port |
|---|---|---|
| Framework | FastAPI + Uvicorn | 8080 |
| LLM | Claude (Anthropic SDK) | — |
| Slack | slack-sdk v3.33 | — |
| Backend MCP | kubectl + Prometheus HTTP API | — |
| Logging | NDJSON audit log | file |

## 3-Tier Permission System

| Tier | Actions | Policy |
|---|---|---|
| **READ** | get pods, query metrics, view logs | Auto-approve |
| **WRITE** | scale, restart, apply config | Cần approval từ user trong Slack |
| **DESTRUCTIVE** | delete, drain, drop DB | Từ chối hoàn toàn |

## Security

- **Slack signature verification**: HMAC-SHA256 với `SLACK_SIGNING_SECRET` trên mọi request `/slack/events`
- **Read-only mặc định**: bot chỉ query infrastructure, không thực hiện hành động ghi
- **Audit trail**: mọi tool call được ghi NDJSON vào `chatops-audit.log`

## 3 Câu hỏi mẫu

Bot phải trả lời được:

1. **"InsightHub có healthy không?"** → Query pod status + health endpoints + metrics lỗi
2. **"Hôm nay ingest bao nhiêu tài liệu?"** → Query Prometheus counter `insighthub_documents_total`
3. **"Pod nào đang lỗi?"** → Query k8s pods với `status.phase != Running`

## Commands

```bash
# Install dependencies
cd chatops-bot && pip install -r requirements.txt

# Run bot
uvicorn app.main:app --host 0.0.0.0 --port 8080

# Docker
docker build -t insighthub-chatops-bot .
docker run -p 8080:8080 \
  -e SLACK_SIGNING_SECRET=xxx \
  -e ANTHROPIC_API_KEY=xxx \
  insighthub-chatops-bot

# ngrok (expose local bot cho Slack)
ngrok http 8080

# Verify
curl -s http://localhost:8080/healthz
# → {"status": "ok"}

# Test signature verification (should 401)
curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://localhost:8080/slack/events -d '{}'
# → 401

# Test URL verification (Slack setup)
curl -X POST http://localhost:8080/slack/events \
  -H "Content-Type: application/json" \
  -d '{"type":"url_verification","challenge":"test123"}'
# → {"challenge":"test123"}

# Run tests
cd chatops-bot && pytest tests/ -v

# Verify Day 5
bash scripts/verify-day-5.sh
```

## Artifacts

| # | Artifact | Path |
|---|----------|------|
| 1 | Bot skeleton + implementation | `chatops-bot/app/main.py` |
| 2 | Audit module | `chatops-bot/app/audit.py` |
| 3 | Permissions module | `chatops-bot/app/permissions.py` |
| 4 | Dockerfile | `chatops-bot/Dockerfile` |
| 5 | Dependencies | `chatops-bot/requirements.txt` |
| 6 | Audit log | `chatops-audit.log` |

## File Structure

```
chatops-bot/
├── app/
│   ├── __init__.py
│   ├── main.py          # FastAPI: signature verify, slack events, handle_question
│   ├── audit.py         # Structured NDJSON audit logging
│   ├── permissions.py   # 3-tier: READ/WRITE/DESTRUCTIVE
│   └── handler.py       # Tool-calling loop via LLM (optional)
├── Dockerfile
├── README.md
└── requirements.txt
```

## Key Concepts

- **ChatOps = Chat + DevOps** — vận hành qua conversation (Slack, Discord, Teams) thay vì dashboard/CLI
- **Human-in-the-loop**: AI mạnh nhưng không tự tin — cần approval cho hành động có rủi ro
- **Audit trail**: Khi AI chạm hạ tầng, phải có dấu vết ai hỏi gì, bot làm gì, kết quả ra sao
- **Signature verification**: Chống request giả mạo — không tin request nào không có HMAC hợp lệ
- **Read-only default**: Bot mặc định chỉ xem — phải có cơ chế rõ ràng để "nâng quyền"
