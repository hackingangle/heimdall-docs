# Material PDF Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 单条素材 Markdown 正文经服务端生成精致 PDF（封面/目录/页眉页脚/品牌色），Web 与 iOS 可下载或分享，便于在 Notion 学习。

**Architecture:** 新增只读 API `GET /api/materials/{id}/export.pdf`。`pdf_export` 模块把 Markdown 转成品牌 HTML，用已有依赖 PyMuPDF `Story.write_stabilized` 生成 PDF（含稳定页码目录）。Web/iOS 只请求该端点并触发下载/系统分享。不新增表或实体。

**Tech Stack:** FastAPI, PyMuPDF Story, `markdown`（MD→HTML）, Noto Sans SC（服务端字体）, React/Ant Design, SwiftUI, pytest, Vitest.

**Spec:** `docs/superpowers/specs/2026-08-01-material-pdf-export-design.md`

---

## File Structure

### Backend (`server/`)

| 路径 | 职责 |
|---|---|
| `app/core/exceptions.py` | 新增 `UnprocessableError`（HTTP 422） |
| `app/services/pdf_export.py` | 纯函数：Markdown→HTML→PDF bytes；sanitize 文件名 |
| `app/services/material.py` | `export_material_pdf(db, user_id, material_id)`：鉴权加载、可导出校验、调渲染 |
| `app/api/materials.py` | `GET /materials/{id}/export.pdf` |
| `app/assets/fonts/README.md` | 字体放置说明 |
| `scripts/fetch_pdf_fonts.py` | 下载 Noto Sans SC 到 `app/assets/fonts/` |
| `tests/test_pdf_export.py` | 渲染单元测试（无 DB） |
| `tests/test_material_pdf_export.py` | API 集成测试 |
| `pyproject.toml` / `uv.lock` | 增加 `markdown` 依赖 |
| `VERSION` | +1 |

### Frontend (`web/`)

| 路径 | 职责 |
|---|---|
| `src/api/materials.ts` | `downloadMaterialPdf(id, title)` |
| `src/components/MaterialViewDrawer.tsx` | 导出菜单「下载 PDF」 |
| `src/components/MaterialViewDrawer.test.tsx` | 菜单项与调用断言 |
| `VERSION` | +1 |

### iOS (`heimdall/`)

| 路径 | 职责 |
|---|---|
| `heimdall/Networking/MaterialsAPI.swift` | `exportPdf(id:)` 路径 |
| `heimdall/Networking/APIClient.swift`（或 Materials 扩展） | `downloadMaterialPdf` |
| `heimdall/Features/Materials/MaterialDetailView.swift` | 工具栏「导出 PDF」+ ShareLink / share sheet |

---

### Task 1: 422 异常 + markdown 依赖 + 字体脚本

**Files:**
- Modify: `server/app/core/exceptions.py`
- Modify: `server/pyproject.toml`
- Create: `server/scripts/fetch_pdf_fonts.py`
- Create: `server/app/assets/fonts/README.md`

- [ ] **Step 1: 增加 `UnprocessableError`**

在 `server/app/core/exceptions.py` 末尾追加：

```python
class UnprocessableError(HeimdallError):
    """业务上无法处理的请求（如素材未就绪无法导出）。"""

    status_code = 422
    code = "unprocessable"
```

- [ ] **Step 2: 添加 `markdown` 依赖**

Run（在 `server/`）：

```bash
uv add markdown
```

Expected: `pyproject.toml` 与 `uv.lock` 更新，含 `markdown`。

- [ ] **Step 3: 字体 README + 下载脚本**

`server/app/assets/fonts/README.md`：

```markdown
# PDF 导出字体

`pdf_export` 需要 **Noto Sans SC Regular**（文件名固定）：

`NotoSansSC-Regular.otf`

生成本地文件：

```bash
uv run python scripts/fetch_pdf_fonts.py
```

部署/CI 跑测试前必须执行该脚本（字体不入库，避免大二进制）。
```

`server/scripts/fetch_pdf_fonts.py`：

```python
"""Download Noto Sans SC Regular into app/assets/fonts/ for PDF export."""

from __future__ import annotations

import urllib.request
from pathlib import Path

# Google Fonts github mirror of Noto Sans SC OTF (static Regular).
FONT_URL = (
    "https://github.com/googlefonts/noto-cjk/raw/main/Sans/OTF/SimplifiedChinese/"
    "NotoSansSC-Regular.otf"
)
DEST = Path(__file__).resolve().parents[1] / "app" / "assets" / "fonts" / "NotoSansSC-Regular.otf"


def main() -> None:
    DEST.parent.mkdir(parents=True, exist_ok=True)
    if DEST.exists() and DEST.stat().st_size > 1_000_000:
        print(f"already present: {DEST}")
        return
    print(f"downloading {FONT_URL} -> {DEST}")
    urllib.request.urlretrieve(FONT_URL, DEST)  # noqa: S310 — pinned upstream URL
    print(f"done: {DEST.stat().st_size} bytes")


if __name__ == "__main__":
    main()
```

若上游 URL 404，改为从 [noto-cjk releases](https://github.com/googlefonts/noto-cjk/releases) 的 `04_NotoSansSC.zip` 解压 `NotoSansSC-Regular.otf`（实现时以能下到为准，更新本脚本与 README）。

- [ ] **Step 4: 拉取字体**

Run:

```bash
cd /Users/ong/ws/heimdall/server && uv run python scripts/fetch_pdf_fonts.py
```

Expected: `app/assets/fonts/NotoSansSC-Regular.otf` 存在且 > 1MB。

- [ ] **Step 5: 把字体加入 `.gitignore`（若尚未忽略）**

在 `server/.gitignore` 增加：

```
app/assets/fonts/*.otf
app/assets/fonts/*.ttf
```

保留 `README.md` 可跟踪。

- [ ] **Step 6: Commit（server 仓库）**

```bash
cd /Users/ong/ws/heimdall/server
git add app/core/exceptions.py pyproject.toml uv.lock scripts/fetch_pdf_fonts.py app/assets/fonts/README.md .gitignore
git commit -m "$(cat <<'EOF'
feat: PDF 导出前置依赖（422、markdown、字体脚本）

EOF
)"
```

---

### Task 2: `pdf_export` 渲染核心（无目录）

**Files:**
- Create: `server/app/services/pdf_export.py`
- Create: `server/tests/test_pdf_export.py`

- [ ] **Step 1: 写失败的单元测试**

`server/tests/test_pdf_export.py`：

```python
from __future__ import annotations

from pathlib import Path

import pymupdf
import pytest

from app.services import pdf_export

FONT = Path(__file__).resolve().parents[1] / "app" / "assets" / "fonts" / "NotoSansSC-Regular.otf"


@pytest.fixture(scope="module", autouse=True)
def _require_font() -> None:
    if not FONT.exists():
        pytest.skip(f"missing font; run: uv run python scripts/fetch_pdf_fonts.py ({FONT})")


def test_render_pdf_magic_and_title() -> None:
    data = pdf_export.render_material_pdf(
        title="内丹法入门",
        content="这是一段中文正文。\n\n第二段。",
        project_name="国学节目",
        exported_on="2026-08-01",
    )
    assert data.startswith(b"%PDF")
    doc = pymupdf.open(stream=data, filetype="pdf")
    assert doc.page_count >= 1
    text = "".join(page.get_text() for page in doc)
    assert "Heimdall" in text
    assert "内丹法入门" in text
    assert "国学节目" in text
    assert "这是一段中文正文" in text


def test_sanitize_pdf_filename() -> None:
    # 与 web sanitizeFilename 对齐：\ / : * ? " < > | → _
    assert pdf_export.pdf_filename('a/b:c*"?.md') == "a_b_c___.md.pdf"
    assert pdf_export.pdf_filename("内丹法") == "内丹法.pdf"
    assert pdf_export.pdf_filename("   ") == "untitled.pdf"


def test_no_toc_without_headings() -> None:
    data = pdf_export.render_material_pdf(
        title="短文",
        content="只有段落，没有二级标题。",
        project_name="P",
        exported_on="2026-08-01",
    )
    doc = pymupdf.open(stream=data, filetype="pdf")
    # 第 0 页封面；无 ## 时后续页不应出现目录页标题
    if doc.page_count > 1:
        assert "目录" not in doc[1].get_text()
```

- [ ] **Step 2: Run 验证 RED**

```bash
cd /Users/ong/ws/heimdall/server && uv run pytest tests/test_pdf_export.py -v
```

Expected: FAIL（`pdf_export` 模块不存在）。

- [ ] **Step 3: 实现 `pdf_export.py`（首版：封面 + 正文 + 页眉页脚，目录下一步）**

```python
"""Render material Markdown to a branded reading PDF via PyMuPDF Story."""

from __future__ import annotations

import io
import re
from pathlib import Path

import markdown as md
import pymupdf

FONT_PATH = Path(__file__).resolve().parents[1] / "assets" / "fonts" / "NotoSansSC-Regular.otf"
PRIMARY = "#d4a574"
_INVALID_FILENAME = re.compile(r'[\\/:*?"<>|]')

CSS = f"""
body {{
  font-family: heimdall-sans, sans-serif;
  color: #1a1a1a;
  font-size: 11pt;
  line-height: 1.55;
}}
h1 {{ font-size: 22pt; color: #111; margin: 0 0 12pt 0; }}
h2 {{ font-size: 16pt; color: #222; margin: 18pt 0 8pt 0; }}
h3 {{ font-size: 13pt; color: #333; margin: 14pt 0 6pt 0; }}
code, pre {{ font-family: heimdall-mono, monospace; font-size: 9.5pt; }}
pre {{
  background-color: #f4f2ee;
  padding: 8pt;
  border-radius: 4pt;
}}
blockquote {{
  border-left: 3pt solid {PRIMARY};
  margin-left: 0;
  padding-left: 10pt;
  color: #555;
}}
a {{ color: {PRIMARY}; }}
.cover-brand {{
  font-size: 14pt;
  color: {PRIMARY};
  letter-spacing: 0.08em;
}}
.cover-meta {{ font-size: 10pt; color: #666; margin-top: 18pt; }}
.cover-rule {{
  margin-top: 28pt;
  border-top: 2pt solid {PRIMARY};
  width: 40%;
}}
.toc-title {{ font-size: 18pt; margin-bottom: 12pt; }}
.toc-item {{ font-size: 11pt; margin: 4pt 0; }}
"""


def sanitize_filename(name: str) -> str:
    cleaned = _INVALID_FILENAME.sub("_", name).strip()
    return cleaned or "untitled"


def pdf_filename(title: str) -> str:
    return f"{sanitize_filename(title)}.pdf"


def _require_font() -> Path:
    if not FONT_PATH.exists():
        raise FileNotFoundError(
            f"PDF 字体缺失: {FONT_PATH}. 请运行: uv run python scripts/fetch_pdf_fonts.py"
        )
    return FONT_PATH


def markdown_to_html(content: str) -> str:
    return md.markdown(
        content,
        extensions=["fenced_code", "tables", "sane_lists", "nl2br"],
        output_format="html5",
    )


def _has_section_headings(content: str) -> bool:
    return bool(re.search(r"(?m)^#{2,3}\s+\S", content))


def render_material_pdf(
    *,
    title: str,
    content: str,
    project_name: str,
    exported_on: str,
) -> bytes:
    """Return PDF bytes. Cover + optional TOC + body; header/footer on non-cover pages."""
    font = _require_font()
    archive = pymupdf.Archive(font.parent)
    body_html = markdown_to_html(content)
    include_toc = _has_section_headings(content)

    def contentfn(positions: list | None) -> str:
        toc_html = ""
        if include_toc:
            items: list[str] = []
            if positions:
                seen: set[str] = set()
                for pos in positions:
                    heading = getattr(pos, "heading", 0) or 0
                    if heading < 2:
                        continue
                    text = (getattr(pos, "text", None) or "").strip()
                    page_num = getattr(pos, "page_num", None)
                    el_id = getattr(pos, "id", None)
                    if not text or page_num is None or el_id in seen:
                        continue
                    seen.add(el_id or text)
                    # page_num from write_stabilized is 1-based in recent pymupdf; clamp display
                    display_page = int(page_num) + (0 if int(page_num) >= 1 else 1)
                    pad = "&nbsp;" * (2 * max(0, heading - 2))
                    href = f"#{el_id}" if el_id else ""
                    label = f"{pad}{text} …… {display_page}"
                    if href:
                        items.append(f'<p class="toc-item"><a href="{href}">{label}</a></p>')
                    else:
                        items.append(f'<p class="toc-item">{label}</p>')
            if not items:
                items.append('<p class="toc-item">（生成中…）</p>')
            toc_html = (
                '<div id="toc"><p class="toc-title">目录</p>'
                + "".join(items)
                + "</div><div style='page-break-after: always;'></div>"
            )

        cover = f"""
        <div id="cover">
          <p class="cover-brand">Heimdall</p>
          <h1>{_escape(title)}</h1>
          <p class="cover-meta">{_escape(project_name)} · 导出日期 {_escape(exported_on)}</p>
          <div class="cover-rule"></div>
        </div>
        <div style="page-break-after: always;"></div>
        """
        return (
            "<html><body>"
            + cover
            + (toc_html if include_toc else "")
            + f'<div id="body">{body_html}</div>'
            + "</body></html>"
        )

    mediabox = pymupdf.paper_rect("a4")
    where = mediabox + (36, 54, -36, -54)

    buf = io.BytesIO()
    writer = pymupdf.DocumentWriter(buf)

    def rectfn(rect_num: int, filled: float) -> tuple:
        # After first layout pass, filled informs remaining work; always same content rect.
        return mediabox, where

    # Header/footer via page callback after each page is created — use write_stabilized
    # with add_header_ids for TOC anchors.
    pymupdf.Story.write_stabilized(
        writer,
        contentfn,
        rectfn,
        user_css=CSS
        + f"""
        @font-face {{
          font-family: heimdall-sans;
          src: url({font.name});
        }}
        """,
        archive=archive,
        add_header_ids=True,
    )
    writer.close()

    doc = pymupdf.open(stream=buf.getvalue(), filetype="pdf")
    _apply_header_footer(doc, title=title)
    if include_toc:
        _apply_outline(doc)
    out = io.BytesIO()
    doc.save(out)
    doc.close()
    return out.getvalue()


def _escape(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def _apply_header_footer(doc: pymupdf.Document, *, title: str) -> None:
    header = title if len(title) <= 40 else title[:39] + "…"
    for i, page in enumerate(doc):
        if i == 0:
            continue  # cover
        # Skip drawing header on a dedicated TOC-only first content page? Still OK to show.
        page.draw_line(
            pymupdf.Point(36, 40),
            pymupdf.Point(page.rect.width - 36, 40),
            color=(0.85, 0.82, 0.78),
            width=0.5,
        )
        page.insert_text(
            pymupdf.Point(36, 32),
            header,
            fontname="helv",
            fontsize=8,
            color=(0.4, 0.4, 0.4),
        )
        y = page.rect.height - 28
        page.insert_text(
            pymupdf.Point(page.rect.width / 2 - 6, y),
            str(i + 1),
            fontname="helv",
            fontsize=8,
            color=(0.4, 0.4, 0.4),
        )
        page.insert_text(
            pymupdf.Point(page.rect.width - 70, y),
            "Heimdall",
            fontname="helv",
            fontsize=8,
            color=(0.83, 0.65, 0.45),
        )


def _apply_outline(doc: pymupdf.Document) -> None:
    toc: list[list] = []
    for i, page in enumerate(doc):
        blocks = page.get_text("dict")["blocks"]
        for block in blocks:
            for line in block.get("lines", []):
                for span in line.get("spans", []):
                    size = span.get("size", 0)
                    text = (span.get("text") or "").strip()
                    if not text or text in {"Heimdall", "目录"}:
                        continue
                    if size >= 15:
                        toc.append([1, text, i + 1])
                    elif size >= 12.5:
                        toc.append([2, text, i + 1])
    # Prefer Story-generated outline if available; fallback size heuristic is best-effort.
    if toc:
        # De-dup consecutive identical
        cleaned: list[list] = []
        for item in toc:
            if cleaned and cleaned[-1][1] == item[1] and cleaned[-1][2] == item[2]:
                continue
            cleaned.append(item)
        try:
            doc.set_toc(cleaned[:80])
        except Exception:
            pass
```

实现时注意：

1. `Story.write_stabilized` / `rectfn` 签名以当前已安装 `pymupdf` 文档为准；若与上文不符，按官方 `write_stabilized` 示例调整（`rectfn(rect_num, filled) -> (mediabox, where[, reserved])`）。
2. 页眉中文标题若 `helv` 无法显示，改用 `page.insert_font(fontfile=FONT_PATH)` + `insert_text(..., fontname=that)`。
3. 首版若 `write_stabilized` 调通成本高：可先 `Story.write` 无目录让 Task 2 测试过，Task 3 再补目录——但最终必须满足 spec 的目录要求。

- [ ] **Step 4: Run 验证 GREEN（无目录用例 + magic）**

```bash
cd /Users/ong/ws/heimdall/server && uv run pytest tests/test_pdf_export.py::test_render_pdf_magic_and_title tests/test_pdf_export.py::test_sanitize_pdf_filename tests/test_pdf_export.py::test_no_toc_without_headings -v
```

Expected: PASS。

- [ ] **Step 5: Commit**

```bash
cd /Users/ong/ws/heimdall/server
git add app/services/pdf_export.py tests/test_pdf_export.py
git commit -m "$(cat <<'EOF'
feat: Markdown 素材渲染为品牌 PDF

EOF
)"
```

---

### Task 3: 目录页（有 `##`/`###` 时）

**Files:**
- Modify: `server/app/services/pdf_export.py`
- Modify: `server/tests/test_pdf_export.py`

- [ ] **Step 1: 写失败的目录测试**

```python
def test_toc_when_headings_present() -> None:
    content = """## 缘起

说明。

## 方法

步骤。

### 细则

补充。
"""
    data = pdf_export.render_material_pdf(
        title="带目录的稿",
        content=content,
        project_name="P",
        exported_on="2026-08-01",
    )
    doc = pymupdf.open(stream=data, filetype="pdf")
    full = "".join(page.get_text() for page in doc)
    assert "目录" in full
    assert "缘起" in full
    assert "方法" in full
    outline = doc.get_toc()
    assert outline, "expected PDF outline/bookmarks"
    labels = {item[1] for item in outline}
    assert "缘起" in labels or any("缘起" in x for x in labels)
```

- [ ] **Step 2: Run 验证 RED 或已绿**

```bash
uv run pytest tests/test_pdf_export.py::test_toc_when_headings_present -v
```

若 RED：按 PyMuPDF `Story.write_stabilized` + `add_header_ids=True` 修好 `contentfn` 的 TOC 列表与 `doc.set_toc`（优先用 `element_positions` 的 heading/id/page_num 构建 outline，而不是字体 size 启发式）。

参考：https://pymupdf.readthedocs.io/en/latest/story-class.html （`write_stabilized`）

- [ ] **Step 3: Run 全文件 GREEN**

```bash
uv run pytest tests/test_pdf_export.py -v
```

Expected: PASS。

- [ ] **Step 4: Commit**

```bash
git add app/services/pdf_export.py tests/test_pdf_export.py
git commit -m "$(cat <<'EOF'
feat: PDF 导出支持目录与书签

EOF
)"
```

---

### Task 4: Material 服务 + API 端点

**Files:**
- Modify: `server/app/services/material.py`
- Modify: `server/app/api/materials.py`
- Create: `server/tests/test_material_pdf_export.py`
- Modify: `server/VERSION`（+1，与本任务功能同一 commit）

- [ ] **Step 1: 写失败的 API 测试**

`server/tests/test_material_pdf_export.py`：

```python
from __future__ import annotations

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from tests.test_materials import _create_project, _headers, _materials_url, _register

FONT = Path(__file__).resolve().parents[1] / "app" / "assets" / "fonts" / "NotoSansSC-Regular.otf"


@pytest.fixture(scope="module", autouse=True)
def _require_font() -> None:
    if not FONT.exists():
        pytest.skip(f"missing font; run scripts/fetch_pdf_fonts.py")


@pytest.fixture
def alice_token(client: TestClient) -> str:
    return _register(client, "alice")


@pytest.fixture
def project_id(client: TestClient, alice_token: str) -> int:
    return _create_project(client, alice_token)


def test_export_pdf_ok(client: TestClient, alice_token: str, project_id: int) -> None:
    created = client.post(
        _materials_url(project_id),
        json={"title": "导出我", "content": "## A\n\n正文中文"},
        headers=_headers(alice_token),
    )
    assert created.status_code == 201
    mid = created.json()["id"]

    resp = client.get(f"/api/materials/{mid}/export.pdf", headers=_headers(alice_token))
    assert resp.status_code == 200, resp.text
    assert resp.headers["content-type"].startswith("application/pdf")
    assert resp.content.startswith(b"%PDF")
    assert "attachment" in resp.headers.get("content-disposition", "")


def test_export_pdf_rejects_generating(client: TestClient, alice_token: str, project_id: int) -> None:
    # 若测试环境不易造 generating，可直接改 DB；或 mock。
    # 简便：创建后 patch status（见实现备选）。
    from app.db import SessionLocal
    from app.models.material import Material

    created = client.post(
        _materials_url(project_id),
        json={"title": "生成中", "content": "x"},
        headers=_headers(alice_token),
    )
    mid = created.json()["id"]
    with SessionLocal() as db:
        row = db.get(Material, mid)
        assert row is not None
        row.status = "generating"
        row.content = None
        db.commit()

    resp = client.get(f"/api/materials/{mid}/export.pdf", headers=_headers(alice_token))
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "unprocessable"


def test_export_pdf_404_other_user(client: TestClient, alice_token: str, project_id: int) -> None:
    created = client.post(
        _materials_url(project_id),
        json={"title": "私有", "content": "secret"},
        headers=_headers(alice_token),
    )
    mid = created.json()["id"]
    bob = _register(client, "bob")
    resp = client.get(f"/api/materials/{mid}/export.pdf", headers=_headers(bob))
    assert resp.status_code == 404
```

确认测试里 `SessionLocal` 的导入路径与项目一致（见 `app/db.py`）；若不同则改用项目既有测试改库方式。

- [ ] **Step 2: Run 验证 RED**

```bash
uv run pytest tests/test_material_pdf_export.py -v
```

Expected: FAIL（路由 404）。

- [ ] **Step 3: 服务层**

在 `server/app/services/material.py` 增加：

```python
from datetime import date
from urllib.parse import quote

from app.core.exceptions import UnprocessableError
from app.services import pdf_export
from app.services.project import get_project

def export_material_pdf(db: Session, user_id: int, material_id: int) -> tuple[str, bytes]:
    material = get_material(db, user_id, material_id)
    if material.status != "ready" or not (material.content or "").strip():
        raise UnprocessableError("素材尚未就绪，无法导出")
    project = get_project(db, user_id, material.project_id)
    data = pdf_export.render_material_pdf(
        title=material.title,
        content=material.content or "",
        project_name=project.title,
        exported_on=date.today().isoformat(),
    )
    return pdf_export.pdf_filename(material.title), data
```

- [ ] **Step 4: 路由**

在 `server/app/api/materials.py` 的 `get_material` 附近增加：

```python
@router.get("/materials/{material_id}/export.pdf")
def export_material_pdf(
    material_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Response:
    filename, data = material_service.export_material_pdf(db, current_user.id, material_id)
    return Response(
        content=data,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f"attachment; filename*=UTF-8''{quote(filename)}"
        },
    )
```

- [ ] **Step 5: VERSION +1**

```bash
echo $(( $(tr -d '[:space:]' < VERSION) + 1 )) > VERSION
```

- [ ] **Step 6: Run GREEN**

```bash
uv run pytest tests/test_material_pdf_export.py tests/test_pdf_export.py -v
```

Expected: PASS。

- [ ] **Step 7: Commit**

```bash
git add app/services/material.py app/api/materials.py tests/test_material_pdf_export.py VERSION
git commit -m "$(cat <<'EOF'
feat: 素材导出 PDF API

EOF
)"
```

- [ ] **Step 8: 部署字体**

在 `server/deploy/scripts/` 中实际被 CI 调用的部署脚本里，于依赖安装后增加一行（找到现有 `uv sync` / `pip install` 附近）：

```bash
uv run python scripts/fetch_pdf_fonts.py
```

若脚本路径相对 `server` 根目录不同，按现有 cwd 调整。并在 `server/deploy/README.md` 注明生产需有该字体文件。

Commit：

```bash
git add deploy && git commit -m "$(cat <<'EOF'
chore: 部署时拉取 PDF 导出色字体

EOF
)"
```

（若你更希望把字体提交进仓库而不是部署拉取，可改为 commit otf 并撤销 gitignore——二选一，优先脚本拉取以保持仓库小。）

---

### Task 5: Web「下载 PDF」

**Files:**
- Modify: `web/src/api/materials.ts`
- Modify: `web/src/components/MaterialViewDrawer.tsx`
- Modify: `web/src/components/MaterialViewDrawer.test.tsx`
- Modify: `web/VERSION`

- [ ] **Step 1: 写失败的组件测试**

在 `MaterialViewDrawer.test.tsx` 顶部 mock 增加 `downloadMaterialPdf`（与现有 `downloadMaterialFile` mock 并列）：

```ts
vi.mock("../api/materials", () => ({
  downloadMaterialFile: vi.fn(),
  downloadMaterialPdf: vi.fn(),
  // 保留该文件里已有的其它导出…
}));
```

若当前 mock 是部分 mock，改为：

```ts
downloadMaterialPdf: vi.fn(),
```

并新增用例：

```ts
it("导出菜单可下载 PDF", async () => {
  const user = userEvent.setup();
  const { downloadMaterialPdf } = await import("../api/materials");
  renderWithProviders(
    <MaterialViewDrawer
      open
      material={makeMaterial({ title: "我的稿", content: "# Hi\n\n正文" })}
      onSave={() => {}}
      onClose={() => {}}
    />,
  );
  await user.click(screen.getByRole("button", { name: /导出/ }));
  await user.click(await screen.findByText("下载 PDF"));
  expect(downloadMaterialPdf).toHaveBeenCalledWith(1, "我的稿");
});
```

（`makeMaterial` 默认 id 以现有 helper 为准。）

- [ ] **Step 2: Run RED**

```bash
cd /Users/ong/ws/heimdall/web && npm test -- src/components/MaterialViewDrawer.test.tsx
```

Expected: FAIL（无菜单项或未定义 `downloadMaterialPdf`）。

- [ ] **Step 3: API 函数**

在 `web/src/api/materials.ts` 增加（复用已有 `triggerBlobDownload`；若它是 module-private，保持同文件内调用）：

```ts
import { sanitizeFilename } from "../lib/script";

/** 下载服务端渲染的素材 PDF。 */
export async function downloadMaterialPdf(id: number, title: string): Promise<void> {
  const { data } = await api.get<Blob>(`/api/materials/${id}/export.pdf`, {
    responseType: "blob",
    timeout: 60_000,
  });
  triggerBlobDownload(data, `${sanitizeFilename(title)}.pdf`);
}
```

- [ ] **Step 4: 菜单项**

`MaterialViewDrawer.tsx`：

1. import `downloadMaterialPdf`
2. state：`const [exportingPdf, setExportingPdf] = useState(false)`
3. menu items 增加 `{ key: "pdf", icon: <DownloadOutlined />, label: "下载 PDF", disabled: exportingPdf }`
4. onClick：

```ts
if (key === "pdf") {
  setExportingPdf(true);
  void downloadMaterialPdf(material.id, material.title)
    .then(() => message.success("PDF 已下载"))
    .catch(() => message.error("导出失败，请稍后重试"))
    .finally(() => setExportingPdf(false));
  return;
}
```

导出 Button 可加 `loading={exportingPdf}`。

- [ ] **Step 5: VERSION +1 与 GREEN**

```bash
echo $(( $(tr -d '[:space:]' < VERSION) + 1 )) > VERSION
npm test -- src/components/MaterialViewDrawer.test.tsx
```

Expected: PASS。

- [ ] **Step 6: Commit（web 仓库）**

```bash
cd /Users/ong/ws/heimdall/web
git add src/api/materials.ts src/components/MaterialViewDrawer.tsx src/components/MaterialViewDrawer.test.tsx VERSION
git commit -m "$(cat <<'EOF'
feat: 素材导出菜单支持下载 PDF

EOF
)"
```

---

### Task 6: iOS 导出 PDF

**Files:**
- Modify: `heimdall/heimdall/Networking/MaterialsAPI.swift`
- Modify: `heimdall/heimdall/Networking/APIClient.swift`（Materials 扩展段）
- Modify: `heimdall/heimdall/Features/Materials/MaterialDetailView.swift`
- 若有现成 sanitize：复用；否则在 View 内做简单替换

- [ ] **Step 1: API 路径**

`MaterialsAPI.swift`：

```swift
static func exportPdf(id: Int) -> String {
    "\(detail(id: id))/export.pdf"
}
```

- [ ] **Step 2: Client 方法**

在 `APIClient` 的 Materials 扩展中：

```swift
func downloadMaterialPdf(id: Int) async throws -> Data {
    try await download(MaterialsAPI.exportPdf(id: id), timeout: 60)
}
```

- [ ] **Step 3: UI**

在 `MaterialDetailView`：

- `@State private var exportPdfURL: URL?`
- `@State private var isExportingPdf = false`
- `@State private var exportErrorMessage: String?`
- 计算属性：`private var canExportPdf: Bool { material?.status == .ready && !(material?.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }`

Toolbar 增加（在编辑按钮旁）：

```swift
if canExportPdf {
    ToolbarItem(placement: .secondaryAction) {
        Button {
            Task { await exportPdf() }
        } label: {
            if isExportingPdf {
                ProgressView()
            } else {
                Label("导出 PDF", systemImage: "square.and.arrow.up")
            }
        }
        .disabled(isExportingPdf)
    }
}
```

并用 `.sheet` / `ShareLink` 分享临时文件：

```swift
@MainActor
private func exportPdf() async {
    guard let material else { return }
    isExportingPdf = true
    defer { isExportingPdf = false }
    do {
        let data = try await appScope.api.downloadMaterialPdf(id: material.id)
        let safe = material.title
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safe.isEmpty ? "untitled" : safe).pdf")
        try data.write(to: url, options: .atomic)
        exportPdfURL = url
    } catch {
        exportErrorMessage = "导出失败，请稍后重试"
    }
}
```

用 `.sheet(item:)` 或 `ShareLink`/`UIActivityViewController` 包装 `exportPdfURL`（与 `MaterialFilePreview` 的 ShareLink 模式对齐）。

- [ ] **Step 4: 手动验证清单（模拟器）**

1. 打开一条 `ready` 且有正文的素材 → 可见「导出 PDF」
2. 点导出 → 出现分享面板，文件为 PDF
3. `generating` 素材 → 无导出入口

- [ ] **Step 5: Commit（heimdall iOS 仓库）**

```bash
cd /Users/ong/ws/heimdall/heimdall
git add heimdall/Networking/MaterialsAPI.swift heimdall/Networking/APIClient.swift heimdall/Features/Materials/MaterialDetailView.swift
git commit -m "$(cat <<'EOF'
feat: 素材详情支持导出 PDF

EOF
)"
```

---

### Task 7: 端到端冒烟

- [ ] **Step 1: 后端回归**

```bash
cd /Users/ong/ws/heimdall/server && uv run python scripts/fetch_pdf_fonts.py && uv run pytest tests/test_pdf_export.py tests/test_material_pdf_export.py -v
```

Expected: PASS。

- [ ] **Step 2: 前端相关测试**

```bash
cd /Users/ong/ws/heimdall/web && npm test -- src/components/MaterialViewDrawer.test.tsx
```

Expected: PASS。

- [ ] **Step 3: 手工 API 冒烟（本地 server 已启动时）**

```bash
curl -sD - -o /tmp/m.pdf -H "Authorization: Bearer $TOKEN" \
  "$BASE/api/materials/$ID/export.pdf" | head
file /tmp/m.pdf
```

Expected: `200`、`application/pdf`、`/tmp/m.pdf: PDF document`。

---

## Spec Coverage Checklist

| Spec 项 | Task |
|---|---|
| `GET .../export.pdf` 同步返回 | Task 4 |
| 可导出条件 ready + 非空 content | Task 4 |
| 不新增实体 | 全任务 |
| 封面 / 品牌色 / 项目名 / 日期 | Task 2 |
| 目录 + 书签（有 ##/###） | Task 3 |
| 页眉页脚 | Task 2 |
| 中文字体 | Task 1–2 |
| 仅正文，不含 raw/原件 | Task 2/4 |
| 401/404/422/500 约定 | Task 1 + 4 |
| Web 导出菜单 | Task 5 |
| iOS 分享 | Task 6 |
| 文件名 sanitize | Task 2 + 5 |

## Notes for Implementers

- 三个 Git 仓库分别 commit；不要在 monorepo 根目录找统一 `.git`。
- CI：`server` 的 test workflow 若存在，在 `pytest` 前加 `uv run python scripts/fetch_pdf_fonts.py`（需 network）。
- PyMuPDF Story API 随小版本可能有差异；以本机 `pymupdf` 文档与 `tests/test_pdf_export.py` 为准，不要死磕上文伪代码的每一个关键字参数名。
- 页眉用嵌入字体绘制中文，避免 Helvetica 缺字。
