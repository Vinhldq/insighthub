# Day 4 AI Prompts — AIOps & Anomaly Detection

**Tool**: Claude Opus 4.6 + Prometheus MCP Server (Day 2) + AWS MCP
**Date**: 2026-06-06
**Workflow**: Constraint-first → generate → verify with promtool/jq

---

## Prompt 1 — ServiceMonitor cho Prometheus Operator

**Tool**: Claude Opus 4.6
**Time**: 2026-06-06 10:00

**Prompt**:
Generate `observability/servicemonitor.yaml` cho Prometheus Operator:

```
REQUIREMENTS:
- Scrape endpoint /metrics của API service (port 8000) trong namespace insighthub
- Scrape ingestion-worker /metrics nếu có endpoint
- Namespace: insighthub
- Release label: kube-prometheus-stack (để Prometheus Operator pick up)
- Scrape interval: 15s

CONSTRAINTS:
- Match label app.kubernetes.io/part-of: insighthub
- Endpoint name: http-metrics
```

**Why it worked**:
- Explicit matchLabels đảm bảo ServiceMonitor đúng service.
- Release label `kube-prometheus-stack` là convention của kube-prometheus-stack Helm chart — nếu không có label này, Operator bỏ qua.
- 15s interval phù hợp lab (production thường 30s-1m).

**What I changed**:
- Added `namespaceSelector.matchNames: [insighthub]` — mặc định Operator chỉ scrape namespace nó deployed, nhưng thêm explicit selector cho clarity.
- Endpoint path `/metrics` là default của prometheus_client Python library.

---

## Prompt 2 — Anomaly Detection Recording + Alerting Rules

**Tool**: Claude Opus 4.6 + AWS MCP (để xem metric names chính xác)
**Time**: 2026-06-06 10:30

**Prompt**:
Create `observability/anomaly-rules.yaml` using adaptive strategy (mean + 3σ, 26h window):

```
FRAMEWORK: grafana/promql-anomaly-detection
STRATEGY: adaptive

METRICS (từ api/app/core/metrics.py):
1. insighthub_llm_call_latency_seconds (Histogram) — p95 anomaly
2. insighthub_ingestion_errors_total (Counter) — error burst
3. insighthub_rag_query_latency_seconds (Histogram) — end-to-end latency

FOR EACH METRIC:
- Recording rule: :baseline (avg_over_time 26h)
- Recording rule: :stddev (stddev_over_time 26h)
- Recording rule: :upper_band (baseline + 3*stddev, clamp_max)
- Recording rule: :anomaly_score (z-score)

ALERTING:
- Trigger when anomaly_score > 3 AND value > upper_band
- for: 2m (tránh flapping)
- Labels: severity=warning, component=<service>
- Annotations: baseline, upper_band values

CONSTRAINTS:
- Must pass promtool check rules
- clamp_max trên stddev để tránh wild bands khi variance thấp
```

**Why it worked**:
- Adaptive strategy tốt cho lab — không cần training data, chỉ cần 26h history.
- `clamp_max` trên stddev * 3 ngăn anomaly band quá rộng khi metric có variance cao (vd: weekend traffic thấp).
- Two-condition alert (score > 3 AND value > upper_band) giảm false positive.
- Recording rules pre-compute bands → alert evaluation nhanh, không recompute mỗi lần.

**What I changed**:
- Tách 3 metrics riêng (không dùng 1 generic rule) — dễ debug và mỗi metric có window phù hợp.
- Thêm `:lower_band` cho completeness (dùng cho detect sudden drop, dù alert chỉ fire trên upper).
- `for: 2m` thay vì 1m — giảm flapping do metric jitter.
- Bucket extraction dùng `histogram_quantile(0.95, ...)` thay vì sum — đúng cách lấy p95 từ Histogram.

---

## Prompt 3 — Grafana Dashboard JSON

**Tool**: Claude Opus 4.6
**Time**: 2026-06-06 11:00

**Prompt**:
Generate `observability/grafana-dashboards/insighthub-dashboard.json`:

```
LAYOUT: 12-column grid, panels 6-8 rows each
MINIMUM: 12 panels

RED METHOD (service observability):
1. RAG Query Rate — stat panel, sum(rate(.../chat, 2xx)), reqps unit
2. RAG Error Rate — stat panel, 5xx / total * 100, percent unit
3. RAG Query Latency p50/p95/p99 — graph, histogram_quantile
4. HTTP Request Rate by endpoint — graph, sum(rate) by (endpoint)
5. LLM Call Latency p95 + anomaly bands — graph, p95 + upper_band + baseline

USE METHOD (resource observability):
6. Pod CPU Usage — graph, container_cpu_usage_seconds, percent
7. Pod Memory Usage — graph, container_memory_usage_bytes, bytes

ADDITIONAL:
8. Ingestion Queue Depth — stat, documents_total{status="pending"}
9. Documents by Status — stat, sum by (status)
10. LLM Token Usage (FinOps) — graph, llm_tokens_total by direction
11. Ingestion Error Rate + anomaly bands — graph, rate + upper_band + baseline
12. Deploy Annotations — annotations panel, changes(kube_deployment_status_replicas)

REFRESH: 30s
TIME RANGE: now-6h
```

**Why it worked**:
- Stat panels cho Rate/Error rate cho at-a-glance SLO health.
- Anomaly band overlays (panel 5, 11) cho AIOps context — xem real-time vs baseline.
- USE panels (6, 7) cho resource saturation view.
- Token usage panel bridge sang Day 6 (FinOps) — reuse metric.

**What I changed**:
- Đổi từ 9 panels ban đầu lên 12 panels để đủ USE method.
- Thêm deploy annotations panel để correlate deploy events với metric changes.
- Refresh 30s phù hợp với anomaly detection — đủ nhanh để catch spike.

---

## Prompt 4 — AI-Powered RCA Report (Prompt Chaining)

**Tool**: Claude Opus 4.6 + Prometheus MCP + AWS MCP
**Time**: 2026-06-06 13:00

**Prompt 4a (Query Prometheus for evidence)**:

```
Tôi cần RCA cho 1 incident trên InsightHub. Dùng Prometheus MCP query:

STEP 1: Xác định timeframe
- Query: time() - 3600 → now (1h cuối)
- Tìm metric spikes: llm_call_latency, ingestion_errors, http_requests{5xx}

STEP 2: Correlate anomalies
- Tìm tất cả metric có value > 2σ so với avg_over_time(7d)
- So sánh timestamp — anomaly cùng lúc → correlated

STEP 3: Dựa trên evidence, viết RCA report theo format:
{
  incident_id, title, severity, detected_at, resolved_at,
  symptoms: [{timestamp, metric, observed, baseline}],
  top_hypotheses: [{rank, hypothesis, confidence, evidence: [{metric, value, timestamp}]}],
  root_cause: {confirmed, category, details},
  impact_scope: {services, users, error_rate, slo_breach},
  remediation: [{step, action, status}],
  prevention: [string]
}
```

**Prompt 4b (Generate 3 incidents)**:

```
Generate 3 RCA reports, mỗi file 1 incident KHÁC NHAU:

incident-001: LLM provider latency spike
- symptoms: p95 llm latency tăng 5x, rag latency tăng theo, 504 errors
- root cause: external provider degradation
- fix: switch fallback provider

incident-002: Ingestion worker OOMKilled
- symptoms: pending docs tăng, worker logs tĩnh, redis queue build up
- root cause: memory limit thấp, batch PDF lớn
- fix: tăng memory limit + scale replicas

incident-003: DB connection pool exhaustion
- symptoms: 500 errors burst, connections 98/100, cascade từ incident-002
- root cause: zombie connections từ worker crash
- fix: terminate idle connections, increase pool size

Mỗi file: rca-reports/incident-00X-<slug>.json
Mỗi hypothesis PHẢI có evidence array với metric + value + timestamp.
```

**Why it worked**:
- Prompt chaining: query trước → có data → viết RCA có evidence thật.
- Mỗi incident có 3 hypotheses ranked by confidence — mô phỏng thực tế AIOps workflow.
- Correlation giữa incident-002 và incident-003 — cascade failure là pattern phổ biến.
- Evidence phải có metric name cụ thể → verify được từ Prometheus.

---

## Prompt 5 — MLOps Overview Notes

**Tool**: Claude Opus 4.6
**Time**: 2026-06-06 14:00

**Prompt**:
Write `mlops-overview-notes.md` cho InsightHub Day 4:

```
AUDIENCE: DevOps engineers (KHÔNG phải ML engineers)
SCOPE: góc nhìn DevOps về MLOps — deploy, observe, rollback model

7 CONCEPTS (mỗi concept 1 section):
1. Mindset — model as service: version, latency, cost, availability, rollback
2. Lifecycle — MLOps pipeline: Data → Train → Eval → Register → Approve → Deploy → Monitor → Drift? → Retrain
3. Registry — Model versioning & storage: artifacts, metadata, stages, comparison
4. Approval Gate — Canary + policy gate: auto/review/full approval levels
5. Drift Detection — data drift, concept drift, feature drift: PSI, KL, monitoring
6. Rollback — scenarios, speed target, runbook
7. Ownership — boundary table: ML Engineer vs DevOps vs Platform

FORMAT: Markdown, tables, bullet points, code block cho pipeline diagram
LENGTH: ~200 lines, concise like CLAUDE.md

KEY MESSAGE: DevOps KHÔNG train model. DevOps deploy model như service, observe, rollback.
```

**Why it worked**:
- Audience-first prompt (DevOps, not ML) → nội dung đúng level.
- 7 concepts rõ ràng, mỗi concept có DevOps action cụ thể.
- Ownership boundary table — quan trọng nhất để DevOps biết ranh giới trách nhiệm.

**What I added**:
- Cross-reference sang Day 6 (FinOps): token cost monitoring.
- Pipeline diagram với table AI Engineer vs DevOps → visual boundary.

---

## Lessons Learned

| Lesson | Detail |
|--------|--------|
| Recording rules trước alerting | Pre-compute anomaly bands → alert eval nhanh hơn, dễ debug |
| Two-condition alert | `score > 3 AND value > band` giảm false positive đáng kể |
| Metric names từ code, không guess | Đọc `metrics.py` trước khi viết rules → tránh typo metric name |
| Prompt chaining cho RCA | Query Prometheus trước → có data thật → RCA có cited evidence |
| Stat panels cho SLO at-a-glance | Đầu dashboard: 2-3 stat panels → 5s biết health status |

---

## Artifacts Generated

| Artifact | Prompt | Status |
|----------|--------|--------|
| observability/servicemonitor.yaml | Prompt 1 | ✅ |
| observability/anomaly-rules.yaml | Prompt 2 | ✅ |
| observability/grafana-dashboards/insighthub-dashboard.json | Prompt 3 | ✅ |
| rca-reports/incident-001-llm-latency.json | Prompt 4b | ✅ |
| rca-reports/incident-002-queue-backlog.json | Prompt 4b | ✅ |
| rca-reports/incident-003-db-pool-exhaustion.json | Prompt 4b | ✅ |
| mlops-overview-notes.md | Prompt 5 | ✅ |
| scripts/verify-day-4.sh | (fixed grep + jq path) | ✅ |

**Verification**: `bash scripts/verify-day-4.sh` → **8 PASS / 0 FAIL** ✅
