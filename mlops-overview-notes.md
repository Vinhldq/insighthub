# InsightHub — MLOps Overview Notes
# Day 4: AIOps — góc nhìn DevOps về MLOps
# DevOps engineer KHÔNG train model. Nhưng phải deploy, observe, và rollback model như 1 service.

---

## 1. Mindset — "Model as a Service"

Model không phải artifact tĩnh. Là 1 service có:
- **Version**: mỗi lần train → version mới (v1, v2, ...)
- **Latency**: inference time phải trong SLA (vd: p95 < 500ms)
- **Cost**: token/call × request volume → daily spend cần monitor
- **Availability**: model endpoint phải có uptime target (vd: 99.9%)
- **Rollback**: nếu v2 tệhơn v1 → cần khả năng revert nhanh

DevOps owns: deploy, observe, rollback. ML Engineer owns: train, tune, evaluate.

---

## 2. Lifecycle — MLOps Pipeline

```
Data → Train → Evaluate → Register → Approve → Deploy → Monitor → Drift? → Retrain
```

| Stage | Ai engineer | DevOps |
|---|---|---|
| Data collection | ✓ | — |
| Training | ✓ | — |
| Evaluation | ✓ | Review metrics |
| Model Registry | Push artifact | Manage infra |
| Approval gate | Request | Enforce policy |
| Deploy | — | Deploy + canary |
| Monitor | — | Alert on drift/regression |
| Retrain trigger | Decide | Auto-trigger pipeline |

**CI/CD cho model**: mỗi PR thay đổi training code → trigger train pipeline → eval → nếu pass → push registry. Khác CI code thường: pipeline chạy lâu hơn (giờ/chứ phút), cần GPU.

---

## 3. Registry — Model Versioning & Storage

**Model Registry** là version control cho model artifacts. Làm được gì:
- Lưu model files (weights, config, tokenizer)
- Gắn metadata: metrics, dataset version, training code commit SHA
- Stage management: Staging → Production → Archived
- Compare versions: v3 có accuracy cao hơn v2 nhưng latency cao hơn → trade-off

**Tools**: MLflow, Weights & Biases, SageMaker Model Registry, Vertex AI Model Registry.

**DevOps góc nhìn**: Registry = artifact store. CI pipeline push lên registry, CD pipeline pull từ registry để deploy. Khác Docker image: model artifact thường lớn (GB), cần storage riêng (S3, GCS).

---

## 4. Approval Gate — Cân bằng Innovation vs Risk

Không thể deploy mọi model version tự động. Cần approval gate:

| Gate level | Ví dụ | Automation |
|---|---|---|
| Auto-deploy | Hotfix model, latency improvement | ✓ CI/CD auto |
| Review required | Accuracy improvement > 2% | Human review metrics |
| Full approval | New architecture, new dataset | Board/lead sign-off |

**Canary deployment**: deploy v2 cho 5% traffic → monitor 24h → nếu OK → rollout 100%. Nếu drift hoặc latency spike → auto rollback.

**Policy as Code**: approval gate = OPA/Gatekeeper policy. VD: "model p95 latency > 500ms → block deploy".

---

## 5. Drift Detection — Model bị lỗi thời

Model performance giảm theo thời gian vì:
- **Data drift**: distribution input data thay đổi (vd: user behavior đổi sau Tết)
- **Concept drift**: relationship giữa input và output thay đổi (vd: "good" review definition đổi)
- **Feature drift**: feature engineering pipeline bị break

**Detection**:
- Statistical: KL divergence, PSI (Population Stability Index), KS test
- Monitor prediction distribution: nếu confidence scores shift → có drift
- Set threshold: PSI > 0.25 → trigger retrain pipeline

**Alert → Auto-retrain**: drift detected → alert → ML engineer review → retrain pipeline → eval → deploy.

---

## 6. Rollback — Khi Model Gây Hại

**Scenarios cần rollback**:
- Accuracy drop > threshold sau deploy
- Latency exceed SLA
- Bias/fairness issue phát hiện trong production
- Security: model bị adversarial attack

**Rollback speed**:
- Fast rollback: < 5 min (revert traffic routing, previous model version)
- Cần pre-approve rollback criteria trước khi deploy

**Runbook**:
1. Detect: monitoring alert hoặc user report
2. Triage: is it model v2 or upstream data issue?
3. Rollback: chuyển traffic về v1
4. Post-mortem: root cause + prevent recurrence
5. Fix + re-deploy

---

## 7. Ownership — Rõ ràng boundary

| Owner | Responsibilities | Tools |
|---|---|---|
| ML Engineer | Train, tune, evaluate, feature engineering | PyTorch, MLflow, Jupyter |
| DevOps Engineer | Deploy, observe, rollback, infra | K8s, Prometheus, CI/CD, Terraform |
| Platform Engineer | Registry, serving infra, GPU cluster | MLflow, KServe, KubeRay |

**Key boundary**: DevOps không cần hiểu model architecture. Nhưng phải hiểu:
- Model là 1 service → cần SLO/SLA
- Model có version → cần versioning strategy
- Model có cost → cần budget + FinOps (Day 6)
- Model có drift → cần monitoring + alerting

---

## Tổng kết

| Concept | DevOps action | Analogous to traditional DevOps |
|---|---|---|
| Mindset | Treat model as service | Treat app as service |
| Lifecycle | CI/CD pipeline cho model | CI/CD pipeline cho code |
| Registry | Versioned artifact store | Docker registry |
| Approval | Canary + policy gate | Code review + staging deploy |
| Drift | Monitor + auto-retrain | Monitor + alert + fix |
| Rollback | Fast revert to previous version | Rollback deployment |
| Ownership | Clear boundary: deploy/observe vs train/tune | Clear boundary: ops vs dev |
