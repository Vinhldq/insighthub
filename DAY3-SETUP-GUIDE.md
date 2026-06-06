# Day 3 Setup Guide — AWS Secrets + Deployment + Verification

> 📋 Complete checklist để hoàn thành Day 3 yêu cầu

---

## 🔑 Part 1: GitHub Secrets Configuration

### Step 1.1: Tạo AWS OIDC Identity Provider (1 lần)

Nếu chưa có, tạo OIDC provider cho GitHub:

```bash
# Kiểm tra xem OIDC provider đã tồn tại không
aws iam list-open-id-connect-providers --region us-east-1

# Nếu không, tạo mới
aws iam create-open-id-connect-provider \
  --url "https://token.actions.githubusercontent.com" \
  --client-id-list "sts.amazonaws.com" \
  --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1"
```

### Step 1.2: Tạo IAM Role cho GitHub Actions

```bash
# 1. Create trust policy file
cat > /tmp/github-trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:USERNAME/insighthub:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF

# 2. Thay ACCOUNT_ID + USERNAME vào
# 3. Create role
aws iam create-role \
  --role-name github-oidc-role \
  --assume-role-policy-document file:///tmp/github-trust-policy.json

# 4. Attach policy (admin for lab, limit for prod)
aws iam attach-role-policy \
  --role-name github-oidc-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# 5. Copy role ARN
aws iam get-role --role-name github-oidc-role --query 'Role.Arn' --output text
# → arn:aws:iam::ACCOUNT_ID:role/github-oidc-role
```

### Step 1.3: Set GitHub Secrets

📌 **Vào GitHub repo** → Settings → Secrets and variables → Actions

Thêm 5 secrets sau:

#### Secret 1: `AWS_ROLE_TO_ASSUME`
```
Value: arn:aws:iam::ACCOUNT_ID:role/github-oidc-role
```

#### Secret 2: `EKS_CLUSTER_NAME`
```
Value: (tên cluster EKS của bạn, vd: insighthub-cluster)

Cách tìm:
aws eks list-clusters --region us-east-1
```

#### Secret 3: `VPC_ID`
```
Value: vpc-xxxxxxxxx

Cách tìm:
aws ec2 describe-vpcs --region us-east-1 --query 'Vpcs[0].VpcId' --output text
```

#### Secret 4: `PRIVATE_SUBNET_IDS`
```
Value: ["subnet-xxx", "subnet-yyy"]

Cách tìm:
aws ec2 describe-subnets \
  --filters "Name=tag:Type,Values=Private" \
  --region us-east-1 \
  --query 'Subnets[*].SubnetId' \
  --output json
```

#### Secret 5: `INFRACOST_API_KEY` (Optional)
```
Value: (từ https://dashboard.infracost.io)

Nếu không có, workflow sẽ skip cost-estimate stage (không block)
```

### Step 1.4: Verify Secrets

```bash
# List secrets (không hiển thị values)
gh secret list

# Test OIDC connection
gh workflow run iac.yml --ref main --event push
```

---

## 🚀 Part 2: Trigger Pipeline

### Step 2.1: Create PR to trigger pipeline

```bash
# 1. Create branch
git checkout -b feat/day3-iac-complete

# 2. Make small change (trigger workflow on infra/)
echo "# Day 3 IaC Deployment Complete" >> infra/README.md

# 3. Commit
git add infra/README.md
git commit -m "[Day 3] IaC & Pipeline verification"

# 4. Push
git push origin feat/day3-iac-complete

# 5. Create PR on GitHub (go to https://github.com/USERNAME/insighthub/pull/new/feat/day3-iac-complete)
```

### Step 2.2: Monitor Pipeline

```bash
# Watch workflow
gh run list --workflow=iac.yml --limit 5

# View specific run
gh run view <RUN_ID> --log

# Expected output:
# ✓ fmt — terraform fmt check pass
# ✓ lint — tflint pass
# ✓ security-scan — checkov pass (no HIGH severity)
# ✓ validate-and-plan — plan generated
# ✓ cost-estimate — cost report (if INFRACOST_API_KEY set)
```

### Step 2.3: Verify Checkov Pass

```bash
# If you want to run locally:
# Install checkov
pip install checkov

# Run scan
checkov -d infra/ --framework terraform --soft-fail MEDIUM,LOW --hard-fail HIGH
```

---

## 🐳 Part 3: Deploy to Kubernetes

### Step 3.1: Prep K8s manifest

```bash
# 1. Get RDS endpoint (from terraform output or AWS console)
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier insighthub-dev \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

echo "RDS Endpoint: $RDS_ENDPOINT"

# 2. Get Redis endpoint
REDIS_ENDPOINT=$(aws elasticache describe-cache-clusters \
  --cache-cluster-id insighthub-dev \
  --show-cache-node-info \
  --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' \
  --output text)

echo "Redis Endpoint: $REDIS_ENDPOINT"

# 3. Update k8s/deployment.yaml
sed -i "s|RDS_ENDPOINT|${RDS_ENDPOINT}|g" k8s/deployment.yaml
sed -i "s|REDIS_ENDPOINT|${REDIS_ENDPOINT}|g" k8s/deployment.yaml

# 4. Verify substitution
grep "postgresql://" k8s/deployment.yaml
grep "redis://" k8s/deployment.yaml
```

### Step 3.2: Deploy manifest

```bash
# 1. Apply namespace + resources
kubectl apply -f k8s/deployment.yaml

# 2. Watch deployment progress
kubectl get pods -n insighthub-dev -w

# Expected: 5 pods Running
# - insighthub-api-xxx (2 replicas)
# - insighthub-worker-xxx (1 replica)
# + system pods

# 3. Verify health
kubectl logs -n insighthub-dev -l app=insighthub,component=api --tail 20
```

### Step 3.3: Port-forward for testing

```bash
# Terminal 1: Port-forward API
kubectl port-forward -n insighthub-dev svc/insighthub-api 8000:80 &

# Terminal 2: Port-forward (for web if needed)
kubectl port-forward -n insighthub-dev svc/insighthub-web 3000:80 &

# Keep running while testing
```

---

## ✅ Part 4: Smoke Tests

### Test 4.1: Upload Document

```bash
curl -X POST http://localhost:8000/upload \
  -F "file=@sample-docs/huong-dan-nguoi-moi.md" \
  -H "Accept: application/json" \
  -v

# Expected response:
# HTTP/1.1 202 Accepted
# Content-Type: application/json
# {"document_id": "...", "status": "queued", "message": "Document queued for processing"}
```

**Save `document_id` for next steps:**
```bash
DOC_ID="<from-response>"
```

### Test 4.2: Check Ingestion Status

```bash
# Wait 5-10 seconds for worker to process
sleep 10

# Check status
curl http://localhost:8000/documents/${DOC_ID}/status \
  -H "Accept: application/json" \
  -v

# Expected: 
# {"status": "ready", "chunks": 5, "embedded": true}
```

### Test 4.3: Chat Query

```bash
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{
    \"question\": \"Tài liệu này nói gì?\",
    \"document_id\": \"${DOC_ID}\",
    \"top_k\": 3
  }" \
  -v

# Expected:
# HTTP/1.1 200 OK
# Content-Type: application/json
# {"answer": "...", "sources": [...], "latency_ms": 450}
```

### Test 4.4: API Health

```bash
curl http://localhost:8000/health -v
# Expected: 200 OK

curl http://localhost:8000/healthz -v
# Expected: 200 OK

curl http://localhost:8000/readyz -v
# Expected: 200 OK
```

---

## 📋 Part 5: Verification Checklist

### Terraform IaC (Dim 2)

```
[ ] terraform fmt -check -recursive  → no diff
[ ] terraform validate  → success
[ ] tflint --recursive  → no warnings/errors
[ ] checkov -d infra/  → no HIGH severity
[ ] Conftest: conftest test --policy infra/policy terraform.tfplan.json  → pass
[ ] All resources have tags (Project, Environment, Owner, ManagedBy)
[ ] RDS: encrypted at rest, private, not public
[ ] Redis: private subnet, auth token enabled, TLS enabled
[ ] IRSA: ServiceAccount + IAM role binding exists
[ ] Secrets Manager: RDS + Redis credentials stored
```

### CI/CD Pipeline (Dim 3)

```
[ ] .github/workflows/iac.yml exists (6 stages)
[ ] Pipeline triggered on PR to infra/
[ ] Stage 1 (fmt) passes
[ ] Stage 2 (lint) passes
[ ] Stage 3 (security-scan) passes
[ ] Stage 4 (validate-and-plan) passes
[ ] Stage 5 (cost-estimate) passes (or skipped if no key)
[ ] PR has plan summary comment
[ ] Pipeline on main branch requires approval before apply
[ ] OIDC: no long-lived AWS keys, uses role-to-assume
[ ] GitHub secrets configured (5 secrets): AWS_ROLE_TO_ASSUME, EKS_CLUSTER_NAME, VPC_ID, PRIVATE_SUBNET_IDS
```

### Kubernetes Deployment

```
[ ] kubectl get ns insighthub-dev  → exists
[ ] kubectl get pods -n insighthub-dev  → 5+ Running
[ ] kubectl get sa insighthub -n insighthub-dev  → exists with IRSA annotation
[ ] kubectl logs -n insighthub-dev -l component=api  → no errors
[ ] kubectl logs -n insighthub-dev -l component=worker  → no errors
[ ] ConfigMap applied with env vars
[ ] Secret created (with RDS_URL + REDIS_URL)
[ ] Deployment: 2 api + 1 worker replicas
[ ] HPA configured (2-5 replicas, CPU/Memory metrics)
[ ] Service: ClusterIP on port 80→8000
[ ] Probes: liveness + readiness configured
```

### Smoke Tests

```
[ ] POST /upload → 202 Accepted (< 1 sec)
[ ] GET /documents/{id}/status → "ready" (< 30 sec)
[ ] POST /chat → 200 OK + non-empty answer
[ ] GET /health → 200 OK
[ ] GET /healthz → 200 OK
[ ] GET /readyz → 200 OK
```

### Documentation

```
[ ] ai-prompts/day3.md exists with ≥5 prompts
[ ] Each prompt has: Context, Prompt, Output, Why it worked, What I changed
[ ] PR [Day 3] created with title format
[ ] PR links: Terraform module, Pipeline run, Smoke test screenshots
[ ] Cost estimate report < $50/month (dev)
[ ] CLAUDE.md includes Day 3 notes
```

---

## 🔧 Part 6: Troubleshooting

### Pipeline Won't Start

**Problem**: Workflow doesn't trigger on PR
**Solution**:
```bash
# Check workflow syntax
gh workflow list -a
gh workflow view iac.yml

# Force trigger
gh workflow run iac.yml --ref main
```

### AWS Credentials Error

**Problem**: `Error: error assuming role: unable to assume role`
**Solution**:
```bash
# Verify OIDC trust policy includes repo
aws iam get-role --role-name github-oidc-role
# Check: sub should include "repo:USERNAME/insighthub:*"

# Regenerate trust policy and update
```

### Checkov Failures

**Problem**: Checkov returns HIGH severity checks
**Solution**:
```bash
# View specific failures
checkov -d infra/ --check HIGH

# Common fixes:
# - RDS must have storage_encrypted = true
# - RDS must have publicly_accessible = false
# - Redis must have at_rest_encryption_enabled = true
```

### K8s Pods Pending

**Problem**: `kubectl get pods` shows Pending
**Solution**:
```bash
# Describe pod to see events
kubectl describe pod -n insighthub-dev insighthub-api-xxx

# Common issues:
# - ImagePullBackOff: image not in ECR → build + push first
# - Insufficient resources: check node capacity
# - Secret/ConfigMap missing: verify mounted
```

### RDS Endpoint Wrong

**Problem**: Pods can't connect to RDS
**Solution**:
```bash
# Verify endpoint substitution
grep "postgresql://" k8s/deployment.yaml

# Test connection locally
psql postgresql://insighthub:PASSWORD@ENDPOINT:5432/insighthub -c "SELECT 1"

# If wrong, re-substitute
sed -i "s|old-endpoint|new-endpoint|g" k8s/deployment.yaml
kubectl apply -f k8s/deployment.yaml
```

---

## 📝 Example Commands Cheat Sheet

```bash
# AWS
aws iam list-open-id-connect-providers
aws eks list-clusters
aws ec2 describe-vpcs
aws rds describe-db-instances --db-instance-identifier insighthub-dev

# GitHub CLI
gh secret list
gh workflow list
gh run list --workflow=iac.yml
gh run view <RUN_ID> --log

# Terraform
terraform fmt -check -recursive
terraform validate
tflint --recursive
checkov -d infra/ --framework terraform

# Kubernetes
kubectl get ns
kubectl get pods -n insighthub-dev
kubectl logs -n insighthub-dev -l app=insighthub
kubectl port-forward -n insighthub-dev svc/insighthub-api 8000:80

# Curl Tests
curl -X POST http://localhost:8000/upload -F "file=@sample.md"
curl http://localhost:8000/documents/{id}/status
curl -X POST http://localhost:8000/chat -d '{"question": "..."}'
```

---

**✅ Follow this guide step-by-step. When all checklists pass → Day 3 COMPLETE!**
