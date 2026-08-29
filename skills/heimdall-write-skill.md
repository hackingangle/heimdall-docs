> **已废弃（2026-08-29）**：写稿策略在平台智能体「写稿」。现行技能是 heimdall-sync 与 heimdall-platform。下文仅作历史。

# Heimdall 写作技能（heimdall-write-skill）

> 供 Claude Code / Cursor / OpenClaw / Hermes 等外部 Harness 作为技能装载。把一期项目已收集的素材写成大纲、口播稿、标题文案，**成稿作为新素材入库**。

- 日期：2026-08-22
- 前置技能：[heimdall-material-skill](./heimdall-material-skill.md)（素材 API 与入库字段规则）
- 上游技能：[heimdall-collect-skill](./heimdall-collect-skill.md)（素材是怎么收进来的）
- 环境自检：[heimdall-doctor-skill](./heimdall-doctor-skill.md)（首次执行、技能过期或平台报错时先跑）

## 1. 定位

Heimdall 只做机制（存素材、守最小规则），**写稿策略在 Harness**。因此：

- 成稿由当前 Harness 自己读素材、自己写，**不走** `POST` 带 `agent_id` 的服务端生成路径（见 [heimdall-material-skill §2.6](./heimdall-material-skill.md)）——那条路拿不到多轮修改与素材对照能力，只作为兼容保留。
- 成稿一律回写为素材，与调研素材同库，可以再当作下一步的输入（调研 → 大纲 → 口播稿 → 标题）。
- 技能是各 Harness 里的副本，真源是本仓；开写前或行为与描述不符时先跑 doctor §0 的技能版本自检。

## 2. 选项目与选料

项目解析同 [collect §0](./heimdall-collect-skill.md)：`GET /projects` 按 `episode_no` 降序，未指明则取第一项，一句话确认后开工。

选料要点：

- 列表接口不回传全文，只用来挑；逐条 `GET /materials/{id}` 取正文。
- **只消费 `status=ready` 且 `content` 非空的素材**；`generating` 等完成，`failed` 跳过。
- PDF 看 `extraction_status`：只有 `ready` 才有正文；`failed`（扫描件）需人工补正文后再用，不许凭标题硬编内容。
- 先读该期的 `[调研索引]` 了解覆盖与缺口；选完告诉用户用了哪几条，有缺口要说明。

## 3. 成稿

### 风格口径来源（按优先级）

1. 项目内的风格素材（如 `[口播口径]`、`[风格样例]`）；
2. 上一期的成稿作为腔调参照；
3. 都没有就**问用户**（时长、面向谁、人称、用语边界）。不自行发明腔调。

### 产出类型与标题格式

| 类型 | 标题 | 要求 |
|---|---|---|
| 大纲 | `[大纲] {主题} - {YYYY-MM-DD}` | 分段 + 每段要点与拟用素材编号，过目后再写正文 |
| 口播稿 | `[口播稿] {主题} - {YYYY-MM-DD}` | 逐字可念：口语、短句；分段对应镜头/段落 |
| 标题文案 | `[标题文案] {主题} - {YYYY-MM-DD}` | 一条素材内给 5~10 个候选，标注角度 |

### 纪律

- **事实只能来自素材**：素材里没有的人名、年份、数字、引文不许补，留 `（待核）`。
- 引用原话保留原文并注明出自哪条素材。
- 时长换算：口播约每分钟 220~260 字；用户没给时长先问。
- 长稿分段推进，边写边给用户看。

## 4. 入库与改稿

入库按 material 技能的字段规则，`type=text`，正文头部写溯源头：

```markdown
> 输入素材：#42 #43 #51
> 成稿日期：2026-08-22
```

- Token 通道写入的素材 `source=api`，**不带 `input_material_ids`**（那是平台 `agent_id` 生成路径的字段），所以溯源必须落在正文里。
- 成稿无外部来源，`origin_url` / `raw_content` 不填。
- 改稿：小改 `PATCH` 同一条；换方向新建一条并在标题标 `v2`，溯源头注明改自哪条。PATCH 覆盖后旧文本不留存，用户要回退时如实说明。

## 5. 收尾

汇报：用了哪几条素材、成稿的素材 id / 标题 / 字数 / 预估时长、`（待核）` 与缺口清单。
