# Heimdall 创作功能设计（素材 · Agent · AI 创作）

- 日期：2026-07-04
- 状态：已确认
- 原则：简单、高可用；每个实体与属性都有存在必要性，杜绝冗余（见 `.cursor/rules/architecture-simplicity.mdc`）

## 1. 目标

进入项目后完成 YouTube 口播稿创作闭环：

1. **收集素材**：手动录入 + 外部 Harness 凭 API Token 写入。
2. **Agent 管理**：平台内定义创作 Agent（人设 + 提示词 + 模型），内部可执行，外部 Harness 也可读取。
3. **基于素材的 AI 创作**：选 Agent + 勾选素材 → 服务端调 LLM → 产出直接成为新素材，支撑链式创作（调研 → 大纲 → 口播稿 → 标题文案）。

## 2. 核心设计决策

1. **创作结果即素材**：不区分「产物」与「素材」，一切内容统一为 Material，用 `source` 区分来源（manual / api / generated）。
2. **创作融合进素材创建**：不设独立 Generation 实体/API。AI 创作 = 以生成模式创建一条素材，过程字段（agent_id、输入素材、补充指令、错误）挂在 Material 上。
3. **服务端内置执行**：后端直接调 OpenAI 兼容 LLM API，用 FastAPI BackgroundTasks，不引入队列。
4. **鉴权双通道**：同一套 API 既认 JWT（网页），也认 API Token（外部 Harness）。

## 3. 数据模型（新增 3 张表）

### Material（素材，项目内）

| 字段 | 说明 |
|---|---|
| `id` | PK |
| `project_id` | FK → project |
| `title` | 标题 |
| `content` | 长文本（MEDIUMTEXT）；生成中为空 |
| `source` | `manual` / `api` / `generated` |
| `status` | `ready` / `generating` / `failed`（手动与 api 创建即 ready） |
| `agent_id` | 可空，生成素材所用 Agent |
| `input_material_ids` | JSON，可空，生成输入 |
| `user_prompt` | 可空，本次补充指令 |
| `error` | 可空，生成失败原因 |
| `created_at` / `updated_at` | 时间戳 |

### Agent（平台级，跨项目）

| 字段 | 说明 |
|---|---|
| `id` | PK |
| `user_id` | FK → user，归属者 |
| `name` | 名称 |
| `description` | 一句话用途 |
| `system_prompt` | 人设/提示词 |
| `model` | 可空；空则用全局默认模型 |
| `created_at` / `updated_at` | 时间戳 |

### ApiToken（平台级）

| 字段 | 说明 |
|---|---|
| `id` | PK |
| `user_id` | FK → user |
| `name` | 用途备注 |
| `token_hash` | SHA-256，明文不落库 |
| `prefix` | 明文前缀（如 `hd_ab12`），列表展示用 |
| `last_used_at` | 可空 |
| `revoked_at` | 可空，非空即失效 |
| `created_at` | 时间戳 |

## 4. API

所有端点同时接受 JWT 与 `Authorization: Bearer hd_xxx`（Token 通道下按 token 归属用户鉴权）。

### 素材

- `POST /api/projects/{id}/materials` — 两种模式：
  - 手动/外部：`{title, content}` → `source` 按通道定（网页 manual / Token api），立即 ready。
  - AI 创作：`{title?, agent_id, input_material_ids, user_prompt?}` → 立即返回 `status=generating` 的素材，后台生成。
- `GET /api/projects/{id}/materials?source=` — 列表（前端轮询生成状态也用素材查询）
- `GET /api/materials/{id}` / `PATCH`（title/content）/ `DELETE`

### Agent

- `POST /api/agents` / `GET /api/agents` / `GET /api/agents/{id}` / `PATCH` / `DELETE`

### Token

- `POST /api/tokens` —— 明文仅在响应中返回一次
- `GET /api/tokens` —— 列 prefix/name/时间，不含明文
- `DELETE /api/tokens/{id}` —— 吊销

## 5. LLM 执行

- 配置：`HEIMDALL_LLM_BASE_URL` / `HEIMDALL_LLM_API_KEY` / `HEIMDALL_LLM_DEFAULT_MODEL`（OpenAI 兼容协议）。
- 流程：拼 messages（system = Agent.system_prompt；user = 各输入素材「标题 + 内容」拼接 + 补充指令）→ chat.completions → 成功写回 content、status=ready；失败 status=failed 存 error。
- 前端每 2 秒轮询素材直至 ready/failed。

## 6. 前端

- 项目列表行可点击 → **项目详情页 `/projects/:id`**：
  - 左：素材列表（Tab：全部 / 原始 / 创作产出），新建（粘贴文本、上传 md/txt）、查看、编辑、删除。
  - 右：创作面板——选 Agent、勾选素材、补充指令 → 开始创作 → 生成中状态 → 完成后出现在素材列表。
- **Agent 管理页 `/agents`**（侧栏菜单）：列表 + 新建/编辑弹窗。
- **Token 管理**：个人菜单入口，新建时弹窗展示明文一次。

## 7. 外部 Harness 接入

技能说明文档 `docs/skills/heimdall-material-skill.md`：API Token 获取方式、素材/Agent 接口的 curl 示例，供 Claude Code / OpenClaw / Hermes 作为技能描述装载。

## 8. 本期不做

大文件对象存储、PDF 解析、URL 自动抓取、流式输出、Task/Record 黑板、MCP server、Agent 版本管理、多轮对话创作、独立 Generation 实体。
