#!/usr/bin/env bash
# InsightHub — Verify Day 6 (Security + FinOps)
set -u
PASS=0; FAIL=0
green(){ printf "\033[32m%s\033[0m\n" "$1"; }
red(){ printf "\033[31m%s\033[0m\n" "$1"; }
ok(){ green "  [PASS] $1"; PASS=$((PASS+1)); }
ng(){ red "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo "=== InsightHub — Verify Day 6 (Security + FinOps) ==="

# Promptfoo config
if [ -f security/promptfooconfig.yaml ]; then
  ok "promptfooconfig.yaml tồn tại"
  for plugin in prompt-injection indirect-prompt-injection pii excessive-agency; do
    if grep -q "$plugin" security/promptfooconfig.yaml; then
      ok "Plugin '$plugin' configured"
    else
      ng "Plugin '$plugin' missing"
    fi
  done
else
  ng "security/promptfooconfig.yaml không tồn tại"
fi

# Final scan report no HIGH/CRITICAL
if [ -f security/red-team-report.html ] || [ -f security/red-team-final.html ]; then
  ok "Promptfoo red team report tồn tại"
  # Check for HIGH/CRITICAL in report (rough)
  if grep -iE "critical|high.*failed" security/red-team-*.html 2>/dev/null | grep -v "0 critical" | grep -q "critical"; then
    ng "Report chứa HIGH/CRITICAL chưa fix"
  else
    ok "Report final — no HIGH/CRITICAL (best effort check)"
  fi
fi

# Threat model
if [ -f security/threat-model.md ]; then
  ok "threat-model.md tồn tại"
  THREAT_COUNT=$(grep -cE "^\|.*\|.*\|" security/threat-model.md || echo 0)
  if [ "$THREAT_COUNT" -ge 6 ]; then
    ok "Threat model có $THREAT_COUNT entries (≥6)"
  else
    ng "Threat model chỉ có $THREAT_COUNT entries (cần ≥6)"
  fi
else
  ng "security/threat-model.md không tồn tại"
fi

# Guardrails config
if [ -f security/bedrock-guardrail.json ] || [ -d security/nemo-config ]; then
  ok "Guardrails config tồn tại"
else
  ng "Guardrails config (Bedrock hoặc NeMo) không tồn tại"
fi

# LiteLLM gateway config
if [ -f litellm-config.yaml ] || [ -f security/litellm-config.yaml ]; then
  ok "LiteLLM gateway config tồn tại"

  # Check Anthropic prompt caching ref
  if grep -qE "cache_control|prompt-caching" api/app/services/llm.py 2>/dev/null; then
    ok "Anthropic prompt caching enabled trong code"
  fi
else
  ng "LiteLLM config không tồn tại"
fi

# Cost dashboard reference
if [ -f observability/cost-dashboard.json ] || grep -q "llm_cost\|tokens_total" observability/grafana-dashboards/*.json 2>/dev/null; then
  ok "Cost dashboard / panel detected"
else
  ng "Cost dashboard chưa setup"
fi

# AWS Budgets (if applicable)
if command -v aws >/dev/null; then
  if aws budgets describe-budgets --account-id "$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" 2>/dev/null | grep -q insighthub; then
    ok "AWS Budgets 'insighthub-*' configured"
  fi
fi

echo
echo "=== Kết quả: $PASS PASS / $FAIL FAIL ==="
[ "$FAIL" -eq 0 ] && green "✅ Day 6 OK" || { red "❌ Xem Day6-Spec.md"; exit 1; }
