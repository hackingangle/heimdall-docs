# 素材导出 PDF 设计

- 日期：2026-08-01
- 状态：已确认
- 产品目标：单条素材正文可导出为精致 PDF，便于在 Notion 等工具中阅读学习；Web 与 iOS 入口一致，版式由服务端统一生成。

## 1. 范围与原则

### 做

- 导出**单条**素材的 Markdown 正文为 PDF
- 精致阅读版式：封面、目录（有标题时）、分页、页眉页脚、Heimdall 品牌点缀
- Web + iOS 均可触发下载/分享
- 服务端为唯一版式真相（PyMuPDF Story）

### 不做（YAGNI）

- 项目级批量打包 PDF
- Notion API 直连同步
- 导出设置页 / 用户自定义模板
- 异步任务表、导出历史实体
- 附带原件 PDF 或 `raw_content`
- 首版不引入 WeasyPrint 等额外系统依赖

### 原则

1. **不新增领域实体**：导出是 Material 的只读派生。
2. **两端一致**：Web / iOS 只调同一 API，不在客户端各自排版。
3. **阅读向纸面**：浅色背景 + 琥珀强调色，不把 Web 暗色 UI 原样印进 PDF。
4. **中文可靠**：服务端嵌入中文字体，不依赖客户端字体。

## 2. 架构与数据流

```text
Web / iOS
  → GET /api/materials/{id}/export.pdf  （现有鉴权）
  → 校验归属与可导出条件
  → 读取 title、content、所属项目名
  → Markdown → 品牌 HTML 模板 → PyMuPDF Story → PDF bytes
  → application/pdf + Content-Disposition: attachment
```

| 组件 | 职责 |
|---|---|
| `GET /api/materials/{id}/export.pdf` | 鉴权、校验、返回 PDF 流 |
| `pdf_export` 服务模块 | Markdown 渲染、套模板、生成 PDF（唯一版式真相） |
| Web「导出」菜单 | 增加「下载 PDF」 |
| iOS 素材详情 | 「导出 PDF」→ 临时文件 → 系统分享 |

可导出条件（全部满足）：

- 素材属于当前用户
- `status == ready`
- `content` 非空（去空白后）

同步生成即可；口播稿体量通常可接受。客户端/反代建议约 60s 超时；若上线后偶发超时，再考虑异步——**首版不做任务队列**。

## 3. PDF 版式

视觉对齐 Heimdall Web token，但改为阅读向浅色纸面：

- 强调色：`#d4a574`（`--heimdall-primary`）
- 正文字色：深灰近黑；次要信息用中灰
- 字体：正文 Noto Sans SC（服务端打包嵌入）；代码等宽

### 页面结构

1. **封面**（独立一页）
   - 品牌字标「Heimdall」
   - 素材标题（大号）
   - 次要：所属项目名、导出日期
   - 底边琥珀强调线

2. **目录**（仅当正文存在 `##` / `###` 时生成；否则跳过整页）
   - 由标题自动生成条目 + 页码
   - 目录条目可跳转到对应正文位置；同时写入 PDF 大纲书签

3. **正文**
   - 支持：标题、段落、列表、引用、代码块、粗斜体、链接
   - 表格：简单 GFM；复杂表降级为可读文本
   - 代码块：等宽 + 浅底，避免横向溢出严重裁切

4. **页眉 / 页脚**（封面除外）
   - 页眉：素材标题（过长截断）
   - 页脚：居中页码；右侧小字「Heimdall」

### 文件名

`{sanitize(title)}.pdf`，与现有 `.md` / `.txt` 导出命名规则一致。

## 4. Web / iOS 入口

### Web（`MaterialViewDrawer`）

在现有「导出」菜单增加 **下载 PDF**（与复制全文 / `.md` / `.txt` 并列）。

- 启用条件与现有导出相同：`status === ready` 且有 `content`
- 点击 → 鉴权请求 `export.pdf` → 浏览器下载
- 请求中按钮 loading；失败用现有消息提示

### iOS（`MaterialDetailView`）

工具栏/菜单增加 **导出 PDF**。

- 同样仅 `ready` + 有正文时可用
- 下载到临时文件 → 系统分享（存文件 / AirDrop / 打开 Notion 等）
- 下载中禁用重复触发并给出进行中反馈

## 5. 错误处理

| 情况 | HTTP | 说明 |
|---|---|---|
| 未登录 / Token 无效 | 401 | 与现有 API 一致 |
| 素材不存在或不属于当前用户 | 404 | 与现有 API 一致 |
| `content` 空，或 `status` 为 `generating` / `failed` | 422 | 文案如「素材尚未就绪，无法导出」 |
| 渲染/字体等内部失败 | 500 | 统一 `{"error": {"code", "message"}}`；客户端提示重试 |

错误响应格式与平台现有约定一致。

## 6. 测试要点

- 可导出素材：响应 `Content-Type: application/pdf`，正文以 `%PDF` 开头
- 不可导出：返回 422；鉴权/归属与现有材料接口一致
- 含 `##` 的正文生成目录；无标题则无目录页
- 中文抽样不缺字形
- Web：菜单有「下载 PDF」，禁用态与现有导出一致
- iOS：就绪可分享 PDF；未就绪入口不可用

## 7. 实现备注

- 复用已有依赖 `pymupdf`（Story HTML/CSS → PDF），避免 WeasyPrint 系统库负担
- 中文字体文件纳入后端仓库或部署产物（路径由配置/约定常量指定），Docker/CI 镜像需包含该字体
- 不改 Material 表结构；无需 Alembic migration
- 版本 bump：改 `server/`、`web/`、`heimdall/`（iOS）时各自按仓库规则 +1
