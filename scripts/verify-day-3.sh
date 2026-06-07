#!/usr/bin/env bash
# InsightHub — Verify Day 3 (IaC + Pipeline)
set -u
PASS=0; FAIL=0
green(){ printf "\033[32m%s\033[0m\n" "$1"; }
red(){ printf "\033[31m%s\033[0m\n" "$1"; }
ok(){ green "  [PASS] $1"; PASS=$((PASS+1)); }
ng(){ red "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo "=== InsightHub — Verify Day 3 (IaC + Pipeline) ==="

# Terraform files
if [ -f infra/main.tf ] || [ -f infra/providers.tf ]; then
  ok "infra/*.tf tồn tại"
  cd infra 2>/dev/null

  if command -v terraform >/dev/null; then
    terraform fmt -check -recursive >/dev/null 2>&1 && ok "terraform fmt OK" || ng "terraform fmt cần chạy"
  fi

  if command -v tflint >/dev/null; then
    tflint --recursive 2>/dev/null && ok "tflint pass" || ng "tflint có warning"
  fi

  if command -v checkov >/dev/null; then
    if checkov -d . --soft-fail-on LOW,MEDIUM --quiet 2>&1 | grep -qE "Failed checks: 0"; then
      ok "checkov no HIGH/CRITICAL"
    else
      HIGH=$(checkov -d . --output json 2>/dev/null | jq '[.results.failed_checks[] | select(.severity == "HIGH" or .severity == "CRITICAL")] | length' 2>/dev/null || echo "?")
      if [ "$HIGH" = "0" ]; then
        ok "checkov no HIGH/CRITICAL"
      else
        ng "checkov có $HIGH HIGH/CRITICAL finding"
      fi
    fi
  fi
  cd - >/dev/null
else
  ng "infra/ chưa có Terraform module"
fi

# GitHub Actions
if [ -f .github/workflows/iac.yml ] || ls .github/workflows/*.yml >/dev/null 2>&1; then
  ok ".github/workflows/*.yml tồn tại"

  # Check stages
  WF=$(cat .github/workflows/*.yml 2>/dev/null)
  for STAGE in fmt lint scan plan; do
    if echo "$WF" | grep -qiE "(name: $STAGE|$STAGE:|terraform $STAGE|tflint|checkov)"; then
      ok "Pipeline có stage liên quan '$STAGE'"
    else
      ng "Pipeline thiếu stage '$STAGE'"
    fi
  done
else
  ng ".github/workflows/iac.yml không tồn tại"
fi

# Check pipeline đã run
if command -v gh >/dev/null 2>&1; then
  if gh run list --limit 1 2>/dev/null | grep -q "completed.*success"; then
    ok "Pipeline run gần nhất: success"
  else
    ng "Pipeline run gần nhất: không success (check gh run view)"
  fi
fi

# kubectl deploy check (tùy lab)
if command -v kubectl >/dev/null; then
  if kubectl get ns 2>/dev/null | grep -qE "insighthub"; then
    ok "EKS namespace 'insighthub-*' tồn tại"
    POD_COUNT=$(kubectl get pods -n insighthub-dev 2>/dev/null | grep -c Running || echo 0)
    [ "$POD_COUNT" -ge 4 ] && ok "$POD_COUNT pod Running trên cluster" || ng "Chỉ $POD_COUNT pod Running"
  fi
fi

echo
echo "=== Kết quả: $PASS PASS / $FAIL FAIL ==="
[ "$FAIL" -eq 0 ] && green "✅ Day 3 OK" || { red "❌ Xem Day3-Spec.md"; exit 1; }
