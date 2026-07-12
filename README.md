# Heimdall Docs

Heimdall 项目的产品与设计文档。代码在独立仓库维护。

> Heimdall 是一个通用的、有状态的多 Agent 协作数据层（控制平面）。设计哲学：**机制与策略分离**——后端只做机制（存数据 + 守最小规则），所有策略交给外部 Harness/Agent。

## 目录

- [`prds/Heimdall PRD.md`](./prds/Heimdall%20PRD.md) — 产品需求文档

### Harness 技能（供外部 Agent 装载）

技能体系只约束两层，**不假定获取手段**（搜索/抓取/字幕/PDF 由执行模型自选）：

- [`skills/heimdall-material-skill.md`](./skills/heimdall-material-skill.md) — 素材接入与入库质量规则（API Token + 素材/Agent 接口）
- [`skills/heimdall-collect-skill.md`](./skills/heimdall-collect-skill.md) — 收集任务编排（调研简报 → 分轮执行 → 缺口盘点，可续跑）
- [`skills/heimdall-doctor-skill.md`](./skills/heimdall-doctor-skill.md) — 平台自检（连通 / Token / 素材 API 冒烟）
- [`skills/claude-code/`](./skills/claude-code/) — **Harness 技能包**（`setup-heimdall.sh` 一键初始化：装技能 + 配 Token）
- [`skills/examples/research-plan-example.md`](./skills/examples/research-plan-example.md) — 调研计划模板范本

### 设计规格

- [`superpowers/specs/2026-07-04-creation-workflow-design.md`](./superpowers/specs/2026-07-04-creation-workflow-design.md) — 创作功能设计（素材 · Agent · AI 创作）
- [`superpowers/specs/2026-07-04-llm-config-design.md`](./superpowers/specs/2026-07-04-llm-config-design.md) — LLM 配置设计
- [`superpowers/specs/2026-07-06-collect-task-design.md`](./superpowers/specs/2026-07-06-collect-task-design.md) — 素材收集任务设计（heimdall-collect 技能）
- [`superpowers/specs/2026-07-05-material-research-design.md`](./superpowers/specs/2026-07-05-material-research-design.md) — 调研素材收集设计（已废弃，历史记录）
