---
name: heimdall-doctor
description: >
  Heimdall 平台自检技能：验证 Heimdall 服务连通、API Token 有效性与素材 API 读写。
  当用户要求"检查 Heimdall 环境 / 自检"，或素材读写出现 401/413/422 等平台侧报错时激活。
  只检查平台侧；素材获取手段不做假定，抓取/转换工具由模型按需自行保证可用。
tools: Read, Bash
---

# Heimdall 平台自检技能

新环境、或素材读写报错时先跑这个。只查平台侧三层，全绿即可开始收集任务。

## 1. 环境变量与连通

```bash
echo "API_BASE=$HEIMDALL_API_BASE"            # 如 http://localhost:8000/api
echo "TOKEN前缀=${HEIMDALL_API_TOKEN:0:6}"    # 应为 hd_ 开头，不要回显完整 Token
curl -sS "$HEIMDALL_API_BASE/projects" -H "Authorization: Bearer $HEIMDALL_API_TOKEN"
# 应返回项目 JSON 数组；401 = 服务活着但 Token 无效
```

- 缺环境变量 → 停下来向用户要，不要猜。
- 后端仓库 `.env` 里的 `HEIMDALL_API_TOKEN` 是服务端旧配置，不是这里要的用户 Token；用户 Token 在网页端「API Token 管理」创建。

## 2. 素材 API 冒烟（最小生命周期，结束后必须删除）

1. `POST /projects/{id}/materials`（带 `type`/`origin_url`/`raw_content`）→ 201 且 `source=api`；
2. `GET /materials/{id}` 回读一致；
3. `PATCH` 改标题 → 200（`raw_content` 不可改）；
4. `PUT /materials/{id}/file` 传小文件 → `GET .../file` 回读字节一致；
5. `DELETE` → 204。

## 3. 平台侧已知坑

| 症状 | 原因与解法 |
|---|---|
| 401 | Token 非 `hd_` 前缀 / 已吊销 / 误用服务端 `.env` 旧配置 |
| 上传 413 | 超 100MB（`HEIMDALL_STORAGE_MAX_FILE_MB`）上限，记录留人工 |
| PATCH 422 | 传了不可变字段 `raw_content`，或字段传 null |
| 创建 422 | 缺 `title`，或 `type` 取值非法 |

## 4. 产出

汇报状态表（环境变量 / 连通 / Token / 素材 API，每项 ✅/❌ + 修复动作）。临时测试素材必须清理。
