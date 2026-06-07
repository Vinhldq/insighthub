#!/usr/bin/env bash
# InsightHub — Verify Day 5 (ChatOps Bot)
set -u
PASS=0; FAIL=0
green(){ printf "\033[32m%s\033[0m\n" "$1"; }
red(){ printf "\033[31m%s\033[0m\n" "$1"; }
ok(){ green "  [PASS] $1"; PASS=$((PASS+1)); }
ng(){ red "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo "=== InsightHub — Verify Day 5 (ChatOps Bot) ==="

# Skeleton hoàn thiện
if [ -d chatops-bot/app ]; then
  for f in main.py audit.py; do
    if [ -f "chatops-bot/app/$f" ]; then
      ok "chatops-bot/app/$f tồn tại"
    else
      ng "chatops-bot/app/$f thiếu"
    fi
  done

  # Permissions module
  if [ -f chatops-bot/app/permissions.py ]; then
    ok "permissions.py có (3-tier system)"
  else
    ng "permissions.py không tồn tại (cần 3-tier read/write/destructive)"
  fi

  # Signature verification implemented
  if grep -qE "verify_signature|hmac|x-slack-signature" chatops-bot/app/*.py 2>/dev/null; then
    ok "Slack signature verification implemented"
  else
    ng "Signature verification chưa implement"
  fi

  # NotImplementedError still in handle_question = chưa hoàn thiện
  if grep -q "NotImplementedError" chatops-bot/app/main.py 2>/dev/null; then
    ng "handle_question() vẫn raise NotImplementedError (chưa hoàn thiện)"
  else
    ok "handle_question() đã implement"
  fi
else
  ng "chatops-bot/app/ không tồn tại"
fi

# Dockerfile
if [ -f chatops-bot/Dockerfile ]; then
  ok "chatops-bot/Dockerfile tồn tại"
fi

# Bot deployable
if curl -sf http://localhost:8080/healthz >/dev/null 2>&1; then
  ok "Bot reachable local http://localhost:8080/healthz"
fi

# Audit log
if [ -f chatops-audit.log ] || [ -f chatops-bot/chatops-audit.log ]; then
  if jq -c '.' chatops-bot/chatops-audit.log 2>/dev/null | head -1 | jq -e '.ts and .user and .tool' >/dev/null 2>&1; then
    ok "Audit log: JSON structured với ts/user/tool"
  else
    ng "Audit log không đúng JSON structured format"
  fi
else
  ng "chatops-audit.log không có (bot chưa hoạt động)"
fi

# Loom screencast
if [ -f LOOM-URL.txt ] || grep -q "loom.com" docs/day5-*.md 2>/dev/null; then
  ok "Loom screencast URL được reference"
else
  ng "Loom screencast URL chưa nộp (xem Day5-Spec.md)"
fi

echo
echo "=== Kết quả: $PASS PASS / $FAIL FAIL ==="
[ "$FAIL" -eq 0 ] && green "✅ Day 5 OK" || { red "❌ Xem Day5-Spec.md"; exit 1; }
