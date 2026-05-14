"""Inventory -> per-document Markdown summary.

Output is skill-author-readable. No HTML, no em-dashes or en-dashes.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any


def write_markdown(inventory: dict[str, Any], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(render_markdown(inventory), encoding="utf-8", newline="\n")


def render_markdown(inv: dict[str, Any]) -> str:
    doc = inv.get("document", {}) or {}
    title = doc.get("title") or "(untitled)"
    parts: list[str] = []
    parts.append(f"# Style inventory: {title}")
    parts.append("")
    parts.append(f"- Document ID: `{doc.get('document_id') or 'unknown'}`")
    parts.append(f"- Revision: `{doc.get('revision_id') or 'unknown'}`")
    parts.append("")

    parts.append("## Document")
    parts.append("")
    parts.extend(_kv_table([
        ("Page size", _fmt_size(doc.get("page_size"))),
        ("Orientation", doc.get("orientation") or "(unknown)"),
        ("Margin top", _fmt_dim((doc.get("margins") or {}).get("top"))),
        ("Margin bottom", _fmt_dim((doc.get("margins") or {}).get("bottom"))),
        ("Margin left", _fmt_dim((doc.get("margins") or {}).get("left"))),
        ("Margin right", _fmt_dim((doc.get("margins") or {}).get("right"))),
        ("Header margin", _fmt_dim((doc.get("margins") or {}).get("header"))),
        ("Footer margin", _fmt_dim((doc.get("margins") or {}).get("footer"))),
        ("Default header", doc.get("default_header_id") or "(none)"),
        ("Default footer", doc.get("default_footer_id") or "(none)"),
    ]))
    parts.append("")

    parts.append("## Named styles")
    parts.append("")
    ns = inv.get("named_styles") or []
    if not ns:
        parts.append("No named styles reported.")
    else:
        parts.append(
            "| Style | Font | Size (pt) | Weight | Italic | Underline | Alignment | "
            "Line spacing | Space above (pt) | Space below (pt) |"
        )
        parts.append(
            "|-------|------|-----------|--------|--------|-----------|-----------|"
            "--------------|------------------|------------------|"
        )
        for entry in ns:
            ts = entry.get("text_style") or {}
            ps = entry.get("paragraph_style") or {}
            parts.append(
                "| {style} | {font} | {size} | {weight} | {italic} | {underline} | "
                "{align} | {ls} | {above} | {below} |".format(
                    style=entry.get("named_style_type") or "",
                    font=_or_dash(ts.get("font_family")),
                    size=_or_dash(ts.get("font_size_pt")),
                    weight=_or_dash(ts.get("font_weight")),
                    italic=_bool(ts.get("italic")),
                    underline=_bool(ts.get("underline")),
                    align=_or_dash(ps.get("alignment")),
                    ls=_or_dash(ps.get("line_spacing")),
                    above=_or_dash(ps.get("space_above_pt")),
                    below=_or_dash(ps.get("space_below_pt")),
                )
            )
    parts.append("")

    parts.append("## Body style observations")
    parts.append("")
    obs = inv.get("body_observations") or {}
    distinct = obs.get("distinct_styles") or []
    parts.append(f"Distinct paragraph style fingerprints observed: {len(distinct)}")
    parts.append("")
    if distinct:
        parts.append("| First para # | Named type | Font | Size (pt) | Alignment | Sample |")
        parts.append("|--------------|------------|------|-----------|-----------|--------|")
        for d in distinct:
            ts = d.get("text_style") or {}
            ps = d.get("paragraph_style") or {}
            parts.append(
                "| {i} | {nt} | {font} | {size} | {align} | {sample} |".format(
                    i=d.get("first_paragraph_index"),
                    nt=_or_dash(d.get("named_style_type")),
                    font=_or_dash(ts.get("font_family")),
                    size=_or_dash(ts.get("font_size_pt")),
                    align=_or_dash(ps.get("alignment")),
                    sample=_cell(d.get("sample_text") or ""),
                )
            )
        parts.append("")

    deviations = obs.get("deviations_from_named") or []
    parts.append(f"### Deviations from named styles ({len(deviations)})")
    parts.append("")
    if deviations:
        parts.append("| Para # | Named type | Field | Named value | Observed value |")
        parts.append("|--------|------------|-------|-------------|----------------|")
        for d in deviations:
            named_type = d.get("named_style_type") or ""
            para_idx = d.get("paragraph_index")
            for section_name in ("text_style", "paragraph_style"):
                section = (d.get("deviations") or {}).get(section_name) or {}
                for field, pair in section.items():
                    parts.append(
                        "| {i} | {nt} | {field} | {named} | {observed} |".format(
                            i=para_idx,
                            nt=named_type,
                            field=f"{section_name}.{field}",
                            named=_cell(pair.get("named")),
                            observed=_cell(pair.get("observed")),
                        )
                    )
    else:
        parts.append("None detected.")
    parts.append("")

    parts.append("## Page breaks")
    parts.append("")
    pbs = inv.get("page_breaks") or []
    if not pbs:
        parts.append("No manual page breaks detected.")
    else:
        for pb in pbs:
            parts.append(
                f"- Paragraph {pb.get('paragraph_index')} "
                f"({pb.get('named_style_type_at_break') or 'NORMAL_TEXT'}): "
                f"prev: {_inline(pb.get('previous_paragraph_text'))}; "
                f"next: {_inline(pb.get('next_paragraph_text'))}"
            )
    parts.append("")

    parts.append("## Section breaks")
    parts.append("")
    sbs = inv.get("section_breaks") or []
    if not sbs:
        parts.append("No section breaks detected.")
    else:
        for sb in sbs:
            parts.append(
                f"- Paragraph {sb.get('paragraph_index')}: "
                f"columns={sb.get('column_count')}, "
                f"section_type={sb.get('section_type') or 'CONTINUOUS'}, "
                f"default_header={sb.get('default_header_id') or '(none)'}, "
                f"default_footer={sb.get('default_footer_id') or '(none)'}"
            )
    parts.append("")

    parts.append("## Table of contents")
    parts.append("")
    toc = inv.get("table_of_contents") or {}
    if toc.get("present"):
        for entry in toc.get("instances") or []:
            levels = ", ".join(entry.get("heading_levels_present") or []) or "(none)"
            parts.append(
                f"- At paragraph {entry.get('paragraph_index')}: "
                f"{entry.get('entry_count')} entries, levels: {levels}"
            )
    else:
        parts.append("No table of contents detected.")
    parts.append("")

    parts.append("## Headers and footers")
    parts.append("")
    hf = inv.get("headers_footers") or {}
    for label, key in (("Headers", "headers"), ("Footers", "footers")):
        parts.append(f"### {label}")
        parts.append("")
        items = hf.get(key) or []
        if not items:
            parts.append(f"No {label.lower()} defined.")
        else:
            for h in items:
                parts.append(f"- `{h.get('id')}`:")
                for para in h.get("paragraphs") or []:
                    align = para.get("alignment") or "default"
                    ts = para.get("text_style") or {}
                    font = ts.get("font_family") or "default"
                    size = ts.get("font_size_pt")
                    size_str = f"{size}pt" if size is not None else "default size"
                    parts.append(
                        f"  - [{align}, {font}, {size_str}] "
                        f"{_inline(para.get('text'))}"
                    )
        parts.append("")

    parts.append("## Inline images")
    parts.append("")
    imgs = inv.get("inline_images") or []
    if not imgs:
        parts.append("No inline images detected.")
    else:
        parts.append("| Para # | Object ID | Width | Height | Anchor |")
        parts.append("|--------|-----------|-------|--------|--------|")
        for img in imgs:
            size = img.get("size") or {}
            parts.append(
                "| {i} | {oid} | {w} | {h} | {a} |".format(
                    i=img.get("paragraph_index"),
                    oid=img.get("inline_object_id") or "",
                    w=_fmt_dim(size.get("width")),
                    h=_fmt_dim(size.get("height")),
                    a=img.get("anchor_type") or "",
                )
            )
    parts.append("")

    parts.append("## Tables")
    parts.append("")
    tables = inv.get("tables") or []
    if not tables:
        parts.append("No tables detected.")
    else:
        for t in tables:
            parts.append(
                f"- Paragraph {t.get('paragraph_index')}: "
                f"{t.get('rows')} rows x {t.get('columns')} cols, "
                f"{len(t.get('cell_borders') or [])} cells with borders, "
                f"{len(t.get('cell_backgrounds') or [])} cells with backgrounds"
            )
    parts.append("")
    return "\n".join(parts)


def _kv_table(rows: list[tuple[str, str]]) -> list[str]:
    out = ["| Field | Value |", "|-------|-------|"]
    for k, v in rows:
        out.append(f"| {k} | {v} |")
    return out


def _fmt_dim(dim: Any) -> str:
    if not dim or not isinstance(dim, dict):
        return "(none)"
    mag = dim.get("magnitude")
    unit = dim.get("unit") or ""
    if mag is None:
        return "(none)"
    return f"{mag} {unit}".strip()


def _fmt_size(size: Any) -> str:
    if not size or not isinstance(size, dict):
        return "(unknown)"
    return f"{_fmt_dim(size.get('width'))} x {_fmt_dim(size.get('height'))}"


def _or_dash(value: Any) -> str:
    if value is None or value == "":
        return ""
    return str(value)


def _bool(value: Any) -> str:
    if value is True:
        return "yes"
    if value is False:
        return "no"
    return ""


def _cell(value: Any) -> str:
    """Escape pipes and newlines so the value is safe inside a Markdown table cell."""
    s = "" if value is None else str(value)
    return s.replace("|", "\\|").replace("\n", " ").replace("\r", " ")


def _inline(value: Any) -> str:
    if not value:
        return "(empty)"
    s = str(value).replace("\n", " ").replace("\r", " ")
    return s if len(s) <= 200 else s[:200] + "..."
