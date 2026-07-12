# 用户维度模型配置（LlmConfig）设计

日期：2026-07-04
状态：已确认

## 背景与目标

当前 LLM 接入信息（base_url / api_key / 默认模型）全部在服务端 `.env` 中，
Agent 的「模型」只是一个自由文本字段。用户无法在页面上：

1. 自助接入自己的模型服务（如 GLM Coding Plan、OpenAI）；
2. 在新建/编辑 Agent 时从已配置的模型中选择。

目标：在**用户维度**维护模型配置，Agent 通过外键引用其一；未引用时回退
服务端 `.env` 全局默认（平滑过渡，不破坏现有链路）。

## 数据模型

新表 `llm_config`（每行 = 一个可用模型接入）：

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInt PK | |
| user_id | FK user.id, index | 用户隔离 |
| name | String(128) | 展示名，如「GLM-5.2（Coding Plan）」 |
| base_url | String(512) | OpenAI 兼容接入点 |
| api_key | String(512) | 接入密钥（接口不回显） |
| model | String(128) | 模型名，如 `glm-5.2` |
| created_at / updated_at | DateTime | |

`agent` 表变更：删除 `model` 列，新增 `llm_config_id`（FK → llm_config.id，
可空，ON DELETE SET NULL）。配置被删后 Agent 自动回退全局默认，不阻塞删除。

遵循 architecture-simplicity：不保留 `model` 文本列与外键并存的冗余。

## API

`/api/llm-configs`（JWT / API Token 双通道均可）：

- `POST` 创建：name, base_url, api_key, model
- `GET` 列表：**不回显 api_key**（返回掩码 `****last4`）
- `PATCH /{id}` 部分更新：api_key 传了才改
- `DELETE /{id}`：直接删除，引用它的 Agent 的 llm_config_id 置 NULL

Agent API：`model` 字段替换为 `llm_config_id`（可空 int）。`AgentOut`
附带 `llm_config_name`（便于列表展示，无需前端二次 join）。

## 生成链路

`llm.complete` 改为接收显式 `(base_url, api_key, model)`。
`run_generation` 解析顺序：Agent.llm_config → 有则用其三元组；
无则用 `settings.llm_*` 全局默认（api_key 为空时保持现有 fail-fast 报错）。

## 前端

- 用户菜单新增「模型设置」抽屉：配置列表（名称/接入点/模型/掩码 key）、
  新建、编辑、删除。
- `AgentFormModal`：「模型」自由文本框 → Select 下拉，选项来自
  `GET /api/llm-configs`，含「使用全局默认」空选项。
- Agent 列表展示所选配置名。

## 非目标

- 不做 api_key 加密存储（个人部署场景）。
- 不做模型连通性测试按钮（失败会体现在生成结果 error 上）。
- 不做每次创作时临时覆盖模型。
