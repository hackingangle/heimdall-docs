#!/usr/bin/env bash
# Heimdall 一键初始化：API 地址由参数传入，仅需交互输入 Token；自动检测 Harness 并安装技能。
# 用法：bash setup-heimdall.sh <API_BASE>
# 示例：bash setup-heimdall.sh http://localhost:8000/api
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/hackingangle/heimdall-docs/main/skills/claude-code/install-skills.sh"
CONFIG_DIR="$HOME/.heimdall"
ENV_FILE="$CONFIG_DIR/env"

API_BASE="${1:-}"
API_BASE="${API_BASE%/}"

if [[ -z "$API_BASE" ]]; then
  echo "用法: bash setup-heimdall.sh <API_BASE>"
  echo "示例: bash setup-heimdall.sh http://localhost:8000/api"
  exit 1
fi

read_line() {
  local prompt="$1"
  local var_name="$2"
  local secret="${3:-}"
  printf "%s" "$prompt"
  if [[ -n "$secret" ]]; then
    if [[ -t 0 ]]; then
      read -rs "$var_name"
    else
      read -rs "$var_name" < /dev/tty
    fi
    echo ""
  elif [[ -t 0 ]]; then
    read -r "$var_name"
  else
    read -r "$var_name" < /dev/tty
  fi
}

echo "=== Heimdall 初始化 ==="
echo ""
echo "  API 地址: $API_BASE"
echo "  Token 在网页右上角 → API Token 签发（明文只显示一次）"
echo ""
read_line "请输入 API Token（hd_ 开头）: " TOKEN secret

if [[ ! "$TOKEN" =~ ^hd_ ]]; then
  echo "错误：Token 应以 hd_ 开头。"
  exit 1
fi

echo ""
echo "==> 验证 API 连接"
if ! curl -sS -f "$API_BASE/projects" -H "Authorization: Bearer $TOKEN" >/dev/null; then
  echo "错误：无法连接 Heimdall，请检查 API 地址与 Token 是否有效。"
  exit 1
fi
echo "  ✓ API 连接正常"

echo ""
echo "==> 安装技能包"
if [[ -f "$SCRIPT_DIR/install-skills.sh" ]]; then
  bash "$SCRIPT_DIR/install-skills.sh"
else
  curl -fsSL "$INSTALL_SCRIPT_URL" | bash
fi

mkdir -p "$CONFIG_DIR"
cat >"$ENV_FILE" <<EOF
# Heimdall Harness 环境（由 setup-heimdall.sh 生成，请勿提交到 git）
export HEIMDALL_API_BASE="$API_BASE"
export HEIMDALL_API_TOKEN="$TOKEN"
EOF
chmod 600 "$ENV_FILE"

echo ""
echo "✅ 初始化完成"
echo ""
echo "以后在 Harness 终端先执行："
echo "  source ~/.heimdall/env"
echo ""
echo "然后即可开始收集任务，例如："
echo "  「围绕某选题给项目收集素材，项目 id 是 1」"
