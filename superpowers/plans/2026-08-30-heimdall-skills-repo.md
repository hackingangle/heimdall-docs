# heimdall-skills 拆仓 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Harness 管道技能与安装脚本从 `heimdall-docs` 拆到公开仓 `hackingangle/heimdall-skills`，旧 raw URL 立刻作废，不留转发。

**Architecture:** 本地 `~/ws/heimdall/skills` 为新仓工作副本，根目录扁平（不再套 `skills/claude-code/`）。必须按「push 新仓 → 改前端并 bump VERSION → 再删 docs/skills」执行。curl 只打 `raw.githubusercontent.com/hackingangle/heimdall-skills/main/...`。

**Tech Stack:** GitHub 公开仓、bash 安装脚本、React/Vitest（`web/src/lib/skillsInstall.ts`）、Markdown/HTML 交接文档。

**Spec:** `docs/superpowers/specs/2026-08-30-heimdall-skills-repo-design.md`

---

## File Structure

| 路径 | 职责 |
|---|---|
| `skills/`（新 git 仓） | 管道技能真源 + `setup-heimdall.sh` 等 |
| `skills/setup-heimdall.sh` | 一键装技能、写 Token、调 install-skills |
| `skills/install-skills.sh` | 扇出 `heimdall-sync` / `heimdall-platform` |
| `skills/install-agents.sh` | 投影平台智能体 |
| `skills/check-skills.sh` | 与 main raw 比对是否过期 |
| `skills/heimdall-sync/SKILL.md` | 同步说明（curl 指向本仓根） |
| `skills/heimdall-platform/SKILL.md` | 素材 API 契约（无 docs URL） |
| `skills/agent-templates/*.json` | 默认收集员/写稿模板副本 |
| `web/src/lib/skillsInstall.ts` | 网页展示的 curl / 本地 hint |
| `web/src/lib/skillsInstall.test.ts` | 断言新 URL |
| `web/VERSION` | +1 |
| `docs/skills/` | **整目录删除** |
| `docs/README.md`、交接 md/html | 仓库表改为六仓；技能指向新仓 |
| `server/app/services/default_agents.py` | 仅改注释路径 |

禁止：在 `docs/` 留下任何 `setup-heimdall.sh` 或转发脚本。禁止把 `legacy/`、collect/write/doctor 拷进新仓。

---

### Task 1: 本地新建 `skills/` 并迁入现行文件

**Files:**
- Create: `/Users/ong/ws/heimdall/skills/`（独立 git 仓）
- Copy from: `docs/skills/claude-code/` 下列文件 only

- [ ] **Step 1: 建目录并只拷现行分发物**

```bash
mkdir -p /Users/ong/ws/heimdall/skills/heimdall-sync \
         /Users/ong/ws/heimdall/skills/heimdall-platform \
         /Users/ong/ws/heimdall/skills/agent-templates

SRC=/Users/ong/ws/heimdall/docs/skills/claude-code
DST=/Users/ong/ws/heimdall/skills

cp "$SRC/setup-heimdall.sh" "$DST/"
cp "$SRC/install-skills.sh" "$DST/"
cp "$SRC/install-agents.sh" "$DST/"
cp "$SRC/check-skills.sh" "$DST/"
cp "$SRC/detect-harness.sh" "$DST/"
cp "$SRC/heimdall-sync/SKILL.md" "$DST/heimdall-sync/"
cp "$SRC/heimdall-platform/SKILL.md" "$DST/heimdall-platform/"
cp "$SRC/agent-templates/collector.json" "$DST/agent-templates/"
cp "$SRC/agent-templates/writer.json" "$DST/agent-templates/"
printf '%s\n' '.DS_Store' > "$DST/.gitignore"
chmod +x "$DST"/*.sh
```

Expected: `ls "$DST"` 含五个 `.sh`、两个技能目录、`agent-templates`。**没有** `heimdall-collect` / `legacy`。

- [ ] **Step 2: 把旧 raw 路径换成新仓根**

```bash
DST=/Users/ong/ws/heimdall/skills
OLD='https://raw.githubusercontent.com/hackingangle/heimdall-docs/main/skills/claude-code'
NEW='https://raw.githubusercontent.com/hackingangle/heimdall-skills/main'

find "$DST" -type f \( -name '*.sh' -o -name '*.md' \) -print0 \
  | xargs -0 sed -i '' "s|${OLD}|${NEW}|g"

sed -i '' \
  -e 's|bash heimdall-docs/skills/claude-code/setup-heimdall.sh|bash skills/setup-heimdall.sh|g' \
  -e 's|bash heimdall-docs/skills/claude-code/install-agents.sh|bash skills/install-agents.sh|g' \
  -e 's|从本地 heimdall-docs|从本地 heimdall-skills|g' \
  -e 's|是否与 heimdall-docs main 一致|是否与 heimdall-skills main 一致|g' \
  -e 's|真源在 heimdall-docs main|真源在 heimdall-skills main|g' \
  "$DST/heimdall-sync/SKILL.md" \
  "$DST/install-skills.sh" \
  "$DST/check-skills.sh"
```

- [ ] **Step 3: 确认新仓内没有旧 URL**

```bash
rg -n 'heimdall-docs|skills/claude-code' /Users/ong/ws/heimdall/skills
```

Expected: 无匹配。若有，手工改掉再继续。

- [ ] **Step 4: 抽查 `REPO_RAW` 已指向仓根**

```bash
grep REPO_RAW /Users/ong/ws/heimdall/skills/install-skills.sh
grep INSTALL_SCRIPT_URL /Users/ong/ws/heimdall/skills/setup-heimdall.sh
```

Expected 各一行含：

`https://raw.githubusercontent.com/hackingangle/heimdall-skills/main`

（**没有**尾部 `/skills/claude-code`。）

---

### Task 2: 新仓 README + git init + 公开远程 + push

**Files:**
- Create: `/Users/ong/ws/heimdall/skills/README.md`
- Create: `/Users/ong/ws/heimdall/skills/.git`

- [ ] **Step 1: 写 README**

`/Users/ong/ws/heimdall/skills/README.md` 全文：

```markdown
# Heimdall Skills

Harness 管道技能真源。安装脚本从本仓 GitHub raw 拉取。

策略（收集怎么拆、稿怎么写）在平台智能体，不在本仓。本仓只做管道：`heimdall-sync`、`heimdall-platform`。

## 安装 / 更新

网页「智能体」会给出带 API 地址的命令。等价于：

```bash
curl -fsSL https://raw.githubusercontent.com/hackingangle/heimdall-skills/main/setup-heimdall.sh | bash -s -- "<API_BASE>"
```

本地工作区已 clone 时：

```bash
bash skills/setup-heimdall.sh "<API_BASE>"
```

## 仓库布局

| 路径 | 用途 |
|---|---|
| `setup-heimdall.sh` | 写 Token、装技能、同步智能体 |
| `install-skills.sh` | 扇出 sync / platform 到本机 Harness |
| `install-agents.sh` | 把平台智能体投影到本机 |
| `check-skills.sh` | 与 main raw 比对是否过期 |
| `heimdall-sync/` | 同步技能正文 |
| `heimdall-platform/` | 素材 API 契约 |
| `agent-templates/` | 默认收集员 / 写稿模板（平台 `ensure-defaults` 的对照副本） |

产品文档在 [heimdall-docs](https://github.com/hackingangle/heimdall-docs)。
```

- [ ] **Step 2: git init 并做 initial commit**

```bash
cd /Users/ong/ws/heimdall/skills
git init -b main
git add README.md .gitignore setup-heimdall.sh install-skills.sh install-agents.sh \
  check-skills.sh detect-harness.sh heimdall-sync heimdall-platform agent-templates
git status
git commit -m "$(cat <<'EOF'
feat: Heimdall Harness 管道技能独立成仓

从 heimdall-docs 迁出安装脚本与 sync/platform，raw 真源改为本仓根目录。
EOF
)"
```

Expected: `git status` 干净，`main` 上有 1 个 commit。

- [ ] **Step 3: 创建公开仓并 push（硬门：未成功则停止，不改前端、不删 docs）**

若组织下尚无该仓：

```bash
cd /Users/ong/ws/heimdall/skills
gh repo create hackingangle/heimdall-skills --public --source=. --remote=origin --push
```

若空仓已存在：

```bash
cd /Users/ong/ws/heimdall/skills
git remote add origin https://github.com/hackingangle/heimdall-skills.git
git push -u origin main
```

Expected: GitHub 上仓库 Public；`git remote -v` 指向 `hackingangle/heimdall-skills`。

- [ ] **Step 4: 验证 raw 可拉**

```bash
curl -fsSL https://raw.githubusercontent.com/hackingangle/heimdall-skills/main/setup-heimdall.sh | head -n 5
```

Expected: 输出以 `#!/usr/bin/env bash` 开头。失败则修可见性/分支名后再试，**不要进入 Task 3**。

---

### Task 3: 前端安装 URL（先改测试）

**Files:**
- Modify: `web/src/lib/skillsInstall.test.ts`
- Modify: `web/src/lib/skillsInstall.ts`
- Modify: `web/VERSION`

工作目录：`/Users/ong/ws/heimdall/web`（独立 git）。

- [ ] **Step 1: 把测试改成新 URL（此时实现未改，测试应失败）**

将 `web/src/lib/skillsInstall.test.ts` 全文换成：

```typescript
import { describe, expect, it } from "vitest";
import {
  getLocalSetupHint,
  getLocalUpdateHint,
  getSetupCommand,
  getUpdateCommand,
} from "./skillsInstall";

describe("skillsInstall", () => {
  it("builds setup command with api base argument", () => {
    const api = "https://www.agoodbit.com/api";
    expect(getSetupCommand(api)).toBe(
      `curl -fsSL https://raw.githubusercontent.com/hackingangle/heimdall-skills/main/setup-heimdall.sh | bash -s -- "${api}"`,
    );
    expect(getLocalSetupHint(api)).toBe(
      `bash skills/setup-heimdall.sh "${api}"`,
    );
  });

  it("builds update command without token or api base", () => {
    expect(getUpdateCommand()).toBe(
      "curl -fsSL https://raw.githubusercontent.com/hackingangle/heimdall-skills/main/install-skills.sh | bash",
    );
    expect(getLocalUpdateHint()).toBe("bash skills/install-skills.sh");
  });
});
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /Users/ong/ws/heimdall/web && npx vitest run src/lib/skillsInstall.test.ts
```

Expected: FAIL，断言里仍是 `heimdall-docs`。

- [ ] **Step 3: 改实现**

将 `web/src/lib/skillsInstall.ts` 全文换成：

```typescript
/** heimdall-skills 初始化脚本（GitHub raw）。 */
export const SETUP_SCRIPT_URL =
  "https://raw.githubusercontent.com/hackingangle/heimdall-skills/main/setup-heimdall.sh";

/** heimdall-skills 技能安装/更新脚本（GitHub raw）。 */
export const INSTALL_SCRIPT_URL =
  "https://raw.githubusercontent.com/hackingangle/heimdall-skills/main/install-skills.sh";

/** 一键安装/更新：API 地址已带入参数；已有有效 Token 则不再询问。 */
export function getSetupCommand(apiBase: string): string {
  return `curl -fsSL ${SETUP_SCRIPT_URL} | bash -s -- "${apiBase}"`;
}

/** 一键更新技能：覆盖本机技能文件，无需重新输入 Token。 */
export function getUpdateCommand(): string {
  return `curl -fsSL ${INSTALL_SCRIPT_URL} | bash`;
}

/** 本地已有脚本时可直接运行。 */
export function getLocalSetupHint(apiBase: string): string {
  return `bash skills/setup-heimdall.sh "${apiBase}"`;
}

/** 本地已有 heimdall-skills 时，直接更新技能。 */
export function getLocalUpdateHint(): string {
  return "bash skills/install-skills.sh";
}
```

- [ ] **Step 4: 再跑测试**

```bash
cd /Users/ong/ws/heimdall/web && npx vitest run src/lib/skillsInstall.test.ts src/pages/AgentsPage.test.tsx src/components/HarnessInstallPanel.test.tsx
```

Expected: PASS。

- [ ] **Step 5: bump 前端 VERSION 并 commit**

```bash
cd /Users/ong/ws/heimdall/web
echo $(( $(tr -d '[:space:]' < VERSION) + 1 )) > VERSION
git add src/lib/skillsInstall.ts src/lib/skillsInstall.test.ts VERSION
git commit -m "$(cat <<'EOF'
fix: 智能体安装命令改指向 heimdall-skills

管道技能已独立公开仓，curl raw 不再打 heimdall-docs。
EOF
)"
```

Expected: `VERSION` 比改前 +1（当前为 14 则变为 15）。**此时不要删 docs/skills。** 生产 Deploy 前线上仍指向旧 URL，这是预期窗口。

---

### Task 4: 后端注释（不 bump VERSION）

**Files:**
- Modify: `server/app/services/default_agents.py` 文件头

- [ ] **Step 1: 改注释路径**

把：

```python
heimdall-docs/skills/claude-code/agent-templates/.
```

换成：

```python
heimdall-skills/agent-templates/.
```

不改 `TEMPLATE_VERSION`、不改 prompt 正文、不改 `server/VERSION`。

- [ ] **Step 2: commit（server 仓）**

```bash
cd /Users/ong/ws/heimdall/server
git add app/services/default_agents.py
git commit -m "$(cat <<'EOF'
docs: 默认智能体模板对照路径改为 heimdall-skills
EOF
)"
```

---

### Task 5: 从 docs 删除技能并改交接文档

**前置：** Task 2 Step 4 的 curl 已成功；Task 3 前端已 commit。

**Files:**
- Delete: `docs/skills/` 整个目录
- Modify: `docs/README.md`
- Modify: `docs/Heimdall-技术实现交接.md`
- Modify: `docs/Heimdall-技术实现交接.html`
- Modify: `docs/Heimdall-交接手册.html`
- Already present: `docs/superpowers/specs/2026-08-30-heimdall-skills-repo-design.md`
- Already present: `docs/superpowers/plans/2026-08-30-heimdall-skills-repo.md`

工作目录：`/Users/ong/ws/heimdall/docs`。

- [ ] **Step 1: 删除本仓技能树**

```bash
cd /Users/ong/ws/heimdall/docs
git rm -r skills
```

Expected: `skills/` 不再存在。不要另写转发脚本。

- [ ] **Step 2: 改 `docs/README.md`**

「目录」里 Harness 技能整节换成：

```markdown
### Harness 技能（供外部 Agent 装载）

技能真源在独立公开仓 [heimdall-skills](https://github.com/hackingangle/heimdall-skills)（本地 `~/ws/heimdall/skills`）。本仓不托管安装脚本。

```bash
curl -fsSL https://raw.githubusercontent.com/hackingangle/heimdall-skills/main/setup-heimdall.sh | bash -s -- "<API_BASE>"
```
```

在「设计规格」列表追加：

```markdown
- [`superpowers/specs/2026-08-30-heimdall-skills-repo-design.md`](./superpowers/specs/2026-08-30-heimdall-skills-repo-design.md) — 管道技能拆到 heimdall-skills
```

- [ ] **Step 3: 改 `Heimdall-技术实现交接.md`**

把「里面是 5 个独立 GitHub 仓」改为「6 个」。

Mermaid 在 `DOC` 节点后加：

```text
  WS --> SK["skills/<br/>heimdall-skills<br/>PUBLIC"]
```

仓库表：`docs/` 行改为：

```markdown
| `docs/` | [heimdall-docs](https://github.com/hackingangle/heimdall-docs) | 公开 | Markdown / HTML | 不部署 ECS；仅文档 | 无 Deploy |
| `skills/` | [heimdall-skills](https://github.com/hackingangle/heimdall-skills) | 公开 | bash / SKILL.md | 不部署 ECS；`setup-heimdall.sh` 从此仓 raw 拉 | 无 Deploy |
```

clone 块追加：

```bash
git clone https://github.com/hackingangle/heimdall-skills.git  skills
```

将 `### 4.5 heimdall-docs` 整节换成：

```markdown
### 4.5 heimdall-docs（`docs/`）

公开。只放 PRD、交接与设计规格，**不是**安装脚本真源。

| 文件 | 用途 |
|---|---|
| `prds/Heimdall PRD 1.0.md` | 现行产品说明 |
| `Heimdall-技术实现交接.md` | 本文 |
| `superpowers/specs/` | 设计规格 |
| `prds/Heimdall PRD.md` | 旧愿景，勿当实现依据 |

### 4.6 heimdall-skills（`skills/`）

公开。网页智能体页的安装命令和 `setup-heimdall.sh` 依赖本仓 raw 地址。

| 文件 | 用途 |
|---|---|
| `setup-heimdall.sh` 等 | 安装 / 扇出 / 投影 / 自检 |
| `heimdall-sync/` `heimdall-platform/` | 管道技能正文 |
| `agent-templates/` | 默认智能体模板对照副本 |
```

发布表把「技能 / PRD」拆成两行：

```markdown
| PRD / 交接 | heimdall-docs | push 即公开，无 Deploy |
| 技能安装脚本 | heimdall-skills | push 即公开，无 Deploy |
```

- [ ] **Step 4: 改两份 HTML 交接稿（与 md 同事实）**

`Heimdall-技术实现交接.html`：

- `docs/` 那一行：技术栈改为 `Markdown / HTML`；生产职责改为「不部署到 ECS。仅文档」。
- 在其后插入 `skills/` 行：链接 `heimdall-skills`，badge PUBLIC，生产职责「`setup-heimdall.sh` 从此仓 raw 拉取」，无 Deploy。
- clone `pre` 追加 `git clone https://github.com/hackingangle/heimdall-skills.git  skills`
- 「技能正文 / 安装脚本」改为「公开仓 heimdall-skills」
- 原 E 节：删掉「网页技能引导依赖本仓」和 `skills/claude-code/` 列表项
- 在 repo-grid 增加 F 节 `heimdall-skills`，path `本地 skills/ → https://github.com/hackingangle/heimdall-skills`
- 发布表「技能 / PRD」拆成「PRD / 交接 → docs」与「技能脚本 → skills」

`Heimdall-交接手册.html`：

- `docs/` 说明改为「PRD、设计规格、交接文档。不含安装脚本。」
- 插入 `skills/` 行，说明「Harness 管道技能与 `setup-heimdall.sh`。技能正文以本仓为准。」
- 「一键脚本」改为 `heimdall-skills` 的 `setup-heimdall.sh`；四件套改为 `heimdall-sync` / `heimdall-platform`（策略在平台智能体）。
- 「技能正文只在 `docs/skills/claude-code/`」改为「技能正文只在 `heimdall-skills` 维护一份」。

- [ ] **Step 5: 工作区根 README（无 git，只改本机文件）**

`/Users/ong/ws/heimdall/README.md` 仓库表改为包含 `docs/` 与 `skills/`，并写明根目录不是 git 仓。不要声称只有两个仓。

- [ ] **Step 6: docs 仓 commit**

```bash
cd /Users/ong/ws/heimdall/docs
git add -A
git status
git commit -m "$(cat <<'EOF'
docs: 技能真源迁到 heimdall-skills，删除本仓 skills/

安装脚本不再从本仓 raw 分发；PRD 与交接改为指向新仓。
EOF
)"
```

Expected: commit 含 `skills/` 删除，以及 spec/plan（若尚未纳入版本库则一并 add）。

---

### Task 6: 切断验收

- [ ] **Step 1: 新地址通、旧地址断**

```bash
curl -fsSL -o /dev/null -w '%{http_code}\n' \
  https://raw.githubusercontent.com/hackingangle/heimdall-skills/main/setup-heimdall.sh
curl -fsSL -o /dev/null -w '%{http_code}\n' \
  https://raw.githubusercontent.com/hackingangle/heimdall-docs/main/skills/claude-code/setup-heimdall.sh
```

Expected: 第一行 `200`；第二行 `404`（docs 已 push 之后）。

- [ ] **Step 2: docs 无安装脚本**

```bash
find /Users/ong/ws/heimdall/docs -name 'setup-heimdall.sh' -o -name 'install-skills.sh'
```

Expected: 无输出。

- [ ] **Step 3: 前端常量**

```bash
rg 'heimdall-docs/main/skills' /Users/ong/ws/heimdall/web/src
```

Expected: 无匹配。

- [ ] **Step 4: 提醒发布**

前端需走 `heimdall-frontend` 的 GitHub Actions Deploy 后，生产智能体页才显示新 curl。本计划不在本机跑 `deploy.sh`。docs / skills 仓 **push `main` 即公开**，无 Deploy。

---

## Self-review（对照 spec）

| Spec 要求 | 任务 |
|---|---|
| 公开仓 `hackingangle/heimdall-skills`，本地 `skills/` | Task 1–2 |
| 根扁平，只迁 sync/platform/脚本/模板 | Task 1 Step 1 |
| 不迁 legacy / 旧四件套 | Task 1（拷贝白名单） |
| 无 docs 转发层 | Task 5 Step 1 |
| 顺序：新仓 → 前端 → 删 docs | Task 2 门闩、Task 3、Task 5 前置 |
| `skillsInstall.ts` + 测试 + VERSION | Task 3 |
| 交接 md/html、docs README | Task 5 |
| `default_agents.py` 只改注释 | Task 4 |
| 工作区 README | Task 5 Step 5 |
| 旧 URL 404、新 URL 200 | Task 6 |
