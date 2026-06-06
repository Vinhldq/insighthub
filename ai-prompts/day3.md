# Day 3 AI Prompts — IaC Generation (Terraform + CI/CD)

**Tool**: Claude Opus 4.6 + Terraform MCP Server
**Date**: 2026-06-06
**Workflow**: Constraint-first prompt (4-part) → PLAN review → Approve → Implement

---

## Prompt 1 — Terraform Module with 3-Layer Defense

**Tool**: Claude Opus 4.6 + Terraform MCP Server (provider/resource validation)
**Time**: 2026-06-06 14:00

**Prompt**:
Generate production-grade Terraform module for InsightHub on AWS EKS with 3-layer defense:

```
SECURITY-FIRST:
- RDS PostgreSQL 16 in private subnets, encryption at rest (KMS), no public IP
- ElastiCache Redis in private subnets, TLS + AUTH token enabled
- IRSA (IAM Roles for Service Accounts) — NO long-lived IAM credentials
- All credentials in AWS Secrets Manager
- Least-privilege IAM: only RDS connect + Secrets read
- Security groups: only 5432/6379 from EKS nodes

COST-AWARE (stay under $50/month):
- RDS: db.t3.micro + gp3 20GB
- Redis: cache.t3.micro, 1 node, single-AZ
- No Performance Insights, no provisioned IOPS

FILES: providers.tf, main.tf, variables.tf, outputs.tf, backend.tf
TAGS: Project, Environment, Owner, ManagedBy, CostCenter (mandatory)
```

**Why it worked**:
- 4-part structure (security → cost → config → files) prevents hallucination.
- Terraform MCP validated provider syntax against official registry.
- Agent generated `validation {}` blocks in variables → catches errors at plan time.

**What I changed**:
- Initially had `publicly_accessible = true` on RDS → changed to `false`.
- Added `auth_token_enabled = true` on Redis.
- Prefixed SG names with `insighthub-<env>-`.
- Used data source for existing EKS cluster (not creating new one).

---

## Prompt 2 — GitHub Actions CI/CD Pipeline (6 Stages)

**Tool**: Claude Opus 4.6
**Time**: 2026-06-06 15:00

**Prompt**:
Create `.github/workflows/iac.yml` with 6 stages implementing 3-layer defense:

```
LAYER 1 — AI Generate: fmt, lint
LAYER 2 — Human Review: plan with PR comment
LAYER 3 — Policy-as-Code: checkov (hard-fail HIGH/CRITICAL), cost-estimate

STAGES:
1. fmt → 2. lint → 3. security-scan → 4. validate-and-plan → 5. cost-estimate → 6. apply

OIDC: token.actions.githubusercontent.com, no long-lived AWS keys
GITHUB SECRETS: AWS_ROLE_TO_ASSUME, EKS_CLUSTER_NAME, VPC_ID, PRIVATE_SUBNET_IDS, INFRACOST_API_KEY
```

**Why it worked**:
- Explicit stage order with `needs:` creates DAG, no race conditions.
- Artifact upload/download persists plan across jobs.
- PR comment with plan summary enables human review (Layer 2).

**What I changed**:
- Removed hardcoded AWS keys → OIDC role assumption.
- Added artifact handoff (plan in stage 4, apply in stage 6).
- Made cost-estimate conditional (only on PR, skip if no API key).
- Added manual approval gate for apply on main.

---

## Prompt 3 — Linting & Policy Configuration

**Tool**: Claude Opus 4.6
**Time**: 2026-06-06 16:00

**Prompt**:
Configure policy-as-code layer:
1. `.tflint.hcl`: AWS + Terraform rulesets, required tags (Project/Environment/Owner/ManagedBy), severity ERROR
2. `terraform.rego`: DENY rules for RDS public, RDS unencrypted, Redis no TLS, SSH open to internet; WARN rules for prod without Multi-AZ

**Why it worked**:
- Separation: tflint (style) → checkov (security) → conftest (org policy).
- All three deterministic — same code = same result.

**What I changed**:
- Set severity to ERROR for critical rules.
- Fixed Rego syntax (mismatched curly braces in initial version).
- Added explicit deny for RDS public + SSH 0.0.0.0/0.

---

## Prompt 4 — K8s Deployment Manifests

**Tool**: Claude Opus 4.6
**Time**: 2026-06-06 16:30

**Prompt**:
Generate `k8s/deployment.yaml` with IRSA:
- Namespace `insighthub-dev`, ServiceAccount `insighthub` with IRSA annotation
- Deployment `insighthub-api`: 2 replicas, HPA 2-5, liveness /healthz, readiness /readyz
- Deployment `insighthub-worker`: 1 replica
- Service ClusterIP port 80→8000
- HPA: CPU 70%, Memory 80%
- PDB: minAvailable 1

---

## Prompt 5 — Terraform Variables + Documentation

**Tool**: Claude Opus 4.6
**Time**: 2026-06-06 17:00

**Prompt**:
Create `terraform.tfvars.example` and inline comments explaining:
- Why IRSA instead of IAM user
- Why pgvector in RDS not DynamoDB
- Why KMS keys vs AWS managed keys

---

## Artifacts Summary

| Artifact | Purpose | Status |
|----------|---------|--------|
| infra/providers.tf | AWS + K8s provider, S3 backend | ✅ |
| infra/main.tf | RDS, Redis, IRSA, KMS, SG, CloudWatch | ✅ |
| infra/variables.tf | Input validation | ✅ |
| infra/outputs.tf | Endpoint references | ✅ |
| infra/backend.tf | S3 state + DynamoDB lock | ✅ |
| infra/.tflint.hcl | Linter rules | ✅ |
| infra/policy/terraform.rego | Conftest policies | ✅ |
| infra/terraform.tfvars.example | Variable template | ✅ |
| .github/workflows/iac.yml | 6-stage CI/CD pipeline | ✅ |
| k8s/deployment.yaml | K8s manifests | ✅ |

## Verification

```bash
bash scripts/verify-day-3.sh   # → 9 PASS / 0 FAIL ✅
terraform fmt -check -recursive infra/
tflint --recursive infra/
checkov -d infra/ --framework terraform
```

**Status**: ✅ Complete — 10 artifacts, verification passing
