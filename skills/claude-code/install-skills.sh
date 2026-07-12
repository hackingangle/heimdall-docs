#!/usr/bin/env bash
# Heimdall Harness 技能：自动检测本机 Harness 并安装/更新技能。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAW="https://raw.githubusercontent.com/hackingangle/heimdall-docs/main/skills/claude-code"
SKILLS=(heimdall-collect heimdall-material heimdall-doctor)

CLAUDE_DIR="$HOME/.claude/skills"
CURSOR_DIR="$HOME/.cursor/skills-cursor"
OPENCLAW_DIR="$HOME/.openclaw/skills"

declare -a TARGETS=()

detect_claude() { command -v claude &>/dev/null || [[ -d "$HOME/.claude" ]]; }
detect_cursor() { [[ -d "$HOME/.cursor" ]]; }
detect_openclaw() { command -v openclaw &>/dev/null || [[ -d "$HOME/.openclaw" ]]; }

use_local_source() {
  [[ -f "$SCRIPT_DIR/heimdall-collect/SKILL.md" ]]
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
  if detect_openclaw; then
    echo "  [已检测到] OpenClaw → $OPENCLAW_DIR"
    TARGETS+=("$OPENCLAW_DIR")
  else
    echo "  [跳过] OpenClaw（未检测到 openclaw 命令或 ~/.openclaw）"
  fi
  echo ""
}

install_to() {
  local dir="$1"
  mkdir -p "$dir"
  for skill in "${SKILLS[@]}"; do
    mkdir -p "$dir/$skill"
    if use_local_source; then
      cp "$SCRIPT_DIR/$skill/SKILL.md" "$dir/$skill/SKILL.md"
    else
      curl -fsSL "$REPO_RAW/$skill/SKILL.md" -o "$dir/$skill/SKILL.md"
    fi
    echo "  ✓ $skill"
  done
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
  echo "请确认已安装 Claude Code / Cursor / OpenClaw 之一，或手动指定："
  echo '  SKILLS_DIRS="$HOME/.claude/skills" bash install-skills.sh'
  exit 1
fi

if use_local_source; then
  echo "==> 从本地 heimdall-docs 安装/更新 Heimdall 技能"
else
  echo "==> 从 GitHub 安装/更新 Heimdall 技能"
fi

for dir in "${TARGETS[@]}"; do
  echo "→ $dir"
  install_to "$dir"
done

echo "✅ 完成：${SKILLS[*]}"
