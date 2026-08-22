---
name: heimdall-write
description: >
  Heimdall 写作技能：基于某一期项目已收集的素材写出大纲、口播稿、标题文案，成稿作为新素材入库。
  当用户要求"写口播稿 / 写大纲 / 起标题 / 基于素材成稿 / 改稿"时激活。
  未指定项目时，默认关联最新一期项目（API 列表第一项）；只消费该项目内已就绪的素材。
  写稿策略在本 Harness 执行，不调用平台的 agent_id 生成；入库 API 与质量规则由 heimdall-material 技能承担。
tools: Read, Write, Bash
---

# Heimdall 写作技能

素材库 → 成稿。本技能管**怎么成稿**；素材 API 细节与入库字段规则见 heimdall-material 技能，不在此重复。

**成稿也是素材**：写出来的大纲、口播稿、标题一律 `POST` 回 `projects/{project_id}/materials`，与调研素材同库，可以再被当作下一步的输入。

**写稿在本 Harness 完成**：自己读素材、自己成稿。不要用 `POST` 带 `agent_id` 让服务端代跑——那条路拿不到你的多轮修改与素材对照能力。

**技能过期先同步**：本机技能是副本，真源在 heimdall-docs main。开写前或行为与描述不符时，跑 heimdall-doctor 的技能版本自检（或直接 `curl -fsSL https://raw.githubusercontent.com/hackingangle/heimdall-docs/main/skills/claude-code/install-skills.sh | bash` 覆盖安装，不需要重输 Token）。

## 0. 确定目标项目（每次激活先做）

同 heimdall-collect §0：

```bash
curl -sS "$HEIMDALL_API_BASE/projects" -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
```

列表按 `episode_no` 降序，**第一项 = 最新一期**。用户指明项目（id / 第 N 期 / 标题关键词）就按指明匹配；只给主题就按 `title` 匹配；都没给则取第一项。一句话确认后再动手：「第 {episode_no} 期 · {title}（project_id={id}），要写：{产出类型}」。

## 1. 选输入素材

```bash
# 列表不回传全文，只用来挑
curl -sS "$HEIMDALL_API_BASE/projects/{项目id}/materials" -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
# 逐条取正文
curl -sS "$HEIMDALL_API_BASE/materials/{id}" -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
```

- **只消费 `status=ready` 且 `content` 非空的素材**。`status=generating` 的等它完成，`failed` 的直接跳过。
- **PDF 看 `extraction_status`**：只有 `ready` 才有正文可用；`pending / processing` 先等，`failed` 说明是扫描件，告诉用户需要人工补正文，不要凭标题硬编。
- 已有的 `[调研索引]` 是地图：先读它了解各维度收了什么、哪里还是缺口。
- 选料告诉用户用了哪几条（编号 + 标题），有明显缺口就说明，别默默拿残缺素材成稿。

## 2. 成稿

### 风格口径

1. 项目内有风格素材（如 `[口播口径]`、`[风格样例]`）→ 读它，按它写；
2. 项目内有上一期的成稿 → 可作为腔调参照；
3. 都没有 → **问用户**（时长、面向谁、第一人称还是解说、能不能用网络语）。**不要自行发明腔调**。

### 产出类型

| 类型 | 标题格式 | 要求 |
|---|---|---|
| 大纲 | `[大纲] {主题} - {YYYY-MM-DD}` | 分段 + 每段要点与打算用的素材编号，先给用户过目再写正文 |
| 口播稿 | `[口播稿] {主题} - {YYYY-MM-DD}` | 逐字可念：口语、短句、不用书面连接词；分段对应镜头/段落 |
| 标题文案 | `[标题文案] {主题} - {YYYY-MM-DD}` | 一条素材里给 5~10 个候选，标注各自的角度 |

### 纪律

- **事实只能来自素材**。素材里没有的人名、年份、数字、引文一律不许补，宁可留 `（待核）` 让用户补。
- 引用他人原话时保留原文，并在稿里注明来自哪条素材。
- 稿子长度按用户给的时长估算（口播约每分钟 220~260 字），没给就先问。
- 写长稿分段推进，边写边给用户看，不要一次甩完再返工。

## 3. 入库

按 heimdall-material 的字段规则 `POST`，`type=text`，正文头部写溯源头：

```markdown
> 输入素材：#42 #43 #51
> 成稿日期：2026-08-22

## 开场
……
```

- Token 通道写入的素材 `source` 自动是 `api`，**不带 `input_material_ids`**（那是平台 `agent_id` 生成路径才有的字段），所以溯源必须写在正文头部，否则事后查不到这稿用了什么料。
- 成稿是自己写的，没有外部来源，`origin_url` 与 `raw_content` 不填。
- 入库前查重：同名成稿已存在时按下一节处理，不要堆同名素材。

## 4. 改稿

- **小改**（措辞、删段、补一句）：`PATCH /materials/{id}` 改 `content`，同一条素材上迭代，标题不动。
- **换方向重写**（换角度、换结构、换时长）：新建一条，标题末尾标版本：`[口播稿] {主题} - {YYYY-MM-DD} v2`，正文溯源头写明是从哪条改来的。
- 用户说"回到上一版"时，如果之前是 PATCH 覆盖的，如实说明旧文本没有留存，别假装能还原。

## 5. 收尾汇报

- 用了哪几条素材（编号 + 标题）；
- 成稿的素材 id、标题、字数、预估时长；
- 待人工确认处：`（待核）` 的地方、缺口维度、需要补的素材方向。
