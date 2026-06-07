#!/usr/bin/env bash
# InsightHub — Verify Day 2 (MCP Protocol)
set -u

PASS=0; FAIL=0
green(){ printf "\033[32m%s\033[0m\n" "$1"; }
red(){ printf "\033[31m%s\033[0m\n" "$1"; }
ok(){ green "  [PASS] $1"; PASS=$((PASS+1)); }
ng(){ red "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo "=== InsightHub — Verify Day 2 (MCP) ==="

# .mcp.json valid + ≥4 servers
if [ -f .mcp.json ]; then
  if jq empty .mcp.json 2>/dev/null; then
    ok ".mcp.json valid JSON"
    COUNT=$(jq '.mcpServers | length' .mcp.json)
    if [ "$COUNT" -ge 4 ]; then
      ok ".mcp.json có $COUNT MCP server (≥4)"
    else
      ng ".mcp.json chỉ có $COUNT server (cần ≥4)"
    fi
    # Check versions pinned
    if jq -r '.mcpServers[].args[]?' .mcp.json | grep -qE '@latest|@main' ; then
      ng "Có server dùng @latest hoặc @main (KHÔNG pin version)"
    else
      ok "Tất cả MCP server version pinned"
    fi
  else
    ng ".mcp.json không valid JSON"
  fi
else
  ng ".mcp.json không tồn tại"
fi

# claude mcp list (nếu Claude Code installed)
if command -v claude >/dev/null 2>&1; then
  if claude mcp list 2>&1 | grep -qE "✓|Connected"; then
    ok "claude mcp list shows Connected servers"
  else
    ng "claude mcp list — không server nào Connected"
  fi
fi

# debug-session log
if [ -f debug-session-day2.md ] || [ -f docs/debug-session-day2.md ]; then
  ok "debug-session-day2.md tồn tại"
else
  ng "debug-session-day2.md không tồn tại (1 case study)"
fi

# Allow-list check
if [ -f .mcp.json ]; then
  if jq -r '.mcpServers.filesystem.args[]?' .mcp.json 2>/dev/null | grep -qE '^/$|^\$HOME$|/home/[^/]+$' ; then
    ng "Filesystem MCP allow-list quá rộng (root, $HOME)"
  else
    ok "Filesystem MCP allow-list hợp lý"
  fi
fi

echo
echo "=== Kết quả: $PASS PASS / $FAIL FAIL ==="
[ "$FAIL" -eq 0 ] && green "✅ Day 2 OK" || { red "❌ Có FAIL — xem Day2-Spec.md"; exit 1; }
