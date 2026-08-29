---
name: heimdall-sync
description: >
  把 Heimdall 平台智能体安装或更新到本机 Cursor / Claude Code / Codex。
  当用户要求同步智能体、安装到本地 harness、技能或人设过期、检查 Heimdall 环境是否最新时激活。
---

# Heimdall 智能体同步

平台智能体是真源。本机文件是只读投影：改人设去网页，再跑同步。

## 0. 一键更新（技能 + 智能体）

首次和更新都用网页「智能体」上那一条（已带 API 地址；已有 `~/.heimdall/env` 时不必重输 Token）：

```bash
curl -fsSL https://raw.githubusercontent.com/hackingangle/heimdall-docs/main/skills/claude-code/setup-heimdall.sh | bash -s -- "<API_BASE>"
```

本地仓库：`bash heimdall-docs/skills/claude-code/setup-heimdall.sh <API_BASE>`

会覆盖安装 `heimdall-sync` / `heimdall-platform`，并投影智能体。

## 1. 只同步智能体

```bash
source ~/.heimdall/env
curl -fsSL https://raw.githubusercontent.com/hackingangle/heimdall-docs/main/skills/claude-code/install-agents.sh | bash
```

本地：`bash heimdall-docs/skills/claude-code/install-agents.sh`

- 缺 env → 先跑 `setup-heimdall.sh <API_BASE>`（网页「智能体」可复制）。
- 平台列表为空 → 脚本会调用 `POST /agents/ensure-defaults` 补「收集员」「写稿」。
- 托管文件带 `heimdall_managed`；平台已删的投影会被清掉。不要手改投影，下次同步会覆盖。

## 2. 投影位置

| Harness | 管道技能 | 智能体 |
|---|---|---|
| Cursor | `~/.cursor/skills/heimdall-{sync,platform}/` | `~/.cursor/skills/heimdall-agent-{id}/SKILL.md` |
| Claude Code | `~/.claude/skills/heimdall-{sync,platform}/` | `~/.claude/agents/heimdall-agent-{id}.md` |
| Codex | `~/.agents/skills/heimdall-{sync,platform}/` | `~/.agents/skills/heimdall-agent-{id}/SKILL.md` |

## 3. 版本自检

```bash
curl -fsSL https://raw.githubusercontent.com/hackingangle/heimdall-docs/main/skills/claude-code/check-skills.sh | bash
```

退出码：0 对齐；1 过期或未安装（按打印的命令同步）；2 缺安装记录或拉不到真源。
