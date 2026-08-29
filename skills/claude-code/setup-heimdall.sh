#!/usr/bin/env bash
# Heimdall 一键安装/更新：装管道技能、写入 Token、补默认智能体并投影到本机。
# 已有 ~/.heimdall/env 且 Token 仍有效时不重复询问。
# 用法：bash setup-heimdall.sh <API_BASE>
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

echo "=== Heimdall 安装 / 更新 ==="
echo ""
echo "  API 地址: $API_BASE"
echo ""

TOKEN=""
if [[ -f "$ENV_FILE" ]]; then
  SAVED_API_BASE="$API_BASE"
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  API_BASE="$SAVED_API_BASE"
  if [[ -n "${HEIMDALL_API_TOKEN:-}" && "$HEIMDALL_API_TOKEN" =~ ^hd_ ]]; then
    TOKEN="$HEIMDALL_API_TOKEN"
    echo "  复用 ~/.heimdall/env 中的 Token，不重复输入"
  fi
fi

prompt_token() {
  echo "  Token 在网页「智能体」→ API 令牌（明文只显示一次）"
  echo ""
  read_line "请输入 API Token（hd_ 开头）: " TOKEN secret
  if [[ ! "$TOKEN" =~ ^hd_ ]]; then
    echo "错误：Token 应以 hd_ 开头。"
    exit 1
  fi
}

if [[ -z "$TOKEN" ]]; then
  prompt_token
fi

echo ""
echo "==> 验证 API 连接"
if ! curl -sS -f "$API_BASE/projects" -H "Authorization: Bearer $TOKEN" >/dev/null; then
  if [[ -f "$ENV_FILE" ]]; then
    echo "  已存 Token 无法连接，请重新输入。"
    echo ""
    prompt_token
    if curl -sS -f "$API_BASE/projects" -H "Authorization: Bearer $TOKEN" >/dev/null; then
      echo "  ✓ API 连接正常"
    else
      echo "错误：无法连接 Heimdall，请检查 API 地址与 Token 是否有效。"
      exit 1
    fi
  else
    echo "错误：无法连接 Heimdall，请检查 API 地址与 Token 是否有效。"
    exit 1
  fi
else
  echo "  ✓ API 连接正常"
fi

mkdir -p "$CONFIG_DIR"
cat >"$ENV_FILE" <<EOF
# Heimdall Harness 环境（由 setup-heimdall.sh 生成，请勿提交到 git）
export HEIMDALL_API_BASE="$API_BASE"
export HEIMDALL_API_TOKEN="$TOKEN"
EOF
chmod 600 "$ENV_FILE"

echo ""
echo "==> 安装管道技能并同步智能体"
if [[ -f "$SCRIPT_DIR/install-skills.sh" ]]; then
  bash "$SCRIPT_DIR/install-skills.sh"
else
  curl -fsSL "$INSTALL_SCRIPT_URL" | bash
fi

echo ""
echo "✅ 完成。同一条命令下次再跑即更新，不必重输 Token。"
echo ""
echo "在 Harness 终端先执行： source ~/.heimdall/env"
echo "然后：「用收集员给最新一期收素材」或「用写稿给项目 1 出大纲」"
