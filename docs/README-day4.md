# Day 4 — AIOps: Observability & Anomaly Detection

## Mục tiêu

Instrument InsightHub với observability stack — Prometheus scrape + Grafana dashboard + anomaly detection — và áp dụng AI để làm Root Cause Analysis (RCA) cho incidents.

## Kiến trúc Observability

```
InsightHub services
  │  /metrics (Prometheus format)
  ▼
ServiceMonitor (scrape mỗi 15s)
  │
  ▼
Prometheus (lưu series, đánh giá recording rules)
  │
  ├── Recording rules: baseline + upper/lower band + anomaly_score
  │     (26h smoothing window, adaptive strategy)
  │
  ├── Alerting rules: anomaly_score > 3 + vượt upper band
  │     → Alertmanager → Slack/PagerDuty
  │
  ▼
Grafana
  ├── Dashboard 12 panels (RED method)
  └── Anomaly visualization

RCA Reports (AI-generated)
  ├── incident-001: LLM latency spike
  ├── incident-002: Queue backlog
  └── incident-003: DB pool exhaustion
```

## Anomaly Detection

Strategy: **adaptive** — baseline động bằng `avg_over_time` + `stddev_over_time` trên cửa sổ 26h.

| Metric | Baseline expr | Alert threshold | Component |
|---|---|---|---|
| `insighthub_llm_call_latency_seconds` | p95 over 5m, avg 26h | score > 3 + vượt upper band | api |
| `insighthub_ingestion_errors_total` | sum(rate) avg 26h | score > 3 + vượt upper band | ingestion-worker |
| `insighthub_rag_query_latency_seconds` | p95 over 5m, avg 26h | score > 3 + vượt upper band | api |

**Band formula:**
```
upper_band = baseline + clamp_max(stddev * 3, max_threshold)
lower_band = baseline * 0.5
anomaly_score = (current - baseline) / max(stddev, 0.001)
```

## Grafana Dashboard

12 panels theo RED method:

| Panel | Metric | Method |
|---|---|---|
| RAG query rate | `insighthub_rag_query_latency_seconds_count` | Rate |
| RAG error rate | `insighthub_rag_errors_total` | Rate |
| RAG query latency p50 | histogram quantile | Duration |
| RAG query latency p95 | histogram quantile | Duration |
| RAG query latency p99 | histogram quantile | Duration |
| LLM call latency p95 | histogram quantile | Duration |
| Ingestion queue depth | `insighthub_ingestion_queue_depth` | Gauge |
| Documents by status | `insighthub_documents_total` | Counter |
| Ingestion errors rate | `insighthub_ingestion_errors_total` | Rate |
| LLM tokens total | `insighthub_llm_tokens_total` | Counter (FinOps) |
| Ingestion throughput | `insighthub_ingestion_queue_depth` deriv | Gauge deriv |
| System health score | composite | Calculated |

## RCA Methodology

Mỗi incident report gồm:

| Section | Nội dung |
|---|---|
| `incident_id` | ID + timestamp |
| `title` | Mô tả ngắn |
| `symptoms` | Triệu chứng quan sát được |
| `timeline` | Dòng thời gian sự kiện |
| `metrics_evidence` | Prometheus queries + kết quả làm bằng chứng |
| `top_hypotheses` | ≥3 giả thuyết, mỗi cái có `evidence` cited |
| `root_cause` | Nguyên nhân gốc |
| `remediation` | Đề xuất fix |
| `prevention` | Cách ngăn ngừa tái diễn |

## MLOps Overview

| Concept | Áp dụng cho InsightHub |
|---|---|
| **Mindset** | Model = service (version, latency, cost, rollback) |
| **Lifecycle** | Train → Deploy → Monitor → Retrain |
| **Registry** | Model versioning (MLflow, W&B) |
| **Approval** | Human review trước promote model prod |
| **Drift** | Monitor data drift — LLM latency distribution thay đổi |
| **Rollback** | Rollback model version khi anomaly spike |
| **Ownership** | ML engineer owns model, DevOps owns deployment pipeline |

## Commands

```bash
# Verify ServiceMonitor
kubectl get servicemonitor -n insighthub
kubectl get servicemonitor insighthub-services -o yaml

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
curl 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | select(.labels.job=="insighthub-api")'

# Validate Prometheus rules
promtool check rules observability/anomaly-rules.yaml

# Query anomaly metrics
curl -s 'http://localhost:9090/api/v1/query?query=insighthub_llm_call_latency_seconds:anomaly_score' | jq

# Import Grafana dashboard
# JSON: observability/grafana-dashboards/insighthub-dashboard.json

# Verify RCA reports
jq '.incident_id, .root_cause' rca-reports/incident-*.json

# Run Day 4 verify
bash scripts/verify-day-4.sh
```

## Artifacts

| # | Artifact | Path |
|---|----------|------|
| 1 | ServiceMonitor | `observability/servicemonitor.yaml` |
| 2 | Anomaly rules | `observability/anomaly-rules.yaml` |
| 3 | Grafana dashboard | `observability/grafana-dashboards/insighthub-dashboard.json` |
| 4 | RCA report — LLM latency | `rca-reports/incident-001-llm-latency.json` |
| 5 | RCA report — Queue backlog | `rca-reports/incident-002-queue-backlog.json` |
| 6 | RCA report — DB pool exhaustion | `rca-reports/incident-003-db-pool-exhaustion.json` |
| 7 | MLOps notes | `mlops-overview-notes.md` |

## Key Concepts

- **AIOps = AI + DevOps operations** — dùng ML để giảm false-positive alerts, tự động RCA
- **Anomaly detection ≠ threshold alert** — baseline động thích ứng với seasonality
- **RED method**: Rate, Errors, Duration — framework chọn metric cho services
- **USE method**: Utilization, Saturation, Errors — cho resources (CPU, memory, disk)
- **Recording rules**: pre-compute expensive queries, giảm load Prometheus
- **Correlation > Detection** — phát hiện 1 anomaly không đủ; cần correlate nhiều metric để ra root cause
- **MLOps for DevOps**: không cần train model, nhưng phải quản lý model như service — deploy, monitor, rollback
