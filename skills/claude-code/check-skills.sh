#!/usr/bin/env bash
# Heimdall Harness 技能：检查本机各 Harness 的技能是否与 heimdall-docs main 一致。
# 退出码：0 全部对齐；1 有过期或未安装；2 无法比对（缺安装记录 / 拉不到真源）。
set -euo pipefail

CANONICAL_RAW="https://raw.githubusercontent.com/hackingangle/heimdall-docs/main/skills/claude-code"
# 真源默认取 heimdall-docs main；本地开发可用 REPO_RAW 指向别处（含 file:// 路径）。
REPO_RAW="${REPO_RAW:-$CANONICAL_RAW}"
SKILLS=(heimdall-collect heimdall-material heimdall-doctor heimdall-write)
LOCK_FILE="$HOME/.heimdall/skills.lock"
# 给用户的命令始终指向线上真源，不受 REPO_RAW 覆盖影响。
UPDATE_CMD="curl -fsSL $CANONICAL_RAW/install-skills.sh | bash"

lock_value() {
  sed -n "s/^$1=//p" "$LOCK_FILE" | tail -n 1
}

echo "==> Heimdall 技能版本自检"

if [[ ! -f "$LOCK_FILE" ]]; then
  echo "  未找到安装记录：$LOCK_FILE"
  echo "  技能还没用 install-skills.sh 装过，先跑一键初始化："
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

echo ""
if [[ $stale -eq 1 ]]; then
  echo "❌ 有技能过期或未安装。跑一条命令同步（不需要重输 Token）："
  echo "   $UPDATE_CMD"
  exit 1
fi

echo "✅ 全部技能与真源一致"
