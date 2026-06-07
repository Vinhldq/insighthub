#!/usr/bin/env bash
# InsightHub — Verify Day 7 (Final Showcase State)
# Composite check — chạy tất cả verify-day-1..6 trước Day 7.
set -u

green(){ printf "\033[32m%s\033[0m\n" "$1"; }
red(){ printf "\033[31m%s\033[0m\n" "$1"; }

echo "=========================================="
echo "  InsightHub — Final State Verification"
echo "=========================================="
echo

TOTAL_FAIL=0

for day in 1 2 3 4 5 6; do
  echo "─────────── Day $day ───────────"
  if [ -x scripts/verify-day-${day}.sh ]; then
    if bash scripts/verify-day-${day}.sh; then
      green "Day $day: PASS"
    else
      red "Day $day: FAIL"
      TOTAL_FAIL=$((TOTAL_FAIL+1))
    fi
  else
    red "scripts/verify-day-${day}.sh không executable"
    TOTAL_FAIL=$((TOTAL_FAIL+1))
  fi
  echo
done

# Day 7 — Loom screencast required for all 15 students
echo "─────────── Day 7 Showcase ───────────"
if [ -f LOOM-DAY7.txt ] || grep -rqE "loom\.com" docs/day7-*.md 2>/dev/null; then
  green "  [PASS] Loom screencast URL được reference"
else
  red "  [FAIL] Loom screencast 3' chưa nộp"
  TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

# Self-eval
if [ -f docs/self-evaluation.md ] || [ -f SELF-EVAL.md ]; then
  green "  [PASS] Self-evaluation form completed"
else
  red "  [FAIL] Self-evaluation chưa fill"
  TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

echo
echo "=========================================="
if [ "$TOTAL_FAIL" -eq 0 ]; then
  green "✅ TẤT CẢ Day 1-7 PASS — Ready for Showcase!"
else
  red "❌ Còn $TOTAL_FAIL Day FAIL — fix trước Day 7"
  exit 1
fi
