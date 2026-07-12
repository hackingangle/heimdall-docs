---
name: heimdall-material
description: >
  Heimdall 素材技能：为 YouTube 口播稿项目收集素材并写入 Heimdall 平台。
  当用户要求"找素材 / 收集素材 / 调研某个主题 / 把资料入库到 Heimdall / 创建素材"时激活。
  覆盖：Heimdall 素材 API（创建/查询/原件上传）、清洗入库规则与原始信息留档。
  素材的发现与获取方式不限，用当下可用的任何手段（搜索、抓取、用户提供的文件等）。
tools: Read, Write, Bash, WebSearch, WebFetch
---

# Heimdall 素材技能

把收集到的资料清洗、留档、写入 Heimdall。**怎么找资料不做限定**——用你可用的任何手段（网页搜索、抓取、读用户给的本地文件等）；本技能管的是**入库的质量和格式**。

## 0. 前置检查（每次任务开始先做）

```bash
# 必需环境变量
echo "API_BASE=$HEIMDALL_API_BASE"     # 如 http://localhost:8000/api
echo "TOKEN 前缀=${HEIMDALL_API_TOKEN:0:6}"  # 应为 hd_ 开头，不要回显完整 Token
# 验证 Token 可用 + 找到目标项目 id
curl -sS "$HEIMDALL_API_BASE/projects" -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
```

- 缺 `HEIMDALL_API_BASE` / `HEIMDALL_API_TOKEN` → 停下来向用户要，不要猜。
- 用户没指明项目时，列出项目让用户选，或按选题标题匹配。

## 1. 素材 API 速查

所有请求带 `Authorization: Bearer $HEIMDALL_API_TOKEN`（Token 通道写入的素材 `source` 自动标 `api`）。

### 创建素材（核心）

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

字段规则：

- `title` 必填（≤512 字符）；`content` 必填，放清洗后全文（上限约 16MB，不要过度摘要）。
- `type` 取值：`text`（文本/Markdown，默认）/ `pdf`（PDF 原件为主）。题材语义用标题前缀：`[网页文章]`、`[视频字幕]`、`[书籍]`。
- **`origin_url` 和 `raw_content` 尽量填**（留档防丢失）：有来源地址就填 `origin_url`；`raw_content` 放清洗前的文本底稿（抓取直出的原文、原始字幕等），入库后不可修改。用户手写的笔记类素材可不填。
- 成功返回 201 和素材 JSON（记下 `id`）。

### 上传原件（二进制原始文件）

```bash
curl -sS -X PUT "$HEIMDALL_API_BASE/materials/{素材id}/file" \
  -H "Authorization: Bearer $HEIMDALL_API_TOKEN" \
  -F "file=@./book.pdf;type=application/pdf"
```

- 有二进制原件（PDF、原始字幕文件、转写用的音频等）就传，字节存对象存储；**视频文件永远不传**（音频允许）。
- 上限 100MB，超限返回 413，记录后留给人工。
- 下载：`GET $HEIMDALL_API_BASE/materials/{id}/file`。

### 查询 / 去重

```bash
# 项目内素材列表（入库前先查重，按标题判断是否已收录）
curl -sS "$HEIMDALL_API_BASE/projects/{项目id}/materials" -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
# 单条详情
curl -sS "$HEIMDALL_API_BASE/materials/{id}" -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
```

## 2. 入库规则（每条素材都要遵守）

1. **一条素材 = 一个来源作品**：一本书 / 一篇演讲 / 一篇文章 / 一个视频字幕 / 一份笔记。既不要把多篇内容塞进一条，也**不要把一本书按章节拆成多条**——章节结构用正文内的 Markdown 标题（`## 章名`）保留（`content` 上限约 16MB，整本书放得下）；仅当单一作品超出上限时才按卷/册拆分，属于例外。
2. **标题格式**：`[网页文章] 站点 - 篇名`、`[视频字幕] 频道 - 标题`、`[书籍] 书名（编著者）`、笔记类直接写标题。
3. **正文头部附出处**（有来源时）：`> 来源：URL` + `> 获取日期：YYYY-MM-DD`，空行后接正文。
4. **保留原文，不过度摘要**；相关性由你速读判断，与主题无关的不入库。
5. **原始信息留档**：`type` 每条必填；有来源的素材填 `origin_url` + `raw_content`；有二进制原件就上传。
6. **入库前查重**：同标题已存在则跳过，或取更完整的版本。
7. **单条失败不中断**：某条资料处理失败，记录原因后继续下一条。

## 3. 收尾汇报

批量收集任务结束后：

- 额外创建一条 `type=text` 的素材，标题 `[调研索引] {主题} - {日期}`，内容为：已收录清单（标题 + 来源）、失败/放弃的来源及原因、建议人工补充的方向。
- 向用户汇报：收录几条、类型分布、失败清单。

单条零散入库不需要调研索引，直接汇报结果即可。
