# Day 3 — AI Prompts for IaC Generation

## Prompt 1: Terraform Module Generation

### Context
Generate production-grade Terraform module for InsightHub deployment on AWS EKS.

### Prompt
```
Create a complete Terraform module for InsightHub infrastructure on AWS with these constraints:

SECURITY-FIRST (highest priority):
- RDS PostgreSQL 16 MUST be in private subnets, encryption at rest (KMS), no public IP
- ElastiCache Redis MUST be in private subnets, TLS + AUTH token
- Use IRSA (IAM Roles for Service Accounts) — NO long-lived IAM credentials
- All credentials in AWS Secrets Manager
- Least-privilege IAM policies (only RDS + Secrets access)

COST-AWARE (lab environment):
- RDS: db.t3.micro (free tier eligible)
- Redis: cache.t3.micro, 1 node
- Single-AZ (disable Multi-AZ for dev)
- Auto-backup 7 days

CONFIGURATION:
- Create Kubernetes namespace 'insighthub-<env>'
- Create ServiceAccount with IRSA annotation
- RDS database: PostgreSQL 16 with pgvector extension
- Security groups: minimize ingress (only from EKS nodes)
- KMS encryption for both RDS and Redis
- CloudWatch logs for monitoring

STRUCTURE:
- providers.tf: AWS + Kubernetes provider setup
- main.tf: All resources (namespace, RDS, Redis, IRSA)
- variables.tf: Inputs with validation (environment, cluster_name, vpc_id, subnet_ids)
- outputs.tf: RDS endpoint, Redis endpoint, secret ARNs
- backend.tf: S3 state + DynamoDB lock configuration

TAGS (mandatory on all resources):
- Project: insighthub
- Environment: var.environment
- Owner: platform-team
- ManagedBy: terraform
- CostCenter: engineering

Generate production-quality code with inline comments explaining security decisions.
```

### Output
- [infra/providers.tf](infra/providers.tf)
- [infra/main.tf](infra/main.tf)
- [infra/variables.tf](infra/variables.tf)
- [infra/outputs.tf](infra/outputs.tf)
- [infra/backend.tf](infra/backend.tf)

---

## Prompt 2: GitHub Actions CI/CD Pipeline

### Context
Create multi-stage GitHub Actions workflow implementing 3-layer defense for Terraform IaC.

### Prompt
```
Generate GitHub Actions workflow (.github/workflows/iac.yml) for Terraform CI/CD with stages:

STAGES (in order):
1. fmt — terraform fmt -check -recursive
2. lint — tflint --recursive (setup tflint, init, run)
3. security-scan — checkov framework=terraform, soft-fail MEDIUM/LOW, hard-fail HIGH
4. validate-and-plan — terraform init, validate, plan (output to artifact)
5. cost-estimate — infracost breakdown (only on PRs)
6. apply — terraform apply (manual approval, main branch only)

REQUIREMENTS:
- Run on: Ubuntu latest
- Trigger: push/PR to main/develop branches, only if infra/ changes
- Use AWS OIDC (no long-lived credentials) — assume role via ${{ secrets.AWS_ROLE_TO_ASSUME }}
- Environment: production with protected-branches policy for apply
- PR comments: Add terraform plan summary to PR
- Artifacts: Upload tfplan for reuse in apply job
- Secrets: AWS_ROLE_TO_ASSUME, EKS_CLUSTER_NAME, VPC_ID, PRIVATE_SUBNET_IDS, INFRACOST_API_KEY

APPLY JOB (main only):
- Requires: validate-and-plan + cost-estimate success
- Manual approval via environment
- Use downloaded tfplan artifact
- Log level: TF_LOG=INFO

Needs (depends_on):
- apply depends on [validate-and-plan, cost-estimate]
- cost-estimate depends on validate-and-plan
- validate-and-plan depends on [security-scan, lint]
- lint depends on fmt
- security-scan depends on lint

Permissions: id-token:write, contents:read, pull-requests:write (for PR comments)
```

### Output
- [.github/workflows/iac.yml](.github/workflows/iac.yml)

---

## Prompt 3: Linting & Policy Configuration

### Context
Configure tflint rules and Conftest Rego policies for automated compliance checks.

### Prompt
```
Create linting + policy-as-code configurations:

1. .tflint.hcl:
   - Enable AWS ruleset v0.31+
   - Enable Terraform ruleset
   - Enable rules: aws_instance_invalid_type, aws_db_instance_invalid_engine, 
                   aws_security_group_invalid_egress_rule, aws_resource_missing_tags,
                   aws_rds_db_instance_publicly_accessible, aws_elasticache_cluster_default_parameter_group
   - Require tags: Project, Environment, Owner, ManagedBy
   - Enforce: RDS not public, ElastiCache uses parameter groups

2. .tflintignore:
   - Disable aws_resource_missing_tags for exceptions (if needed)

3. infra/policy/terraform.rego (Conftest):
   - DENY: RDS publicly_accessible == true
   - DENY: RDS storage_encrypted != true
   - DENY: ElastiCache transit_encryption_enabled != true
   - DENY: Security group allows SSH from 0.0.0.0/0
   - WARN: RDS in prod without Multi-AZ
   - WARN: ElastiCache without at-rest encryption
```

### Output
- [infra/.tflint.hcl](infra/.tflint.hcl)
- [infra/.tflintignore](infra/.tflintignore)
- [infra/policy/terraform.rego](infra/policy/terraform.rego)

---

## Prompt 4: Kubernetes Deployment Manifests

### Context
Create Kubernetes YAML manifests for InsightHub deployment using IRSA ServiceAccount.

### Prompt
```
Generate Kubernetes deployment manifests (k8s/deployment.yaml):

RESOURCES:
1. ConfigMap: App config (LLM_PROVIDER, EMBEDDING_PROVIDER, LOG_LEVEL, etc.)
2. Secret: Database URL, Redis URL (populated from AWS Secrets Manager in runtime)
3. Deployment: insighthub-api
   - 2 replicas (HPA: 2-5, CPU 70%, Memory 80%)
   - Image: insighthubtest1-api:latest
   - ServiceAccount: insighthub (with IRSA)
   - Liveness: /healthz, 10s initial delay
   - Readiness: /readyz, 5s initial delay
   - Resources: req 100m CPU / 256Mi mem, limit 500m CPU / 512Mi mem
   - Env from ConfigMap + Secret

4. Deployment: insighthub-worker
   - 1 replica
   - Image: insighthubtest1-ingestion-worker:latest
   - Same ServiceAccount
   - Resources: req 200m CPU / 512Mi mem, limit 1 CPU / 1Gi mem

5. Service: ClusterIP for insighthub-api (port 80 → 8000)

6. HorizontalPodAutoscaler: CPU/memory based scaling

7. PodDisruptionBudget: minAvailable: 1 for api pods

Namespace: insighthub-dev
Labels: app=insighthub, component=(api|worker)
```

### Output
- [k8s/deployment.yaml](k8s/deployment.yaml)

---

## Prompt 5: Terraform Variables Example & Documentation

### Context
Provide template and documentation for deploying Terraform module.

### Prompt
```
Create:
1. terraform.tfvars.example: Template with all variables
2. Inline comments in main.tf explaining security decisions (IRSA setup, encryption, HNSW config)
3. outputs.tf: Clear output descriptions for post-apply reference

Variables example should show:
- AWS region, environment (dev/prod)
- EKS cluster name, VPC ID, private subnet IDs
- RDS config (instance class, storage size)
- Redis config (node type, num nodes)
- Encryption flags
- Example tags
```

### Output
- [infra/terraform.tfvars.example](infra/terraform.tfvars.example)
- Inline comments in [infra/main.tf](infra/main.tf)
- Inline comments in [infra/outputs.tf](infra/outputs.tf)

---

## Summary Table

| Artifact | Purpose | Status |
|----------|---------|--------|
| infra/providers.tf | AWS + K8s provider setup | ✅ |
| infra/main.tf | Core resources (EKS, RDS, Redis, IRSA) | ✅ |
| infra/variables.tf | Input validation | ✅ |
| infra/outputs.tf | Endpoint references | ✅ |
| infra/backend.tf | S3 state + locking | ✅ |
| infra/.tflint.hcl | Linter rules | ✅ |
| infra/policy/terraform.rego | Conftest policies | ✅ |
| .github/workflows/iac.yml | CI/CD pipeline | ✅ |
| k8s/deployment.yaml | K8s manifests | ✅ |
| infra/terraform.tfvars.example | Variable template | ✅ |

## Verification Commands

```bash
# Format check
terraform fmt -check -recursive infra/

# Validate
terraform validate infra/

# Lint
tflint --recursive infra/

# Security scan
checkov -d infra/ --framework terraform

# Test Rego policies
conftest test --policy infra/policy/terraform infra/tfplan.json
```

## 3-Layer Defense Checklist

Layer 1: AI Generate ✅
- All security defaults in place (KMS, private subnets, IRSA)
- Constraint validation in variables
- No hardcoded credentials

Layer 2: Human Review ✅
- PR workflow with plan comments
- Manual approval gate
- Cost estimation

Layer 3: Policy-as-Code ✅
- tflint: 8 rules enabled
- checkov: 250+ AWS policies
- Conftest: 5 custom Rego policies

---

Generated: 2026-06-02
Modified: Day 3 Lab Guide — AI-Powered IaC & Pipeline Engineering
