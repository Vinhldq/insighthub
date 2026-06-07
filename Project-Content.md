# InsightHub - AI-Native DevOps Training Project

## 1. InsightHub Là Gì?

InsightHub là một ứng dụng **RAG (Retrieval-Augmented Generation) Notebook** tương tự Google NotebookLM, dùng để:

1. Upload tài liệu (`.txt`, `.md`, `.pdf`)
2. Chunk văn bản → Embed thành vector → Lưu vào pgvector
3. User hỏi → Retrieve chunk liên quan → Generate câu trả lời qua LLM

Đây là dự án đào tạo **AI-Native DevOps** trong 7 ngày. Học viên nhận app v0 đã chạy được, sau đó từng bước "DevOps-ize" hệ thống qua mỗi ngày học.

---

# 2. Các Dịch Vụ AWS Được Sử Dụng

| Dịch vụ AWS                  | Mục đích                   | Chi tiết                                                                  |
| ---------------------------- | -------------------------- | ------------------------------------------------------------------------- |
| EKS                          | Kubernetes cluster hiện có | Chạy API + Worker Pods, kết nối qua data source (không tạo EKS mới)       |
| RDS PostgreSQL 16 + pgvector | Database chính             | Lưu metadata + vector embeddings, `VECTOR(1024)`, HNSW index              |
| ElastiCache Redis 7          | Message broker + cache     | ARQ job queue, caching (TLS enabled)                                      |
| Secrets Manager              | Lưu credentials            | RDS password, Redis auth token, API keys                                  |
| IAM / IRSA                   | Quyền pod                  | IAM Role gắn vào ServiceAccount, cho phép truy cập RDS và Secrets Manager |
| KMS                          | Mã hóa dữ liệu             | Mã hóa dữ liệu lưu trữ trên RDS                                           |
| CloudWatch Logs              | Logging                    | Log group cho application logs                                            |
| S3                           | Remote state               | Lưu Terraform state                                                       |
| DynamoDB                     | State lock                 | Terraform state locking                                                   |
| Infracost                    | Cost governance            | Ước tính chi phí trước khi Terraform apply                                |

---

# 3. Phân Tích Chi Tiết 7 Ngày

## Day 1: Async Ingestion Refactor

### Mục tiêu

Chuyển ingestion từ đồng bộ sang bất đồng bộ bằng Redis + ARQ.

### Trước (v0)

```
API
 └── chunk
      └── embedding
            └── lưu DB
```

Request bị chặn cho tới khi xử lý xong.

### Sau (v1)

```
API
 └── Redis Queue
       └── Worker
             └── chunk
                   └── embedding
                         └── lưu DB
```

User nhận response ngay, worker xử lý nền.

### Deliverables

* Repo hoàn chỉnh
* `CLAUDE.md`
* Pull Request refactor
* Worker service hoạt động

### AWS

Chưa sử dụng AWS (docker-compose local).

---

## Day 2: MCP Protocol (Model Context Protocol)

### Mục tiêu

Cấu hình MCP Servers - "USB-C cho AI Agents".

### Công việc

* Tạo `.mcp.json`
* Tích hợp tối thiểu 4 MCP Servers
* Xây dựng các tools:

  * `search_documents`
  * `upload_document`
  * `get_document_metadata`

### Debug

Sử dụng MCP protocol để debug InsightHub.

### Deliverables

* `.mcp.json`
* Debug session log

### AWS

Chưa sử dụng AWS.

---

## Day 3: Terraform IaC + CI/CD + Kubernetes Deployment

### Mục tiêu

Tự động hóa infrastructure AWS và triển khai production lên Kubernetes.

### Terraform Infrastructure

#### Kubernetes

* Namespace
* IRSA IAM Role

#### Database

* RDS PostgreSQL 16 + pgvector
* Private Subnets
* KMS Encryption

#### Cache

* ElastiCache Redis 7
* TLS
* Auth Token

#### Supporting Services

* Security Groups
* Secrets Manager
* CloudWatch Logs

#### Terraform Backend

* S3 (State Storage)
* DynamoDB (State Lock)

---

### GitHub Actions Pipeline

1. **fmt**

   * Terraform format check

2. **lint**

   * TFLint

3. **security-scan**

   * Checkov
   * Fail khi có HIGH hoặc CRITICAL

4. **validate-and-plan**

   * Terraform validate
   * Terraform plan
   * Comment lên Pull Request

5. **cost-estimate**

   * Infracost (PR only)

6. **apply**

   * Chỉ chạy trên branch `main`
   * Manual approval qua GitHub Environment

---

### Kubernetes Deployment

#### Deployments

* API: 2 replicas
* Worker: 1 replica

#### Scaling

* HPA: 2 → 5 replicas

#### Reliability

* Pod Disruption Budget
* ClusterIP Service

#### Security

* IRSA Annotation

---

### Security

#### OIDC Authentication

Không sử dụng AWS Access Key lâu dài.

#### Conftest OPA Policy

Từ chối:

* Public RDS
* Redis không mã hóa
* Security Group mở SSH ra Internet

---

### Chi phí

Khoảng **50 USD/tháng**

Cấu hình:

* db.t3.micro
* cache.t3.micro

---

## Day 4: AIOps + MLOps Overview

### Mục tiêu

Vận hành và quan sát hệ thống AI.

### Monitoring

#### Prometheus Metrics

* Request latency
* Query throughput
* Vector search time
* Embedding latency

#### Grafana Dashboard

Hiển thị:

* API performance
* Retrieval performance
* Embedding performance

---

### Anomaly Detection

Phát hiện:

* Vector search latency spike
* Embedding failure rate tăng bất thường

---

### AI-Powered RCA

LLM hỗ trợ phân tích:

* Logs
* Metrics
* Root cause

---

### AWS

* CloudWatch
* CloudWatch Alarms
* Anomaly Detection

---

### MLOps Concepts

* Embedding quality monitoring
* Model versioning
* A/B testing embeddings

---

## Day 5: ChatOps + Incident Response

### Mục tiêu

Điều khiển và giám sát InsightHub qua Slack.

### Công việc

* Slack Bot hoạt động
* Trả lời:

  * Status
  * Health
  * Search documents

### Tái sử dụng

Backend MCP từ Day 2.

### Audit

Ghi nhận:

* Ai thực hiện
* Thời điểm
* Kết quả

### Mã nguồn

```
chatops-bot/
 ├── main.py
 └── audit.py
```

### AWS

Không cần dịch vụ AWS mới.

Bot chạy trong EKS.

---

## Day 6: Security + Governance + FinOps

### Mục tiêu

Bảo mật hệ thống AI và quản trị chi phí.

### Security

#### Promptfoo Red Team Testing

Kiểm thử:

* Prompt Injection
* RAG Poisoning
* PII Leakage
* Harmful Content

#### Guardrails

* Input validation
* Output filtering
* Rate limiting

#### Threat Modeling

* STRIDE hoặc
* DREAD

---

### FinOps

#### Cost Dashboard

* AWS Budgets
* CloudWatch Metrics
* SNS Notifications

### KPI

* Promptfoo: 0 HIGH findings
* Cost < 50 USD/tháng

---

## Day 7: Showcase

### Mục tiêu

Demo production-grade deployment.

### Nội dung

* Screencast
* Q&A

Học viên phải giải thích:

* Kiến trúc
* Quyết định kỹ thuật
* Code đã viết

Mục tiêu là chứng minh khả năng **hiểu hệ thống**, không chỉ "vibe coding".

---

# 4. Tổng Hợp Dịch Vụ AWS Theo Ngày

| Ngày    | Thành phần                                                                      |
| ------- | ------------------------------------------------------------------------------- |
| Day 1-2 | Local Docker Compose                                                            |
| Day 3   | EKS, RDS, ElastiCache, Secrets Manager, IAM/IRSA, KMS, CloudWatch, S3, DynamoDB |
| Day 4   | CloudWatch Alarms, Anomaly Detection                                            |
| Day 5   | Triển khai Slack Bot lên EKS                                                    |
| Day 6   | AWS Budgets, CloudWatch, SNS                                                    |
| Day 7   | Full Production Stack                                                           |

---

# 5. Kiến Trúc AWS Deployment (Day 3+)

```text
GitHub Actions (CI/CD)
fmt → lint → security → plan → cost → apply
           |
           v
+----------------------------------+
|          EKS Cluster             |
|                                  |
|  +-------------+  +-----------+  |
|  | API (x2)    |  | Worker    |  |
|  | IRSA Role   |  | IRSA Role |  |
|  +------+------|  +-----+-----+  |
|         |               |        |
|         +-------+-------+        |
|                 |                |
|         +-------v-------+        |
|         | PostgreSQL +  |        |
|         | pgvector      |        |
|         | (RDS)         |        |
|         +---------------+        |
|                                  |
|         +---------------+        |
|         | Redis TLS     |        |
|         | ElastiCache   |        |
|         +---------------+        |
+----------------------------------+

Supporting Services:
- Secrets Manager
- KMS
- CloudWatch Logs
- S3 (Terraform State)
- DynamoDB (State Lock)
```

---

# Ước Tính Chi Phí

## Development

* 30 – 50 USD/tháng

## Production

* 60 – 80 USD/tháng

Ví dụ:

* Multi-AZ
* db.t3.small
* cache.t3.small
