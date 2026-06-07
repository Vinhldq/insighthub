#!/usr/bin/env bash
# InsightHub — Kiểm tra môi trường trước Day 1
# Chạy: bash scripts/verify-setup.sh
# Học viên phải fix mọi dòng [FAIL] trước buổi học đầu tiên.

set -u

PASS=0
FAIL=0

green() { printf "\033[32m%s\033[0m\n" "$1"; }
red()   { printf "\033[31m%s\033[0m\n" "$1"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$1"; }

check_cmd() {
  # $1 = tên lệnh, $2 = mô tả, $3 = optional ("opt")
  local cmd="$1" desc="$2" opt="${3:-}"
  if command -v "$cmd" >/dev/null 2>&1; then
    local ver
    ver=$("$cmd" --version 2>&1 | head -n1)
    green "[PASS] $desc — $ver"
    PASS=$((PASS+1))
  else
    if [ "$opt" = "opt" ]; then
      yellow "[SKIP] $desc — không bắt buộc, nhưng nên có"
    else
      red "[FAIL] $desc — chưa cài '$cmd'"
      FAIL=$((FAIL+1))
    fi
  fi
}

echo "=============================================="
echo " InsightHub — Pre-class Environment Check"
echo "=============================================="
echo

echo "--- Core tools ---"
check_cmd git    "Git"
check_cmd docker "Docker"
check_cmd node   "Node.js 20+"
check_cmd npm    "npm"
check_cmd python3 "Python 3.11+"
check_cmd pip3   "pip"
echo

echo "--- DevOps tools ---"
check_cmd kubectl   "kubectl"
check_cmd helm      "Helm"
check_cmd terraform "Terraform"
check_cmd aws       "AWS CLI v2"
echo

echo "--- AI tools ---"
check_cmd claude "Claude Code CLI"
echo

echo "--- Optional ---"
check_cmd cursor "Cursor" opt
check_cmd ngrok  "ngrok" opt
echo

echo "--- Docker daemon ---"
if docker info >/dev/null 2>&1; then
  green "[PASS] Docker daemon đang chạy"
  PASS=$((PASS+1))
else
  red "[FAIL] Docker daemon chưa chạy — mở Docker Desktop"
  FAIL=$((FAIL+1))
fi
echo

echo "--- Node.js version ---"
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]")
  if [ "$NODE_MAJOR" -ge 20 ]; then
    green "[PASS] Node.js major version = $NODE_MAJOR (>= 20)"
    PASS=$((PASS+1))
  else
    red "[FAIL] Node.js version $NODE_MAJOR quá cũ — cần >= 20"
    FAIL=$((FAIL+1))
  fi
fi
echo

echo "--- Python version ---"
if command -v python3 >/dev/null 2>&1; then
  PY_MINOR=$(python3 -c "import sys; print(sys.version_info[1])")
  PY_MAJOR=$(python3 -c "import sys; print(sys.version_info[0])")
  if [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -ge 11 ]; then
    green "[PASS] Python $PY_MAJOR.$PY_MINOR (>= 3.11)"
    PASS=$((PASS+1))
  else
    red "[FAIL] Python $PY_MAJOR.$PY_MINOR quá cũ — cần >= 3.11"
    FAIL=$((FAIL+1))
  fi
fi
echo

echo "--- InsightHub v0 (docker compose config) ---"
if [ -f "docker-compose.yml" ]; then
  if docker compose config >/dev/null 2>&1; then
    green "[PASS] docker-compose.yml hợp lệ"
    PASS=$((PASS+1))
  else
    red "[FAIL] docker-compose.yml lỗi cú pháp"
    FAIL=$((FAIL+1))
  fi
else
  yellow "[SKIP] Chạy script này từ thư mục gốc repo để check compose"
fi
echo

echo "=============================================="
echo " Kết quả: $PASS PASS / $FAIL FAIL"
echo "=============================================="
if [ "$FAIL" -gt 0 ]; then
  red "Còn $FAIL mục cần fix trước Day 1. Xem hướng dẫn ở Pre-class Checklist."
  exit 1
else
  green "Môi trường sẵn sàng. Bước tiếp theo: docker compose up --build"
  exit 0
fi
