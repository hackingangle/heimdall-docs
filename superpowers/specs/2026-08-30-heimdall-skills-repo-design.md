# 拆出 heimdall-skills 仓库

- 日期：2026-08-30
- 状态：已确认
- 产品目标：Harness 管道技能与安装脚本从 `heimdall-docs` 独立为公开仓 `heimdall-skills`。文档仓只保留 PRD / 交接 / 设计规格；curl raw 真源只指向新仓。旧 `heimdall-docs` raw 地址立刻作废，不留转发层。

## 1. 范围与原则

### 做

- 新建公开 GitHub 仓 `hackingangle/heimdall-skills`，默认分支 `main`
- 本地工作区 `~/ws/heimdall/skills` 克隆该仓
- 迁入现行分发物：安装/同步脚本、`heimdall-sync`、`heimdall-platform`、默认智能体模板
- 脚本与技能正文里的 raw URL 全部改为新仓根路径
- 前端智能体页安装命令改指向新仓；`web/VERSION` +1
- `heimdall-docs` 删除 `skills/`；交接文档改仓库表

### 不做（YAGNI）

- 旧 URL 包装、301、docs 仓里留 `setup-heimdall.sh` 转发
- 把已停发的 collect / write / material / doctor 迁入新仓
- 用 git filter 保留 docs 仓提交史
- 给技能仓加 Deploy / CI / ECS
- 改平台智能体策略（仍在数据库；本机只是投影）
- 改后端行为（`default_agents.py` 只改注释，不 bump `server/VERSION`）

### 原则

1. **docs 不再是运行时依赖。** push 到 `heimdall-docs` 不得再影响用户本机安装。
2. **切断旧地址。** 已装技能副本里的 docs URL 会 404；用户以网页上新命令为准重新跑一遍。
3. **扁平根目录。** 独立技能仓不再套 `skills/claude-code/`。
4. **先上新源，再改前端，最后清 docs。** 避免生产安装命令窗口期内 404。

## 2. 仓库边界

```text
~/ws/heimdall/          （不是 git 仓）
  server/               heimdall-backend    PRIVATE
  web/                  heimdall-frontend   PRIVATE
  heimdall/             heimdall-client     PRIVATE
  asr/                  heimdall-asr        PRIVATE
  docs/                 heimdall-docs       PUBLIC   仅文档
  skills/               heimdall-skills     PUBLIC   管道技能真源
```

| 仓 | 职责 |
|---|---|
| `heimdall-skills` | 管道技能真源 + 安装/同步脚本。网页 curl 与 `check-skills.sh` 只打这里。 |
| `heimdall-docs` | PRD、交接手册、设计规格、实施计划。 |
| `heimdall-frontend` | 「智能体」页展示的 curl 文案。 |

克隆：

```bash
git clone https://github.com/hackingangle/heimdall-skills.git skills
```

## 3. 新仓目录（根扁平）

从 `docs/skills/claude-code/` 迁出并改 URL，放在新仓根：

```text
setup-heimdall.sh
install-skills.sh
install-agents.sh
check-skills.sh
detect-harness.sh
heimdall-sync/SKILL.md
heimdall-platform/SKILL.md
agent-templates/collector.json
agent-templates/writer.json
README.md
.gitignore
```

不迁：`docs/skills/legacy/`、`docs/skills/examples/`、`docs/skills/heimdall-*-skill.md`、以及 `claude-code/` 下已停发的 collect / write / material / doctor。删除 docs 侧 `skills/` 后，这些只留在 docs 仓 git 历史里。

脚本内常量一律改为：

```text
https://raw.githubusercontent.com/hackingangle/heimdall-skills/main
```

本地 hint：`bash skills/setup-heimdall.sh <API_BASE>`（相对工作区根）。

管道技能仍只做管道；收集/写稿策略仍由平台智能体投影，不把策略写进本仓技能正文。

## 4. 发布顺序

必须按此顺序，禁止颠倒 1 与 3：

1. 在 GitHub 组织 `hackingangle` 建公开空仓 `heimdall-skills`；本地写入内容并 push `main`。验证：
   `curl -fsSL https://raw.githubusercontent.com/hackingangle/heimdall-skills/main/setup-heimdall.sh` 返回脚本。
2. 改前端 `web/src/lib/skillsInstall.ts` 与测试；`web/VERSION` +1；frontend 仓提交。生产页在 Deploy 完成前仍指向旧地址。
3. 从 `heimdall-docs` 删除 `skills/`，更新 README 与交接文档。此后旧 raw 路径 404。

GitHub 空仓由有 `hackingangle` 权限的人创建（`gh repo create hackingangle/heimdall-skills --public`），再把本地 `skills/` push 上去。

## 5. 引用清单

| 位置 | 变更 |
|---|---|
| 新仓四个 `.sh` 的 `REPO_RAW` / `INSTALL_SCRIPT_URL` / `CANONICAL_RAW` | 指向 `heimdall-skills/main` 根 |
| 新仓 `heimdall-sync/SKILL.md` | curl 与本地 `bash skills/...` |
| `web/src/lib/skillsInstall.ts` | `SETUP_SCRIPT_URL` / `INSTALL_SCRIPT_URL`；本地 hint 改为 `skills/` |
| `web/src/lib/skillsInstall.test.ts` | 断言新 URL |
| `docs/README.md` | 技能节改为链接新仓，删除本仓 skills 目录说明 |
| `docs/Heimdall-技术实现交接.md` 与 `.html` | 仓库表加 `skills/`；docs 行去掉「从此仓 raw 拉」 |
| `docs/Heimdall-交接手册.html` | 技能真源改为 heimdall-skills |
| `server/app/services/default_agents.py` 文件头注释 | 模板路径改为 `heimdall-skills/agent-templates/`；不 bump 后端 VERSION |
| 工作区根 `README.md` | 补第六仓（仅本机，无 remote） |

前端「智能体」页只展示 `getSetupCommand`（curl 新仓）。本地 hint 若仍展示，路径改为 `bash skills/setup-heimdall.sh`。

## 6. 错误与兼容

- **新仓尚未 public：** 步骤 1 失败则停止，不改前端、不删 docs。
- **生产窗口：** 步骤 2 未 Deploy 前，线上命令仍打 docs；步骤 3 之后该命令 404。这是预期，不在 docs 留 shim。
- **用户本机旧技能：** `heimdall-sync` 正文里的 docs URL 会失败。处理：打开网页复制新命令重跑 `setup-heimdall.sh`。不写迁移脚本。
- **`~/.heimdall/env`：** Token 与 API_BASE 格式不变；setup 脚本已有则复用。
- **Harness 投影路径：** 仍是 `~/.cursor/skills/`、`~/.claude/skills/` 等；只换下载源。

## 7. 验收

- `curl` 新仓 `setup-heimdall.sh` 成功；旧 `heimdall-docs/main/skills/claude-code/setup-heimdall.sh` 404。
- 前端测试：`getSetupCommand` 含 `heimdall-skills/main/setup-heimdall.sh`。
- `docs/` 下不再有可执行安装脚本。
- 交接文档仓库图含 `skills/` / `heimdall-skills`。
- 本地 `~/ws/heimdall/skills` 是独立 git 仓，remote 为 `hackingangle/heimdall-skills`。
