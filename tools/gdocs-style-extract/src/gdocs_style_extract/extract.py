"""Pure extraction functions: Docs API JSON -> inventory dict.

The inventory is the canonical intermediate representation. Both the JSON
emitter and the Markdown emitter consume it. No I/O happens here.
"""

from __future__ import annotations

from typing import Any

# Top-level inventory keys mirror the extraction targets from the brief.
CATEGORIES = (
    "document",
    "named_styles",
    "body_observations",
    "page_breaks",
    "section_breaks",
    "table_of_contents",
    "headers_footers",
    "inline_images",
    "tables",
)

# A small helper alias for clarity.
Doc = dict[str, Any]


def build_inventory(doc: Doc) -> dict[str, Any]:
    """Build the full inventory dict for a single document.

    The input is the raw Docs API response (documents.get). The output is a
    plain dict suitable for json.dumps and for Markdown rendering.
    """
    named_styles = extract_named_styles(doc)
    return {
        "document": extract_document_level(doc),
        "named_styles": named_styles,
        "body_observations": extract_body_observations(doc, named_styles),
        "page_breaks": extract_page_breaks(doc),
        "section_breaks": extract_section_breaks(doc),
        "table_of_contents": extract_table_of_contents(doc),
        "headers_footers": extract_headers_footers(doc),
        "inline_images": extract_inline_images(doc),
        "tables": extract_tables(doc),
    }


# Document level ---------------------------------------------------------

def extract_document_level(doc: Doc) -> dict[str, Any]:
    ds = doc.get("documentStyle", {}) or {}
    page_size = ds.get("pageSize", {}) or {}
    width = _dim(page_size.get("width"))
    height = _dim(page_size.get("height"))
    orientation = _orientation(width, height)
    return {
        "title": doc.get("title"),
        "document_id": doc.get("documentId"),
        "revision_id": doc.get("revisionId"),
        "page_size": {"width": width, "height": height},
        "orientation": orientation,
        "margins": {
            "top": _dim(ds.get("marginTop")),
            "bottom": _dim(ds.get("marginBottom")),
            "left": _dim(ds.get("marginLeft")),
            "right": _dim(ds.get("marginRight")),
            "header": _dim(ds.get("marginHeader")),
            "footer": _dim(ds.get("marginFooter")),
        },
        "default_header_id": ds.get("defaultHeaderId"),
        "default_footer_id": ds.get("defaultFooterId"),
        "use_custom_header_footer_margins": ds.get("useCustomHeaderFooterMargins"),
        "page_number_start": ds.get("pageNumberStart"),
    }


# Named styles -----------------------------------------------------------

def extract_named_styles(doc: Doc) -> list[dict[str, Any]]:
    ns_root = doc.get("namedStyles", {}) or {}
    out: list[dict[str, Any]] = []
    for entry in ns_root.get("styles", []) or []:
        text_style = entry.get("textStyle", {}) or {}
        paragraph_style = entry.get("paragraphStyle", {}) or {}
        out.append(
            {
                "named_style_type": entry.get("namedStyleType"),
                "text_style": summarize_text_style(text_style),
                "paragraph_style": summarize_paragraph_style(paragraph_style),
                "raw_text_style": text_style,
                "raw_paragraph_style": paragraph_style,
            }
        )
    return out


def summarize_text_style(ts: dict[str, Any]) -> dict[str, Any]:
    weighted_font = ts.get("weightedFontFamily") or {}
    return {
        "font_family": weighted_font.get("fontFamily"),
        "font_weight": weighted_font.get("weight"),
        "font_size_pt": _magnitude(ts.get("fontSize")),
        "bold": ts.get("bold"),
        "italic": ts.get("italic"),
        "underline": ts.get("underline"),
        "strikethrough": ts.get("strikethrough"),
        "small_caps": ts.get("smallCaps"),
        "foreground_color": _color(ts.get("foregroundColor")),
        "background_color": _color(ts.get("backgroundColor")),
        "baseline_offset": ts.get("baselineOffset"),
        "link": (ts.get("link") or {}).get("url"),
    }


def summarize_paragraph_style(ps: dict[str, Any]) -> dict[str, Any]:
    return {
        "alignment": ps.get("alignment"),
        "line_spacing": ps.get("lineSpacing"),
        "spacing_mode": ps.get("spacingMode"),
        "space_above_pt": _magnitude(ps.get("spaceAbove")),
        "space_below_pt": _magnitude(ps.get("spaceBelow")),
        "indent_first_line_pt": _magnitude(ps.get("indentFirstLine")),
        "indent_start_pt": _magnitude(ps.get("indentStart")),
        "indent_end_pt": _magnitude(ps.get("indentEnd")),
        "direction": ps.get("direction"),
        "keep_lines_together": ps.get("keepLinesTogether"),
        "keep_with_next": ps.get("keepWithNext"),
        "avoid_widow_and_orphan": ps.get("avoidWidowAndOrphan"),
        "shading_background": _color((ps.get("shading") or {}).get("backgroundColor")),
        "border_between": ps.get("borderBetween"),
        "border_top": ps.get("borderTop"),
        "border_bottom": ps.get("borderBottom"),
        "border_left": ps.get("borderLeft"),
        "border_right": ps.get("borderRight"),
    }


# Body observations ------------------------------------------------------

def extract_body_observations(
    doc: Doc, named_styles: list[dict[str, Any]]
) -> dict[str, Any]:
    """Walk body paragraphs and collect distinct style tuples plus deviations."""
    by_named_type = {ns["named_style_type"]: ns for ns in named_styles if ns.get("named_style_type")}
    distinct: list[dict[str, Any]] = []
    deviations: list[dict[str, Any]] = []
    seen: set[str] = set()

    body = doc.get("body", {}) or {}
    for index, element in enumerate(body.get("content", []) or []):
        para = element.get("paragraph")
        if not para:
            continue
        ps = para.get("paragraphStyle", {}) or {}
        named_type = ps.get("namedStyleType")
        ps_summary = summarize_paragraph_style(ps)
        # Sample text style from the first textRun in the paragraph.
        ts = _first_text_style(para)
        ts_summary = summarize_text_style(ts)
        key = _stable_key({"named_type": named_type, "ts": ts_summary, "ps": ps_summary})
        if key not in seen:
            seen.add(key)
            distinct.append(
                {
                    "first_paragraph_index": index,
                    "named_style_type": named_type,
                    "sample_text": _para_text(para)[:120],
                    "text_style": ts_summary,
                    "paragraph_style": ps_summary,
                }
            )
        base = by_named_type.get(named_type)
        if base is not None:
            diffs = _diff_against_named(base, ts_summary, ps_summary)
            if diffs:
                deviations.append(
                    {
                        "paragraph_index": index,
                        "named_style_type": named_type,
                        "sample_text": _para_text(para)[:120],
                        "deviations": diffs,
                    }
                )

    return {"distinct_styles": distinct, "deviations_from_named": deviations}


# Page breaks ------------------------------------------------------------

def extract_page_breaks(doc: Doc) -> list[dict[str, Any]]:
    """Locate manual page breaks (paragraph elements with a pageBreak field)."""
    body_content = (doc.get("body", {}) or {}).get("content", []) or []
    paragraphs = [(i, e.get("paragraph")) for i, e in enumerate(body_content) if e.get("paragraph")]
    out: list[dict[str, Any]] = []
    for pos, (index, para) in enumerate(paragraphs):
        for element in para.get("elements", []) or []:
            if "pageBreak" not in element:
                continue
            prev_text = _para_text(paragraphs[pos - 1][1]) if pos > 0 else None
            next_text = _para_text(paragraphs[pos + 1][1]) if pos + 1 < len(paragraphs) else None
            out.append(
                {
                    "paragraph_index": index,
                    "named_style_type_at_break": (
                        (para.get("paragraphStyle") or {}).get("namedStyleType")
                    ),
                    "text_in_paragraph": _para_text(para)[:120],
                    "previous_paragraph_text": (prev_text or "")[:120] or None,
                    "next_paragraph_text": (next_text or "")[:120] or None,
                }
            )
    return out


# Section breaks ---------------------------------------------------------

def extract_section_breaks(doc: Doc) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for index, element in enumerate((doc.get("body", {}) or {}).get("content", []) or []):
        sb = element.get("sectionBreak")
        if not sb:
            continue
        ss = sb.get("sectionStyle", {}) or {}
        columns = ss.get("columnProperties") or []
        out.append(
            {
                "paragraph_index": index,
                "column_count": len(columns) or 1,
                "column_separator_style": ss.get("columnSeparatorStyle"),
                "content_direction": ss.get("contentDirection"),
                "section_type": ss.get("sectionType"),
                "default_header_id": ss.get("defaultHeaderId"),
                "default_footer_id": ss.get("defaultFooterId"),
                "first_page_header_id": ss.get("firstPageHeaderId"),
                "first_page_footer_id": ss.get("firstPageFooterId"),
                "even_page_header_id": ss.get("evenPageHeaderId"),
                "even_page_footer_id": ss.get("evenPageFooterId"),
                "use_first_page_header_footer": ss.get("useFirstPageHeaderFooter"),
                "margins": {
                    "top": _dim(ss.get("marginTop")),
                    "bottom": _dim(ss.get("marginBottom")),
                    "left": _dim(ss.get("marginLeft")),
                    "right": _dim(ss.get("marginRight")),
                    "header": _dim(ss.get("marginHeader")),
                    "footer": _dim(ss.get("marginFooter")),
                },
                "page_number_start": ss.get("pageNumberStart"),
                "columns": [
                    {
                        "width": _dim((c or {}).get("width")),
                        "padding_end": _dim((c or {}).get("paddingEnd")),
                    }
                    for c in columns
                ],
            }
        )
    return out


# Table of contents ------------------------------------------------------

def extract_table_of_contents(doc: Doc) -> dict[str, Any]:
    entries: list[dict[str, Any]] = []
    for index, element in enumerate((doc.get("body", {}) or {}).get("content", []) or []):
        toc = element.get("tableOfContents")
        if not toc:
            continue
        levels_seen: set[str] = set()
        for inner in toc.get("content", []) or []:
            para = inner.get("paragraph")
            if not para:
                continue
            level = (para.get("paragraphStyle") or {}).get("namedStyleType")
            if level:
                levels_seen.add(level)
        entries.append(
            {
                "paragraph_index": index,
                "entry_count": len(toc.get("content", []) or []),
                "heading_levels_present": sorted(levels_seen),
            }
        )
    return {"present": bool(entries), "instances": entries}


# Headers and footers ----------------------------------------------------

def extract_headers_footers(doc: Doc) -> dict[str, Any]:
    return {
        "headers": [_summarize_hf(hid, h) for hid, h in (doc.get("headers") or {}).items()],
        "footers": [_summarize_hf(fid, f) for fid, f in (doc.get("footers") or {}).items()],
    }


def _summarize_hf(obj_id: str, obj: dict[str, Any]) -> dict[str, Any]:
    paragraphs: list[dict[str, Any]] = []
    for element in obj.get("content", []) or []:
        para = element.get("paragraph")
        if not para:
            continue
        paragraphs.append(
            {
                "text": _para_text(para),
                "alignment": (para.get("paragraphStyle") or {}).get("alignment"),
                "named_style_type": (para.get("paragraphStyle") or {}).get("namedStyleType"),
                "text_style": summarize_text_style(_first_text_style(para)),
            }
        )
    return {"id": obj_id, "paragraphs": paragraphs}


# Inline images ----------------------------------------------------------

def extract_inline_images(doc: Doc) -> list[dict[str, Any]]:
    inline_objects = doc.get("inlineObjects") or {}
    out: list[dict[str, Any]] = []
    for index, element in enumerate((doc.get("body", {}) or {}).get("content", []) or []):
        para = element.get("paragraph")
        if not para:
            continue
        for sub in para.get("elements", []) or []:
            ioe = sub.get("inlineObjectElement")
            if not ioe:
                continue
            obj_id = ioe.get("inlineObjectId")
            obj = inline_objects.get(obj_id, {}) or {}
            props = (obj.get("inlineObjectProperties") or {}).get("embeddedObject", {}) or {}
            size = props.get("size") or {}
            out.append(
                {
                    "paragraph_index": index,
                    "inline_object_id": obj_id,
                    "title": props.get("title"),
                    "description": props.get("description"),
                    "anchor_type": "inline",
                    "size": {
                        "width": _dim(size.get("width")),
                        "height": _dim(size.get("height")),
                    },
                    "margins": {
                        "top": _dim(props.get("marginTop")),
                        "bottom": _dim(props.get("marginBottom")),
                        "left": _dim(props.get("marginLeft")),
                        "right": _dim(props.get("marginRight")),
                    },
                    "image_properties": props.get("imageProperties"),
                    "embedded_object_border": props.get("embeddedObjectBorder"),
                }
            )
    return out


# Tables -----------------------------------------------------------------

def extract_tables(doc: Doc) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for index, element in enumerate((doc.get("body", {}) or {}).get("content", []) or []):
        table = element.get("table")
        if not table:
            continue
        rows = table.get("tableRows", []) or []
        table_style = table.get("tableStyle", {}) or {}
        column_widths = [
            _dim((c or {}).get("width", {}))
            for c in table_style.get("tableColumnProperties", []) or []
        ]
        cell_borders: list[dict[str, Any]] = []
        cell_backgrounds: list[dict[str, Any]] = []
        for r_idx, row in enumerate(rows):
            for c_idx, cell in enumerate(row.get("tableCells", []) or []):
                style = cell.get("tableCellStyle", {}) or {}
                borders = {
                    "top": _border(style.get("borderTop")),
                    "bottom": _border(style.get("borderBottom")),
                    "left": _border(style.get("borderLeft")),
                    "right": _border(style.get("borderRight")),
                }
                if any(borders.values()):
                    cell_borders.append({"row": r_idx, "col": c_idx, "borders": borders})
                bg = _color(style.get("backgroundColor"))
                if bg:
                    cell_backgrounds.append({"row": r_idx, "col": c_idx, "color": bg})
        out.append(
            {
                "paragraph_index": index,
                "rows": len(rows),
                "columns": table.get("columns"),
                "column_widths": column_widths,
                "cell_borders": cell_borders,
                "cell_backgrounds": cell_backgrounds,
            }
        )
    return out


# Helpers ----------------------------------------------------------------

def _dim(value: Any) -> dict[str, Any] | None:
    """Return a {'magnitude': float, 'unit': str} pair or None."""
    if not value:
        return None
    if isinstance(value, dict):
        mag = value.get("magnitude")
        unit = value.get("unit")
        if mag is None and unit is None:
            return None
        return {"magnitude": mag, "unit": unit}
    return None


def _magnitude(value: Any) -> float | None:
    if isinstance(value, dict):
        return value.get("magnitude")
    return None


def _color(color_field: Any) -> dict[str, Any] | None:
    """Flatten a Docs OptionalColor / Color into {'rgb': [r,g,b]} or None."""
    if not color_field or not isinstance(color_field, dict):
        return None
    color = color_field.get("color")
    if not color:
        return None
    rgb = (color.get("rgbColor") or {})
    if not rgb:
        return None
    return {
        "red": rgb.get("red", 0.0),
        "green": rgb.get("green", 0.0),
        "blue": rgb.get("blue", 0.0),
    }


def _border(border: Any) -> dict[str, Any] | None:
    if not border or not isinstance(border, dict):
        return None
    width = _magnitude(border.get("width"))
    dash = border.get("dashStyle")
    color = _color(border.get("color"))
    if width is None and dash is None and color is None:
        return None
    return {"width_pt": width, "dash_style": dash, "color": color}


def _orientation(width: dict[str, Any] | None, height: dict[str, Any] | None) -> str | None:
    if not width or not height:
        return None
    w = width.get("magnitude")
    h = height.get("magnitude")
    if w is None or h is None:
        return None
    if w > h:
        return "landscape"
    if h > w:
        return "portrait"
    return "square"


def _first_text_style(para: dict[str, Any]) -> dict[str, Any]:
    for sub in para.get("elements", []) or []:
        tr = sub.get("textRun")
        if tr and (tr.get("content") or "").strip():
            return tr.get("textStyle", {}) or {}
    # Fall back to the first textRun regardless of content.
    for sub in para.get("elements", []) or []:
        tr = sub.get("textRun")
        if tr:
            return tr.get("textStyle", {}) or {}
    return {}


def _para_text(para: dict[str, Any]) -> str:
    parts: list[str] = []
    for sub in para.get("elements", []) or []:
        tr = sub.get("textRun")
        if tr and tr.get("content"):
            parts.append(tr["content"])
    return "".join(parts).strip()


def _stable_key(value: Any) -> str:
    """Build a stable, hashable key for a dict by sorting keys recursively."""
    if isinstance(value, dict):
        return "{" + ",".join(f"{k}={_stable_key(v)}" for k, v in sorted(value.items())) + "}"
    if isinstance(value, list):
        return "[" + ",".join(_stable_key(v) for v in value) + "]"
    return repr(value)


def _diff_against_named(
    base: dict[str, Any], ts: dict[str, Any], ps: dict[str, Any]
) -> dict[str, Any]:
    """Return only the fields that differ from the base named style."""
    out: dict[str, Any] = {}
    base_ts = base.get("text_style") or {}
    base_ps = base.get("paragraph_style") or {}
    ts_diff = {
        k: {"named": base_ts.get(k), "observed": v}
        for k, v in ts.items()
        if v is not None and v != base_ts.get(k)
    }
    ps_diff = {
        k: {"named": base_ps.get(k), "observed": v}
        for k, v in ps.items()
        if v is not None and v != base_ps.get(k)
    }
    if ts_diff:
        out["text_style"] = ts_diff
    if ps_diff:
        out["paragraph_style"] = ps_diff
    return out
