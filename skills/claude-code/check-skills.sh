#!/usr/bin/env bash
# 检查本机管道技能是否与 heimdall-docs main 一致；有 env 时顺便看智能体投影记录。
# 退出码：0 全部对齐；1 有过期或未安装；2 无法比对。
set -euo pipefail

CANONICAL_RAW="https://raw.githubusercontent.com/hackingangle/heimdall-docs/main/skills/claude-code"
REPO_RAW="${REPO_RAW:-$CANONICAL_RAW}"
SKILLS=(heimdall-sync heimdall-platform)
LOCK_FILE="$HOME/.heimdall/skills.lock"
AGENTS_LOCK="$HOME/.heimdall/agents.lock"
ENV_FILE="$HOME/.heimdall/env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi
if [[ -n "${HEIMDALL_API_BASE:-}" ]]; then
  UPDATE_CMD="curl -fsSL $CANONICAL_RAW/setup-heimdall.sh | bash -s -- \"$HEIMDALL_API_BASE\""
else
  UPDATE_CMD="curl -fsSL $CANONICAL_RAW/setup-heimdall.sh | bash -s -- <API_BASE>"
fi

lock_value() {
  sed -n "s/^$1=//p" "$LOCK_FILE" | tail -n 1
}

echo "==> Heimdall 技能版本自检"

if [[ ! -f "$LOCK_FILE" ]]; then
  echo "  未找到安装记录：$LOCK_FILE"
  echo "  还没装过，先跑网页「智能体」上那一条："
  echo "    curl -fsSL $CANONICAL_RAW/setup-heimdall.sh | bash -s -- <API_BASE>"
  exit 2
fi

LOCK_SOURCE="$(lock_value source)"
INSTALLED_AT="$(lock_value installed_at)"
declare -a TARGETS=()
read -r -a TARGETS <<<"$(lock_value targets)"

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "  安装记录里没有 targets，重新装一次："
  echo "    $UPDATE_CMD"
  exit 2
fi

echo "  真源：$REPO_RAW"
echo "  安装记录：${LOCK_FILE}（${INSTALLED_AT}）"
if [[ "$LOCK_SOURCE" != "$REPO_RAW" ]]; then
  echo "  注意：本机技能装自本地仓库 ${LOCK_SOURCE}，差异可能是本地领先于 main。"
fi
echo ""

stale=0
for skill in "${SKILLS[@]}"; do
  if ! remote_hash="$(curl -fsSL "$REPO_RAW/$skill/SKILL.md" | shasum -a 256 | awk '{print $1}')"; then
    echo "  ✗ 无法从真源获取 ${skill}，检查网络后重试。"
    exit 2
  fi
  echo "$skill"
  for dir in "${TARGETS[@]}"; do
    file="$dir/$skill/SKILL.md"
    if [[ ! -f "$file" ]]; then
      echo "  未安装  $dir"
      stale=1
      continue
    fi
    if [[ "$(shasum -a 256 "$file" | awk '{print $1}')" == "$remote_hash" ]]; then
      echo "  对齐    $dir"
    else
      echo "  过期    $dir"
      stale=1
    fi
  done
done

if [[ -f "$AGENTS_LOCK" ]]; then
  echo ""
  echo "智能体投影记录：$AGENTS_LOCK"
  sed -n 's/^count=/  上次同步条数：/p' "$AGENTS_LOCK"
  echo "  人设有更新时再跑：$UPDATE_CMD"
else
  echo ""
  echo "  尚未同步智能体。有 ~/.heimdall/env 时跑："
  echo "    $UPDATE_CMD"
fi

echo ""
if [[ $stale -eq 1 ]]; then
  echo "❌ 有技能过期或未安装。再跑同一条安装命令（已有 env 不必重输 Token）："
  echo "   $UPDATE_CMD"
  exit 1
fi

echo "✅ 管道技能与真源一致"
