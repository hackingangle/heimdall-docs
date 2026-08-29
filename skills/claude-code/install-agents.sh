#!/usr/bin/env bash
# 把平台智能体投影到本机 Cursor / Claude Code / Codex。
# 依赖 ~/.heimdall/env（HEIMDALL_API_BASE / HEIMDALL_API_TOKEN）。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${HEIMDALL_ENV_FILE:-$HOME/.heimdall/env}"
LOCK_FILE="$HOME/.heimdall/agents.lock"
REPO_RAW="https://raw.githubusercontent.com/hackingangle/heimdall-docs/main/skills/claude-code"

CURSOR_SKILLS="$HOME/.cursor/skills"
CLAUDE_AGENTS="$HOME/.claude/agents"
CODEX_SKILLS="$HOME/.agents/skills"

detect_claude() { command -v claude &>/dev/null || [[ -d "$HOME/.claude" ]]; }
detect_cursor() { [[ -d "$HOME/.cursor" ]]; }
detect_codex() { command -v codex &>/dev/null || [[ -d "$HOME/.codex" ]]; }

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

API_BASE="${HEIMDALL_API_BASE:-}"
TOKEN="${HEIMDALL_API_TOKEN:-}"
API_BASE="${API_BASE%/}"

if [[ -z "$API_BASE" || -z "$TOKEN" ]]; then
  echo "未找到 HEIMDALL_API_BASE / HEIMDALL_API_TOKEN。"
  echo "先跑 setup-heimdall.sh，或：source ~/.heimdall/env"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "需要 python3 才能解析智能体 JSON。"
  exit 1
fi

echo "==> 拉取平台智能体"
AGENTS_JSON="$(mktemp)"
trap 'rm -f "$AGENTS_JSON"' EXIT
HTTP_CODE="$(curl -sS -o "$AGENTS_JSON" -w "%{http_code}" \
  "$API_BASE/agents" -H "Authorization: Bearer $TOKEN")"
if [[ "$HTTP_CODE" != "200" ]]; then
  echo "错误：GET /agents 返回 $HTTP_CODE"
  exit 1
fi

COUNT="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$AGENTS_JSON")"
echo "  ${COUNT} 条"

if [[ "$COUNT" == "0" ]]; then
  echo "==> 平台尚无智能体，调用 ensure-defaults"
  ENSURE_CODE="$(curl -sS -o "$AGENTS_JSON" -w "%{http_code}" -X POST \
    "$API_BASE/agents/ensure-defaults" -H "Authorization: Bearer $TOKEN")"
  if [[ "$ENSURE_CODE" != "200" ]]; then
    echo "  ensure-defaults 不可用（HTTP ${ENSURE_CODE}），尝试按模板 POST"
    seed_from_templates() {
      local file="$1"
      local body
      if [[ -f "$SCRIPT_DIR/agent-templates/$file" ]]; then
        body="$(python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
print(json.dumps({"name":d["name"],"description":d["description"],"system_prompt":d["system_prompt"]},ensure_ascii=False))
' "$SCRIPT_DIR/agent-templates/$file")"
      else
        body="$(curl -fsSL "$REPO_RAW/agent-templates/$file" | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(json.dumps({"name":d["name"],"description":d["description"],"system_prompt":d["system_prompt"]},ensure_ascii=False))
')"
      fi
      curl -sS -X POST "$API_BASE/agents" \
        -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
        -d "$body" >/dev/null
    }
    seed_from_templates collector.json
    seed_from_templates writer.json
    curl -sS -o "$AGENTS_JSON" "$API_BASE/agents" -H "Authorization: Bearer $TOKEN"
  fi
  COUNT="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$AGENTS_JSON")"
  echo "  现在 ${COUNT} 条"
fi

declare -a SKILL_TARGETS=()
CLAUDE_AGENT_DIR=""

echo ""
echo "==> 检测本机 Harness（智能体投影）"
if detect_cursor; then
  echo "  [已检测到] Cursor → $CURSOR_SKILLS"
  SKILL_TARGETS+=("$CURSOR_SKILLS")
else
  echo "  [跳过] Cursor"
fi
if detect_codex; then
  echo "  [已检测到] Codex → $CODEX_SKILLS"
  SKILL_TARGETS+=("$CODEX_SKILLS")
else
  echo "  [跳过] Codex"
fi
if detect_claude; then
  echo "  [已检测到] Claude Code → $CLAUDE_AGENTS"
  CLAUDE_AGENT_DIR="$CLAUDE_AGENTS"
else
  echo "  [跳过] Claude Code"
fi

if [[ ${#SKILL_TARGETS[@]} -eq 0 && -z "$CLAUDE_AGENT_DIR" ]]; then
  echo "未检测到 Cursor / Claude Code / Codex，只写入安装记录。"
fi

SKILL_TARGETS_CSV="$(IFS=','; echo "${SKILL_TARGETS[*]}")"
export AGENTS_JSON SKILL_TARGETS_CSV CLAUDE_AGENT_DIR LOCK_FILE HEIMDALL_API_BASE

python3 - <<'PY'
import json, os, pathlib, re

agents = json.load(open(os.environ["AGENTS_JSON"]))
skill_roots = [p for p in os.environ.get("SKILL_TARGETS_CSV", "").split(",") if p]
claude_dir = os.environ.get("CLAUDE_AGENT_DIR") or ""
lock_path = pathlib.Path(os.environ["LOCK_FILE"])

def yaml_str(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)

def body(agent: dict) -> str:
    name = agent["name"]
    aid = agent["id"]
    prompt = (agent.get("system_prompt") or "").rstrip()
    desc = agent.get("description") or f"Heimdall 智能体「{name}」。"
    return (
        "---\n"
        f"name: heimdall-agent-{aid}\n"
        f"description: {yaml_str(desc)}\n"
        f"heimdall_agent_id: {aid}\n"
        "heimdall_managed: true\n"
        "---\n\n"
        f"# {name}\n\n"
        f"你是 Heimdall 智能体「{name}」（id={aid}）。"
        "入库、改素材、查项目时必须遵守 heimdall-platform。"
        "不要用 POST 带 agent_id 让服务端代跑。\n\n"
        f"{prompt}\n"
    )

def is_managed_skill(path: pathlib.Path) -> bool:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return False
    return "heimdall_managed: true" in text and "heimdall_agent_id:" in text

written = []
ids = {int(a["id"]) for a in agents}

for agent in agents:
    aid = int(agent["id"])
    content = body(agent)
    slug = f"heimdall-agent-{aid}"
    for root in skill_roots:
        dest = pathlib.Path(root) / slug / "SKILL.md"
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(content, encoding="utf-8")
        written.append(str(dest))
        print(f"  ✓ {dest}")
    if claude_dir:
        dest = pathlib.Path(claude_dir) / f"{slug}.md"
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(content, encoding="utf-8")
        written.append(str(dest))
        print(f"  ✓ {dest}")

removed = []
for root in skill_roots:
    base = pathlib.Path(root)
    if not base.is_dir():
        continue
    for child in base.iterdir():
        skill = child / "SKILL.md"
        if not skill.is_file() or not is_managed_skill(skill):
            continue
        m = re.search(r"heimdall_agent_id:\s*(\d+)", skill.read_text(encoding="utf-8"))
        if m and int(m.group(1)) not in ids:
            skill.unlink()
            try:
                child.rmdir()
            except OSError:
                pass
            removed.append(str(skill))
            print(f"  − {skill}")

if claude_dir:
    base = pathlib.Path(claude_dir)
    if base.is_dir():
        for path in base.glob("heimdall-agent-*.md"):
            if not is_managed_skill(path):
                continue
            m = re.search(r"heimdall_agent_id:\s*(\d+)", path.read_text(encoding="utf-8"))
            if m and int(m.group(1)) not in ids:
                path.unlink()
                removed.append(str(path))
                print(f"  − {path}")

lock_path.parent.mkdir(parents=True, exist_ok=True)
lines = [
    "# Heimdall 智能体投影记录（由 install-agents.sh 生成）",
    f"api_base={os.environ.get('HEIMDALL_API_BASE', '')}",
    f"count={len(agents)}",
    f"ids={' '.join(str(i) for i in sorted(ids))}",
]
for agent in agents:
    lines.append(f"agent_{agent['id']}={agent['name']}|{agent.get('updated_at', '')}")
lock_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"  记录：{lock_path}")
PY

echo "✅ 智能体已同步到本机"
