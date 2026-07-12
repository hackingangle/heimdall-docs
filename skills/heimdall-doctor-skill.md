# Heimdall 平台自检技能（heimdall-doctor-skill）

> 供 Claude Code 等外部 Harness 作为技能装载。在跑收集任务之前，验证 Heimdall 平台侧的连通与凭证；新环境、或素材读写报错时先跑这个。
>
> 只检查**平台侧**（服务、Token、素材 API）。素材获取手段不做假定，因此不检查任何抓取/转换工具——模型用什么手段，就自行保证该手段可用。

- 日期：2026-07-06
- 服务对象：[heimdall-collect-skill](./heimdall-collect-skill.md) / [heimdall-material-skill](./heimdall-material-skill.md)

## 1. 环境变量与连通

```bash
echo "API_BASE=$HEIMDALL_API_BASE"            # 如 http://localhost:8000/api
echo "TOKEN前缀=${HEIMDALL_API_TOKEN:0:6}"    # 应为 hd_ 开头，不要回显完整 Token

# 后端连通 + Token 有效性（应返回项目 JSON 数组；401 = 服务活着但 Token 无效）
curl -sS "$HEIMDALL_API_BASE/projects" -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
```

- 缺环境变量 → 停下来向用户要，不要猜。
- 注意：后端仓库 `.env` 里的 `HEIMDALL_API_TOKEN` 是服务端旧配置，**不是**这里要的用户 Token；用户 Token 在网页端「API Token 管理」创建，明文只显示一次。

## 2. 素材 API 冒烟（最小生命周期）

在任意项目建一条临时素材走完整生命周期，**结束后必须删除**：

1. `POST /projects/{id}/materials`（带 `type` / `origin_url` / `raw_content`）→ 应返回 201 且 `source=api`、`raw_content` 已存；
2. `GET /materials/{id}` 回读一致；
3. `PATCH` 改标题 → 200（注意 `raw_content` 不可改，PATCH 不接受）；
4. `PUT /materials/{id}/file` 传一个小文件原件 → `GET .../file` 回读字节数一致；
5. `DELETE` 清理 → 204。

## 3. 平台侧已知坑

| 症状 | 原因与解法 |
|---|---|
| 素材 API 返回 401 | Token 非 `hd_` 前缀 / 已被吊销 / 误用服务端 `.env` 里的旧配置 |
| 原件上传返回 413 | 超 `HEIMDALL_STORAGE_MAX_FILE_MB`（默认 100MB）上限，记录后留人工 |
| PATCH 报 422 | 传了 `raw_content`（不可变字段）或字段传了 null |
| 创建素材 422 | 缺 `title`，或 `type` 取值不在 text/pdf |

## 4. 产出

向用户汇报状态表（环境变量 / 后端连通 / Token / 素材 API 生命周期，每项 ✅ 或 ❌ + 修复动作），全绿即可开始收集任务。临时测试素材必须清理。
