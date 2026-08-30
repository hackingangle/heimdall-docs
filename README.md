# Heimdall Docs

Heimdall 项目的产品与设计文档。代码在独立仓库维护。

> Heimdall 是一个通用的、有状态的多 Agent 协作数据层（控制平面）。设计哲学：**机制与策略分离**——后端只做机制（存数据 + 守最小规则），所有策略交给外部 Harness/Agent。

## 目录

- [`prds/Heimdall PRD 1.0.md`](./prds/Heimdall%20PRD%201.0.md) — **现行产品需求（按已实现功能；含主路径 / 素材 / 创作 / 跟读图）**
- [`Heimdall-PRD-1.0.html`](./Heimdall-PRD-1.0.html) — 同上 HTML，给投资人投屏
- [`Heimdall-技术实现交接.md`](./Heimdall-技术实现交接.md) — **技术交接 Markdown（仓库图、运行时接线、鉴权、发布流水线）**
- [`Heimdall-技术实现交接.html`](./Heimdall-技术实现交接.html) — 同上 HTML
- [`prds/Heimdall PRD.md`](./prds/Heimdall%20PRD.md) — 立项愿景稿 v0.3（任务表编排，仅历史）

### Harness 技能（供外部 Agent 装载）

技能真源在独立公开仓 [heimdall-skills](https://github.com/hackingangle/heimdall-skills)（本地 `~/ws/heimdall/skills`）。本仓不托管安装脚本。

```bash
curl -fsSL https://raw.githubusercontent.com/hackingangle/heimdall-skills/main/setup-heimdall.sh | bash -s -- "<API_BASE>"
```

### 设计规格

- [`superpowers/specs/2026-07-04-creation-workflow-design.md`](./superpowers/specs/2026-07-04-creation-workflow-design.md) — 创作功能设计（素材 · Agent · AI 创作）
- [`superpowers/specs/2026-07-04-llm-config-design.md`](./superpowers/specs/2026-07-04-llm-config-design.md) — LLM 配置设计
- [`superpowers/specs/2026-07-06-collect-task-design.md`](./superpowers/specs/2026-07-06-collect-task-design.md) — 素材收集任务设计（heimdall-collect 技能）
- [`superpowers/specs/2026-07-26-multimodal-material-ingestion-design.md`](./superpowers/specs/2026-07-26-multimodal-material-ingestion-design.md) — 多模态素材理解与 PDF 自动解析演进设计
- [`superpowers/specs/2026-07-05-material-research-design.md`](./superpowers/specs/2026-07-05-material-research-design.md) — 调研素材收集设计（已废弃，历史记录）
- [`superpowers/specs/2026-08-30-heimdall-skills-repo-design.md`](./superpowers/specs/2026-08-30-heimdall-skills-repo-design.md) — 管道技能拆到 heimdall-skills
