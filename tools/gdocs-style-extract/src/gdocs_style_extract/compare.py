"""Cross-document comparison report.

Given multiple inventories, identify which style attributes are consistent
across all samples vs which vary. Goal: separate house style from per-document
accidents.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Iterable

CONSISTENT = "consistent"
PARTIAL = "partial"
VARIES = "varies"


def write_comparison(
    inventories: list[tuple[str, dict[str, Any]]], out_path: Path
) -> None:
    """Write comparison.md across the supplied (label, inventory) pairs."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        render_comparison(inventories), encoding="utf-8", newline="\n"
    )


def render_comparison(inventories: list[tuple[str, dict[str, Any]]]) -> str:
    parts: list[str] = []
    parts.append("# Style comparison across documents")
    parts.append("")
    parts.append(f"Documents compared: {len(inventories)}")
    parts.append("")
    parts.append("| Document ID | Title |")
    parts.append("|-------------|-------|")
    for label, inv in inventories:
        title = (inv.get("document") or {}).get("title") or "(untitled)"
        parts.append(f"| `{label}` | {title} |")
    parts.append("")

    parts.append("Legend: [x] consistent across all, [~] partial (some agree), "
                 "[ ] varies across all.")
    parts.append("")

    # Document-level fields ------------------------------------------------
    parts.append("## Document-level")
    parts.append("")
    parts.extend(
        _section(
            inventories,
            keys=[
                ("orientation", lambda inv: (inv.get("document") or {}).get("orientation")),
                ("page width",
                 lambda inv: _ser((inv.get("document") or {}).get("page_size", {}).get("width"))),
                ("page height",
                 lambda inv: _ser((inv.get("document") or {}).get("page_size", {}).get("height"))),
                ("margin top",
                 lambda inv: _ser((inv.get("document") or {}).get("margins", {}).get("top"))),
                ("margin bottom",
                 lambda inv: _ser((inv.get("document") or {}).get("margins", {}).get("bottom"))),
                ("margin left",
                 lambda inv: _ser((inv.get("document") or {}).get("margins", {}).get("left"))),
                ("margin right",
                 lambda inv: _ser((inv.get("document") or {}).get("margins", {}).get("right"))),
            ],
        )
    )
    parts.append("")

    # Named-style comparison ---------------------------------------------
    parts.append("## Named styles")
    parts.append("")
    parts.extend(_named_style_section(inventories))
    parts.append("")

    # Structural elements --------------------------------------------------
    parts.append("## Structural elements")
    parts.append("")
    parts.extend(
        _section(
            inventories,
            keys=[
                ("table of contents present",
                 lambda inv: (inv.get("table_of_contents") or {}).get("present")),
                ("manual page break count",
                 lambda inv: len(inv.get("page_breaks") or [])),
                ("section break count",
                 lambda inv: len(inv.get("section_breaks") or [])),
                ("inline image count",
                 lambda inv: len(inv.get("inline_images") or [])),
                ("table count",
                 lambda inv: len(inv.get("tables") or [])),
                ("header count",
                 lambda inv: len((inv.get("headers_footers") or {}).get("headers") or [])),
                ("footer count",
                 lambda inv: len((inv.get("headers_footers") or {}).get("footers") or [])),
            ],
        )
    )
    parts.append("")

    return "\n".join(parts)


def _section(
    inventories: list[tuple[str, dict[str, Any]]],
    keys: list[tuple[str, Any]],
) -> list[str]:
    header = "| Attribute | Status | " + " | ".join(label for label, _ in inventories) + " |"
    sep = "|-----------|--------|" + "|".join(["---"] * len(inventories)) + "|"
    rows = [header, sep]
    for label, getter in keys:
        values = [getter(inv) for _, inv in inventories]
        status = _status(values)
        marker = {CONSISTENT: "[x]", PARTIAL: "[~]", VARIES: "[ ]"}[status]
        rendered = " | ".join(_render(v) for v in values)
        rows.append(f"| {label} | {marker} | {rendered} |")
    return rows


def _named_style_section(
    inventories: list[tuple[str, dict[str, Any]]],
) -> list[str]:
    style_types: list[str] = []
    seen: set[str] = set()
    for _, inv in inventories:
        for entry in inv.get("named_styles") or []:
            nst = entry.get("named_style_type")
            if nst and nst not in seen:
                seen.add(nst)
                style_types.append(nst)
    if not style_types:
        return ["No named styles found in any document."]

    rows: list[str] = []
    for style_type in style_types:
        rows.append(f"### {style_type}")
        rows.append("")
        rows.extend(
            _section(
                inventories,
                keys=[
                    (
                        "font family",
                        lambda inv, st=style_type: _lookup_named(inv, st, ("text_style", "font_family")),
                    ),
                    (
                        "font size (pt)",
                        lambda inv, st=style_type: _lookup_named(inv, st, ("text_style", "font_size_pt")),
                    ),
                    (
                        "font weight",
                        lambda inv, st=style_type: _lookup_named(inv, st, ("text_style", "font_weight")),
                    ),
                    (
                        "italic",
                        lambda inv, st=style_type: _lookup_named(inv, st, ("text_style", "italic")),
                    ),
                    (
                        "underline",
                        lambda inv, st=style_type: _lookup_named(inv, st, ("text_style", "underline")),
                    ),
                    (
                        "foreground color",
                        lambda inv, st=style_type: _ser(
                            _lookup_named(inv, st, ("text_style", "foreground_color"))
                        ),
                    ),
                    (
                        "alignment",
                        lambda inv, st=style_type: _lookup_named(inv, st, ("paragraph_style", "alignment")),
                    ),
                    (
                        "line spacing",
                        lambda inv, st=style_type: _lookup_named(inv, st, ("paragraph_style", "line_spacing")),
                    ),
                    (
                        "space above (pt)",
                        lambda inv, st=style_type: _lookup_named(inv, st, ("paragraph_style", "space_above_pt")),
                    ),
                    (
                        "space below (pt)",
                        lambda inv, st=style_type: _lookup_named(inv, st, ("paragraph_style", "space_below_pt")),
                    ),
                ],
            )
        )
        rows.append("")
    return rows


def _lookup_named(inv: dict[str, Any], style_type: str, path: tuple[str, str]) -> Any:
    for entry in inv.get("named_styles") or []:
        if entry.get("named_style_type") == style_type:
            section = entry.get(path[0]) or {}
            return section.get(path[1])
    return None


def _status(values: Iterable[Any]) -> str:
    values_list = list(values)
    non_null = [v for v in values_list if v is not None]
    if not non_null:
        return CONSISTENT  # all absent counts as consistent
    if len(non_null) < len(values_list):
        return PARTIAL
    first = non_null[0]
    if all(v == first for v in non_null):
        return CONSISTENT
    return VARIES


def _render(value: Any) -> str:
    if value is None:
        return "(none)"
    if isinstance(value, bool):
        return "yes" if value else "no"
    return str(value)


def _ser(value: Any) -> Any:
    """Serialize dicts to a stable string so equality comparison works."""
    if isinstance(value, dict):
        return ",".join(f"{k}={value[k]}" for k in sorted(value))
    return value
