---
name: heimdall-platform
description: >
  Heimdall 平台能力：用 API Token 读写项目与素材。收集员 / 写稿等智能体入库、改稿、查项目时必须遵守。
  当用户要求入库、创建/更新/删除素材、上传原件、查项目，或素材 API 报 401/413/422 时激活。
  不含调研怎么拆、稿怎么写——那是平台智能体的策略。禁止 POST 带 agent_id 让服务端代跑。
---

# Heimdall 平台能力

任何本地智能体读写 Heimdall 时遵守本技能。本技能只谈**契约**（环境、项目、素材 API、字段规则）。

**禁止**用 `POST` 带 `agent_id` 让服务端代跑——写稿和收集在当前 Harness 完成，结果用 Token 通道写入。

## 0. 环境

```bash
# 若尚未加载：source ~/.heimdall/env
echo "API_BASE=$HEIMDALL_API_BASE"            # 如 http://127.0.0.1:8000/api
echo "TOKEN前缀=${HEIMDALL_API_TOKEN:0:6}"    # 应为 hd_ 开头，不要回显完整 Token
curl -sS "$HEIMDALL_API_BASE/projects" -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
```

- 缺 `HEIMDALL_API_BASE` / `HEIMDALL_API_TOKEN` → 停下来向用户要，不要猜。
- 用户 Token 在网页「API Token 管理」创建，形如 `hd_…`。后端仓库 `.env` 里的同名变量不是用户 Token。
- 所有请求带 `Authorization: Bearer $HEIMDALL_API_TOKEN`。401 = Token 无效；403 = 账号封禁。

## 1. 解析目标项目

素材必须写入 `POST /projects/{project_id}/materials`。`GET /projects` 按 `episode_no` 降序，**第一项 = 最新一期**。

| 用户输入 | 做法 |
|---|---|
| 指明项目（id / 第 N 期 / 标题关键词） | 按指明匹配 |
| 只给选题 | 用选题匹配项目 `title`；无匹配则列出近期项目让用户选 |
| 都没给 | 默认列表第一项；选题用该项目 `title` |
| 零散入库仍无法确定 | 列出近期项目让用户选 |

一句话确认：「第 {episode_no} 期 · {title}（project_id={id}）」。

## 2. 素材 API

Token 通道写入的素材 `source` 自动为 `api`。

### 创建

```bash
curl -sS -X POST "$HEIMDALL_API_BASE/projects/{项目id}/materials" \
  -H "Authorization: Bearer $HEIMDALL_API_TOKEN" -H "Content-Type: application/json" \
  -d '{
    "title": "[网页文章] 站点 - 篇名",
    "content": "> 来源：https://…\n> 获取日期：YYYY-MM-DD\n\n清洗后的正文…",
    "type": "text",
    "origin_url": "https://…",
    "raw_content": "清洗前的原始文本"
  }'
```

- `title` 必填（≤512）。文本素材的 `content` 放清洗后全文（上限约 16MB），不要过度摘要。仅有 PDF 原件时允许 `content=""`。
- `type`：`text`（默认）/ `pdf`。题材语义用标题前缀：`[网页文章]`、`[视频字幕]`、`[书籍]`、`[调研计划]`、`[调研索引]`、`[大纲]`、`[口播稿]`、`[标题文案]`。
- 有来源就填 `origin_url`；`raw_content` 放清洗前底稿，入库后不可改。手写笔记、成稿可不填这两项。
- **不要**传 `agent_id` / `input_material_ids`。成稿溯源写在正文头部。
- 成功 201，记下 `id`。缺 `title` 或非法 `type` → 422。

### 查询 / 改 / 删

```bash
curl -sS "$HEIMDALL_API_BASE/projects/{项目id}/materials" \
  -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
curl -sS "$HEIMDALL_API_BASE/materials/{id}" \
  -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
curl -sS -X PATCH "$HEIMDALL_API_BASE/materials/{id}" \
  -H "Authorization: Bearer $HEIMDALL_API_TOKEN" -H "Content-Type: application/json" \
  -d '{"title": "修订标题"}'
curl -sS -X DELETE "$HEIMDALL_API_BASE/materials/{id}" \
  -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
```

列表不回传全文。PATCH 不可传 `raw_content`，字段不可显式 `null`（422）。

### 上传原件

```bash
curl -sS -X PUT "$HEIMDALL_API_BASE/materials/{素材id}/file" \
  -H "Authorization: Bearer $HEIMDALL_API_TOKEN" \
  -F "file=@./book.pdf;type=application/pdf"
```

- 有二进制原件（PDF、字幕文件、转写音频）就传。**不传视频**。上限 100MB，超限 413。
- PDF 的 `content` 为空时平台抽电子文本；轮询详情 `extraction_status`，只有 `ready` 才能当正文用。`pending` / `processing` 先等；`failed` 且提示 OCR 时，由当前 Harness OCR 后 PATCH `content`。
- 下载：`GET $HEIMDALL_API_BASE/materials/{id}/file`。

### 智能体列表（只读人设，不代跑）

```bash
curl -sS "$HEIMDALL_API_BASE/agents" -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
```

本地没有投影时用这条对照人设，然后跑 heimdall-sync。不要用返回的 `id` 去 `POST` 素材的 `agent_id`。

## 3. 入库规则

1. **一条素材 = 一个来源作品**：一本书 / 一篇演讲 / 一篇文章 / 一个字幕 / 一份笔记 / 一篇成稿。不要把多篇塞进一条，也不要按章节拆书（章节用正文 `##`）。仅超 16MB 才按卷册拆。
2. **标题**：`[网页文章] 站点 - 篇名`、`[视频字幕] 频道 - 标题`、`[书籍] 书名（编著者）`；计划 / 索引 / 成稿用对应前缀。
3. **有来源时正文头部**：`> 来源：URL` + `> 获取日期：YYYY-MM-DD`，空行后接正文。
4. **保留原文，不过度摘要**；无关的不入库。
5. **入库前按标题查重**；同名已存在则跳过或更新更完整的版本。
6. **单条失败不中断**，记下原因继续。

## 4. 已知报错

| 症状 | 原因 |
|---|---|
| 401 | Token 非 `hd_` / 已吊销 / 误用服务端 `.env` |
| 上传 413 | 超过 100MB |
| PATCH 422 | 传了 `raw_content` 或字段 `null` |
| 创建 422 | 缺 `title` 或 `type` 非法 |

技能或本机投影过期时，再跑网页「智能体」上同一条 setup 命令（或 heimdall-sync）。
