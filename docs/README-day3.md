# Day 3 — IaC + Pipeline: Terraform Modular + Helm Chart + CI/CD

## Mục tiêu

Triển khai InsightHub infrastructure as code trên AWS EKS với:
- **Terraform modular** — reusable modules cho database, cache, IRSA, networking
- **Helm chart** — package tất cả K8s manifests
- **CI/CD pipeline** — 6-stage GitHub Actions với policy-as-code

## Kiến trúc IaC

```
insighthub/
├── infra/
│   ├── main.tf              # Root: gọi 4 modules
│   ├── variables.tf         # 15 input variables
│   ├── outputs.tf           # 11 outputs
│   ├── locals.tf            # Common tags + prefix
│   ├── providers.tf         # AWS + K8s providers
│   ├── backend.tf           # S3 state + DynamoDB lock
│   ├── .tflint.hcl          # Linting rules
│   ├── .checkov.yaml        # Security scan config
│   ├── policy/
│   │   └── terraform.rego   # Conftest policies (4 deny + 2 warn)
│   ├── modules/
│   │   ├── database/        # RDS PostgreSQL 16 + pgvector
│   │   ├── cache/           # ElastiCache Redis 7
│   │   ├── irsa/            # IAM Role for Service Account
│   │   └── networking/      # EKS node SG discovery
│   ├── helm/
│   │   └── insighthub/      # Helm chart (Chart + 7 templates)
│   ├── db/
│   │   └── init.sql         # Schema: documents + chunks + HNSW
│   └── terraform.tfvars.example
├── infra/k8s/mcp-readonly/  # K8s RBAC (SA + CR + CRB)
└── .github/workflows/iac.yml # 6-stage CI/CD
```

## 4 Terraform Modules

### database
RDS PostgreSQL 16 với pgvector extension:
- Private subnets, encryption at rest (KMS)
- Secrets Manager cho credentials
- Security group: chỉ 5432 từ EKS nodes
- Performance Insights tắt (cost-aware)
- CloudWatch logs export

### cache
ElastiCache Redis 7:
- Private subnets, TLS + AUTH token
- Secrets Manager cho connection string
- Automatic failover (Multi-AZ optional)

### irsa
IAM Roles for Service Accounts:
- OIDC trust với EKS cluster
- Least-privilege policies: RDS connect + Secrets read + CloudWatch logs
- K8s Namespace + ServiceAccount với IRSA annotation

### networking
- Discover EKS node security group qua data source
- Không tạo VPC mới — dùng existing

## Helm Chart

```bash
# Dry-run
helm template insighthub infra/helm/insighthub -f infra/helm/insighthub/values-dev.yaml

# Install
helm install insighthub infra/helm/insighthub \
  -f infra/helm/insighthub/values-dev.yaml \
  --namespace insighthub-dev --create-namespace

# Upgrade
helm upgrade insighthub infra/helm/insighthub \
  -f infra/helm/insighthub/values-dev.yaml

# Values override (dev → cheaper)
helm install insighthub infra/helm/insighthub \
  --set postgres.resources.requests.cpu=50m \
  --set redis.numCacheNodes=1
```

| Template | Resources |
|----------|-----------|
| postgres.yaml | StatefulSet + Service + ConfigMap (init SQL) |
| redis.yaml | StatefulSet + Service |
| api.yaml | Deployment + Service + HPA + PDB |
| worker.yaml | Deployment |
| web.yaml | Deployment + Service |
| secrets.yaml | Secret (DB + Redis URLs + API keys) |

## CI/CD Pipeline (6 Stages)

```
push/PR → [1.fmt] → [2.lint] → [3.security-scan] → [4.validate+plan] → [5.cost-estimate] → [6.apply]
                                   ↓                    ↓
                              Checkov scan        Plan artifact
                              (HIGH/CRITICAL       PR comment
                               hard-fail)           human review
```

| Stage | Tool | Action |
|-------|------|--------|
| 1. fmt | terraform fmt | Format check |
| 2. lint | tflint | Style + best practices |
| 3. security-scan | checkov | Hard-fail HIGH/CRITICAL |
| 4. validate-and-plan | terraform | Validate + plan + PR comment |
| 5. cost-estimate | infracost | Cost breakdown (PR only) |
| 6. apply | terraform apply | Manual approval gate, main only |

## Security Features

### 3-Layer Defense
1. **AI Generate**: terraform fmt + tflint (auto-fix style issues)
2. **Human Review**: plan output comment trên PR → approve
3. **Policy-as-Code**: checkov + conftest DENY rules

### Conftest Policies (terraform.rego)
```
DENY: RDS publicly accessible
DENY: RDS unencrypted
DENY: Redis no transit encryption
DENY: SSH 0.0.0.0/0
WARN: RDS prod without Multi-AZ
WARN: Redis no at-rest encryption
```

## Cost-Aware Configuration

| Resource | Dev | Prod |
|----------|-----|------|
| RDS | db.t3.micro, 20GB gp3 | db.t3.small, 20GB gp3 |
| Redis | cache.t3.micro, 1 node | cache.t3.small, 1 node |
| Multi-AZ | false | true |
| API replicas | 1 | 2 |
| Performance Insights | off | off |

Estimated cost: <$50/month dev, ~$80/month prod

## Commands

```bash
# Terraform
cd infra
terraform init
terraform fmt -check -recursive
tflint --recursive
checkov -d . --soft-fail-on LOW,MEDIUM
terraform validate
terraform plan
terraform apply

# Helm
helm template insighthub infra/helm/insighthub
helm lint infra/helm/insighthub
helm install insighthub infra/helm/insighthub -f values-dev.yaml

# Pipeline
gh run list --limit 5
gh run view <run-id>
```

## Artifacts Summary

| # | Artifact | Purpose |
|---|----------|---------|
| 1 | `infra/providers.tf` | AWS + K8s provider config |
| 2 | `infra/main.tf` | 4-module orchestration |
| 3 | `infra/variables.tf` | 15 input variables |
| 4 | `infra/outputs.tf` | 11 outputs |
| 5 | `infra/backend.tf` | S3 state + DynamoDB lock |
| 6 | `infra/locals.tf` | Common tags + prefix |
| 7 | `infra/modules/database/` | RDS module |
| 8 | `infra/modules/cache/` | Redis module |
| 9 | `infra/modules/irsa/` | IRSA module |
| 10 | `infra/modules/networking/` | Networking module |
| 11 | `infra/helm/insighthub/` | Helm chart |
| 12 | `infra/.tflint.hcl` | Linter config |
| 13 | `infra/.checkov.yaml` | Security scan config |
| 14 | `infra/policy/terraform.rego` | Policy-as-code |
| 15 | `infra/terraform.tfvars.example` | Variable template |
| 16 | `.github/workflows/iac.yml` | 6-stage CI/CD |
| 17 | `infra/k8s/mcp-readonly/` | K8s RBAC |
| 18 | `infra/db/init.sql` | DB schema |
