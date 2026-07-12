# Heimdall 素材接入技能（heimdall-material-skill）

> 供 Claude Code / OpenClaw / Hermes 等外部 Harness 作为技能装载。本技能描述如何凭 API Token 读写 Heimdall 的项目、素材与 Agent。

- 日期：2026-07-06
- 适用对象：需要向 Heimdall 写入素材、或读取素材/Agent 配置的外部 Agent
- 相关设计：[创作功能设计](../superpowers/specs/2026-07-04-creation-workflow-design.md)

## 1. 准备工作

### 1.1 获取 API Token

1. 登录 Heimdall 网页端 → 右上角个人菜单 → **API Token 管理**。
2. 新建 Token（填写用途备注），**明文只在创建时展示一次**，形如 `hd_xxxxxxxx...`，请立即保存。
3. Token 与创建者账号绑定：凭 Token 调用接口，数据归属、可见范围与该用户一致。
4. Token 可随时在网页端吊销；吊销后立即失效。

### 1.2 环境变量约定

```bash
export HEIMDALL_API_BASE="http://localhost:8000/api"   # 服务地址 + /api 前缀
export HEIMDALL_API_TOKEN="hd_xxxxxxxxxxxxxxxx"        # 上一步创建的 Token 明文
```

### 1.3 鉴权方式

所有接口统一用 Bearer 头，服务端按 `hd_` 前缀自动识别 Token 通道：

```
Authorization: Bearer $HEIMDALL_API_TOKEN
```

鉴权失败返回 `401`；账号被封禁返回 `403`。

## 2. 核心接口

### 2.1 列出项目（找到要写入的项目 ID）

```bash
curl -sS "$HEIMDALL_API_BASE/projects" \
  -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
```

响应示例：

```json
[
  { "id": 1, "episode_no": 12, "title": "内丹法是什么", "category": "道学科普", "created_at": "2026-07-01T08:00:00" }
]
```

### 2.2 创建素材（最常用）

```bash
curl -sS -X POST "$HEIMDALL_API_BASE/projects/1/materials" \
  -H "Authorization: Bearer $HEIMDALL_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "[网页文章] 某站 - 内丹法源流考",
    "content": "> 来源：https://example.com/article\n> 获取日期：2026-07-06\n\n正文……",
    "type": "text",
    "origin_url": "https://example.com/article",
    "raw_content": "（清洗前的原始文本，如 Jina 直出的 Markdown）"
  }'
```

要点：

- Token 通道创建的素材 `source` 自动标为 `api`，网页手动创建为 `manual`，无需也无法自行指定。
- `title` 必填，上限 **512 字符**；`content` 为长文本（MEDIUMTEXT，约 16 MB 上限），放全文没有问题。
- **原始信息留档字段（强烈建议填写，防止清洗出错后无法回溯）**：
  - `type`：素材载体，取值 `text`（默认，文本/Markdown）/ `pdf`（PDF 原件为主）；题材语义（书籍、网页、字幕等）用标题前缀区分，如 `[书籍]`、`[网页文章]`；
  - `origin_url`：来源地址（上限 1024 字符）；
  - `raw_content`：清洗前的文本底稿（原始字幕文本、markitdown 直出等）。**入库后不可修改**，PATCH 不接受该字段。
- 成功返回 `201` 与素材完整 JSON（含 `id`）。
- 校验失败（如缺 title、type 取值非法）返回 `422`。

### 2.2.1 上传素材原件（二进制原始文件）

素材创建后，把原件（PDF、原始 SRT 等）挂到素材上，字节存对象存储：

```bash
curl -sS -X PUT "$HEIMDALL_API_BASE/materials/42/file" \
  -H "Authorization: Bearer $HEIMDALL_API_TOKEN" \
  -F "file=@./book.pdf;type=application/pdf"
```

- 幂等替换：重复 PUT 覆盖旧文件。
- 大小上限默认 **100 MB**（`HEIMDALL_STORAGE_MAX_FILE_MB` 可调），超限返回 `413`。视频文件本身**不要上传**，只传字幕；音轨转写场景的音频原件（`.m4a` 等）允许上传留档。
- 响应为素材完整 JSON，`file_key / file_name / file_size / file_mime` 已回填。
- 下载原件：`GET $HEIMDALL_API_BASE/materials/42/file`（无原件时 `404`）。

### 2.3 查询素材

```bash
# 项目内素材列表，可按来源过滤：source=manual|api|generated
curl -sS "$HEIMDALL_API_BASE/projects/1/materials?source=api" \
  -H "Authorization: Bearer $HEIMDALL_API_TOKEN"

# 单条素材详情
curl -sS "$HEIMDALL_API_BASE/materials/42" \
  -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
```

### 2.4 修改 / 删除素材

```bash
# 部分更新（只传要改的字段；字段不可传 null）
curl -sS -X PATCH "$HEIMDALL_API_BASE/materials/42" \
  -H "Authorization: Bearer $HEIMDALL_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "[网页文章] 某站 - 内丹法源流考（修订）"}'

# 删除
curl -sS -X DELETE "$HEIMDALL_API_BASE/materials/42" \
  -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
```

### 2.5 读取 Agent 列表（了解平台内已配置的创作 Agent）

```bash
curl -sS "$HEIMDALL_API_BASE/agents" \
  -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
```

返回每个 Agent 的 `id / name / description / system_prompt / model`，外部 Harness 可读取提示词用于对齐口径。

### 2.6 触发 AI 创作（可选）

创建素材的另一种模式：不给 `content`，改给 `agent_id`（+ `input_material_ids` / `user_prompt`），服务端后台调 LLM 生成，产出同样是一条素材：

```bash
curl -sS -X POST "$HEIMDALL_API_BASE/projects/1/materials" \
  -H "Authorization: Bearer $HEIMDALL_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "agent_id": 3,
    "input_material_ids": [42, 43],
    "user_prompt": "基于以上调研素材输出视频大纲"
  }'
```

立即返回 `status=generating` 的素材；轮询 `GET /materials/{id}` 直到 `status` 变为 `ready`（成功）或 `failed`（`error` 字段有失败原因）。

## 3. 注意事项

- **一条素材 = 一个来源作品**：一本书 / 一篇演讲 / 一篇文章 / 一个视频字幕。既不要把多篇内容塞进一条，也**不要把一本书按章节拆成多条**——章节结构用正文内的 Markdown 标题（`## 章名`）保留即可（`content` 上限约 16 MB，整本书放得下）。仅当单一作品超出字段上限时才按卷/册拆分，属于例外。
- **正文头部附出处**：来源 URL + 获取日期，便于写稿时引用溯源。
- **幂等自查**：写入前可先 `GET` 列表按标题查重，避免重复入库。
- 时间戳为服务器时区的 ISO 格式；素材列表按创建时间排序返回。
