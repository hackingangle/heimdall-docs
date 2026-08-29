#!/usr/bin/env bash
# Heimdall 管道技能：检测本机 Harness，安装/更新 heimdall-sync 与 heimdall-platform。
# 若已有 ~/.heimdall/env，接着同步平台智能体。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAW="https://raw.githubusercontent.com/hackingangle/heimdall-docs/main/skills/claude-code"
SKILLS=(heimdall-sync heimdall-platform)
LEGACY_SKILLS=(heimdall-collect heimdall-material heimdall-doctor heimdall-write)

CLAUDE_DIR="$HOME/.claude/skills"
CURSOR_DIR="$HOME/.cursor/skills"
CURSOR_LEGACY_DIR="$HOME/.cursor/skills-cursor"
CODEX_DIR="$HOME/.agents/skills"
OPENCLAW_DIR="$HOME/.openclaw/skills"
HERMES_DIR="$HOME/.hermes/skills/heimdall"
LOCK_FILE="$HOME/.heimdall/skills.lock"

declare -a TARGETS=()
declare -a SKILL_HASHES=()

detect_claude() { command -v claude &>/dev/null || [[ -d "$HOME/.claude" ]]; }
detect_cursor() { [[ -d "$HOME/.cursor" ]]; }
detect_codex() { command -v codex &>/dev/null || [[ -d "$HOME/.codex" ]]; }
detect_openclaw() { command -v openclaw &>/dev/null || [[ -d "$HOME/.openclaw" ]]; }
detect_hermes() { command -v hermes &>/dev/null || [[ -d "$HOME/.hermes" ]]; }

use_local_source() {
  [[ -f "$SCRIPT_DIR/heimdall-sync/SKILL.md" ]]
}

auto_detect_targets() {
  TARGETS=()
  echo "==> 检测本机 Harness 环境"
  if detect_claude; then
    echo "  [已检测到] Claude Code → $CLAUDE_DIR"
    TARGETS+=("$CLAUDE_DIR")
  else
    echo "  [跳过] Claude Code（未检测到 claude 命令或 ~/.claude）"
  fi
  if detect_cursor; then
    echo "  [已检测到] Cursor → $CURSOR_DIR"
    TARGETS+=("$CURSOR_DIR")
  else
    echo "  [跳过] Cursor（未检测到 ~/.cursor）"
  fi
  if detect_codex; then
    echo "  [已检测到] Codex → $CODEX_DIR"
    TARGETS+=("$CODEX_DIR")
  else
    echo "  [跳过] Codex（未检测到 codex 命令或 ~/.codex）"
  fi
  if detect_openclaw; then
    echo "  [已检测到] OpenClaw → $OPENCLAW_DIR"
    TARGETS+=("$OPENCLAW_DIR")
  else
    echo "  [跳过] OpenClaw（未检测到 openclaw 命令或 ~/.openclaw）"
  fi
  if detect_hermes; then
    echo "  [已检测到] Hermes → $HERMES_DIR"
    TARGETS+=("$HERMES_DIR")
  else
    echo "  [跳过] Hermes（未检测到 hermes 命令或 ~/.hermes）"
  fi
  echo ""
}

migrate_cursor_legacy() {
  [[ -d "$CURSOR_LEGACY_DIR" ]] || return 0
  local cleaned=0
  local dir
  for dir in "$CURSOR_LEGACY_DIR"/heimdall-*; do
    [[ -d "$dir" ]] || continue
    rm -rf "$dir"
    cleaned=1
  done
  if [[ $cleaned -eq 1 ]]; then
    echo "==> 已清理误装在 Cursor 内置技能目录的旧副本（${CURSOR_LEGACY_DIR}）"
    echo "    技能改装到 $CURSOR_DIR"
    echo ""
  fi
}

remove_legacy_skills() {
  local dir="$1"
  local name
  for name in "${LEGACY_SKILLS[@]}"; do
    if [[ -d "$dir/$name" ]]; then
      rm -rf "$dir/$name"
      echo "  − 已移除旧技能 $name"
    fi
  done
}

record_hash() {
  local skill="$1"
  local file="$2"
  local entry
  if [[ ${#SKILL_HASHES[@]} -gt 0 ]]; then
    for entry in "${SKILL_HASHES[@]}"; do
      if [[ "$entry" == "$skill="* ]]; then
        return 0
      fi
    done
  fi
  SKILL_HASHES+=("$skill=$(shasum -a 256 "$file" | awk '{print $1}')")
}

install_to() {
  local dir="$1"
  mkdir -p "$dir"
  remove_legacy_skills "$dir"
  for skill in "${SKILLS[@]}"; do
    mkdir -p "$dir/$skill"
    if use_local_source; then
      cp "$SCRIPT_DIR/$skill/SKILL.md" "$dir/$skill/SKILL.md"
    else
      curl -fsSL "$REPO_RAW/$skill/SKILL.md" -o "$dir/$skill/SKILL.md"
    fi
    record_hash "$skill" "$dir/$skill/SKILL.md"
    echo "  ✓ $skill"
  done
}

write_lock() {
  mkdir -p "$(dirname "$LOCK_FILE")"
  {
    echo "# Heimdall 技能安装记录（由 install-skills.sh 生成，供 check-skills.sh 比对）"
    if use_local_source; then
      echo "source=$SCRIPT_DIR"
    else
      echo "source=$REPO_RAW"
    fi
    echo "installed_at=$(date +%Y-%m-%dT%H:%M:%S%z)"
    echo "targets=${TARGETS[*]}"
    for entry in "${SKILL_HASHES[@]}"; do
      echo "$entry"
    done
  } >"$LOCK_FILE"
}

if [[ "${1:-}" == "--detect" ]]; then
  auto_detect_targets
  if [[ ${#TARGETS[@]} -eq 0 ]]; then
    echo "未检测到任何 Harness 环境。"
    exit 1
  fi
  exit 0
fi

if [[ -n "${SKILLS_DIRS:-}" ]]; then
  # shellcheck disable=SC2206
  TARGETS=($SKILLS_DIRS)
  echo "==> 使用手动指定的安装目录（SKILLS_DIRS）"
else
  auto_detect_targets
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "未检测到可安装的 Harness 环境。"
  echo "请确认已安装 Claude Code / Cursor / Codex / OpenClaw / Hermes 之一，或手动指定："
  echo '  SKILLS_DIRS="$HOME/.claude/skills" bash install-skills.sh'
  exit 1
fi

migrate_cursor_legacy

if use_local_source; then
  echo "==> 从本地 heimdall-docs 安装/更新 Heimdall 管道技能"
else
  echo "==> 从 GitHub 安装/更新 Heimdall 管道技能"
fi

for dir in "${TARGETS[@]}"; do
  echo "→ $dir"
  install_to "$dir"
done

write_lock

echo "✅ 完成：${SKILLS[*]}"
echo "   安装记录：${LOCK_FILE}（用 check-skills.sh 查是否过期）"

if [[ -f "${HEIMDALL_ENV_FILE:-$HOME/.heimdall/env}" ]]; then
  echo ""
  if [[ -f "$SCRIPT_DIR/install-agents.sh" ]]; then
    bash "$SCRIPT_DIR/install-agents.sh"
  else
    curl -fsSL "$REPO_RAW/install-agents.sh" | bash
  fi
fi
