#!/usr/bin/env python3
"""embed-fonts.py: post-generation font embedding for shruggie-docs.

Takes a .docx produced by document-template.js and embeds the six bundled TTFs
into the file. docx-js does not expose font embedding directly; this script
unpacks the .docx, drops the TTFs into word/fonts/, patches word/fontTable.xml
to reference each embed, sets the embedTrueTypeFonts flag in word/settings.xml,
and repacks.

Usage:
    python embed-fonts.py <path-to-docx>

The script is idempotent: running it twice on the same file will not duplicate
font entries.

Runtime requirements:
    - Python 3.9+
    - lxml (for OOXML manipulation)
    - The bundled assets/fonts/ directory adjacent to this script

The script does not require the public docx skill at runtime; it implements
unpack/pack inline using the Python standard library zipfile module. The
public skill's scripts/office/unpack.py and pack.py produce equivalent output
and may be substituted by callers that prefer the public toolchain.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

try:
    from lxml import etree
except ImportError as exc:
    raise SystemExit(
        "lxml is required. Install it in the skill execution environment "
        "with `pip install lxml`."
    ) from exc


SCRIPT_DIR = Path(__file__).resolve().parent
FONTS_DIR = SCRIPT_DIR / "fonts"

NS_W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
NS_R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
NS_REL = "http://schemas.openxmlformats.org/package/2006/relationships"
NSMAP_W = {"w": NS_W, "r": NS_R}

CONTENT_TYPE_FONT = "application/vnd.openxmlformats-officedocument.obfuscatedFont"

FONT_BINDINGS = [
    {
        "file": "SpaceGrotesk-Bold.ttf",
        "family": "Space Grotesk",
        "slot": "embedBold",
    },
    {
        "file": "SpaceGrotesk-Medium.ttf",
        "family": "Space Grotesk",
        "slot": "embedRegular",
    },
    {
        "file": "Geist-Regular.ttf",
        "family": "Geist",
        "slot": "embedRegular",
    },
    {
        "file": "Geist-Medium.ttf",
        "family": "Geist",
        "slot": "embedBold",
    },
    {
        "file": "Geist-Italic.ttf",
        "family": "Geist",
        "slot": "embedItalic",
    },
    {
        "file": "GeistMono-Regular.ttf",
        "family": "Geist Mono",
        "slot": "embedRegular",
    },
]


def unpack_docx(docx_path: Path, dest: Path) -> None:
    with zipfile.ZipFile(docx_path, "r") as zf:
        zf.extractall(dest)


def pack_docx(src: Path, docx_path: Path) -> None:
    if docx_path.exists():
        docx_path.unlink()
    with zipfile.ZipFile(docx_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, _dirs, files in os.walk(src):
            for f in files:
                full = Path(root) / f
                rel = full.relative_to(src)
                zf.write(full, arcname=str(rel).replace(os.sep, "/"))


def ensure_font_payload(extracted: Path) -> None:
    fonts_dir = extracted / "word" / "fonts"
    fonts_dir.mkdir(parents=True, exist_ok=True)
    for binding in FONT_BINDINGS:
        src = FONTS_DIR / binding["file"]
        if not src.is_file():
            raise SystemExit(f"Missing bundled font: {src}")
        dst = fonts_dir / binding["file"]
        shutil.copyfile(src, dst)


def update_content_types(extracted: Path) -> None:
    ct_path = extracted / "[Content_Types].xml"
    tree = etree.parse(str(ct_path))
    root = tree.getroot()
    existing_defaults = {
        d.get("Extension", "").lower(): d
        for d in root.findall("{http://schemas.openxmlformats.org/package/2006/content-types}Default")
    }
    if "ttf" not in existing_defaults:
        default_el = etree.SubElement(
            root,
            "{http://schemas.openxmlformats.org/package/2006/content-types}Default",
        )
        default_el.set("Extension", "ttf")
        default_el.set("ContentType", "application/x-font-ttf")
    tree.write(str(ct_path), xml_declaration=True, encoding="UTF-8", standalone=True)


def update_document_rels(extracted: Path) -> dict[str, str]:
    """Add a relationship per font binding to word/_rels/document.xml.rels and
    return a mapping from font filename to relationship Id."""
    rels_path = extracted / "word" / "_rels" / "document.xml.rels"
    rels_path.parent.mkdir(parents=True, exist_ok=True)
    rels_ns = "http://schemas.openxmlformats.org/package/2006/relationships"
    if rels_path.exists():
        tree = etree.parse(str(rels_path))
        root = tree.getroot()
    else:
        root = etree.Element(f"{{{rels_ns}}}Relationships")
        tree = etree.ElementTree(root)

    existing_ids = set()
    existing_targets = {}
    for rel in root.findall(f"{{{rels_ns}}}Relationship"):
        existing_ids.add(rel.get("Id"))
        existing_targets[rel.get("Target")] = rel.get("Id")

    def next_id() -> str:
        n = 1
        while f"rIdFont{n}" in existing_ids:
            n += 1
        new = f"rIdFont{n}"
        existing_ids.add(new)
        return new

    mapping: dict[str, str] = {}
    font_rel_type = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/font"
    for binding in FONT_BINDINGS:
        target = f"fonts/{binding['file']}"
        if target in existing_targets:
            mapping[binding["file"]] = existing_targets[target]
            continue
        rid = next_id()
        rel_el = etree.SubElement(root, f"{{{rels_ns}}}Relationship")
        rel_el.set("Id", rid)
        rel_el.set("Type", font_rel_type)
        rel_el.set("Target", target)
        mapping[binding["file"]] = rid

    tree.write(str(rels_path), xml_declaration=True, encoding="UTF-8", standalone=True)
    return mapping


def update_font_table(extracted: Path, font_to_rid: dict[str, str]) -> None:
    ft_path = extracted / "word" / "fontTable.xml"
    w_ns = NS_W
    r_ns = NS_R
    nsmap = {"w": w_ns, "r": r_ns}
    if ft_path.exists():
        tree = etree.parse(str(ft_path))
        root = tree.getroot()
    else:
        root = etree.Element(f"{{{w_ns}}}fonts", nsmap=nsmap)
        tree = etree.ElementTree(root)

    fonts_by_name: dict[str, etree._Element] = {}
    for f in root.findall(f"{{{w_ns}}}font"):
        fonts_by_name[f.get(f"{{{w_ns}}}name") or ""] = f

    for binding in FONT_BINDINGS:
        family = binding["family"]
        font_el = fonts_by_name.get(family)
        if font_el is None:
            font_el = etree.SubElement(root, f"{{{w_ns}}}font")
            font_el.set(f"{{{w_ns}}}name", family)
            fonts_by_name[family] = font_el

        slot = binding["slot"]
        existing = font_el.find(f"{{{w_ns}}}{slot}")
        if existing is not None:
            font_el.remove(existing)
        embed_el = etree.SubElement(font_el, f"{{{w_ns}}}{slot}")
        embed_el.set(f"{{{r_ns}}}id", font_to_rid[binding["file"]])
        embed_el.set(f"{{{w_ns}}}fontKey", "{00000000-0000-0000-0000-000000000000}")

    tree.write(str(ft_path), xml_declaration=True, encoding="UTF-8", standalone=True)


def update_settings(extracted: Path) -> None:
    s_path = extracted / "word" / "settings.xml"
    w_ns = NS_W
    if s_path.exists():
        tree = etree.parse(str(s_path))
        root = tree.getroot()
    else:
        nsmap = {"w": w_ns}
        root = etree.Element(f"{{{w_ns}}}settings", nsmap=nsmap)
        tree = etree.ElementTree(root)

    embed_flag = root.find(f"{{{w_ns}}}embedTrueTypeFonts")
    if embed_flag is None:
        embed_flag = etree.SubElement(root, f"{{{w_ns}}}embedTrueTypeFonts")
        embed_flag.set(f"{{{w_ns}}}val", "true")

    save_subset = root.find(f"{{{w_ns}}}saveSubsetFonts")
    if save_subset is None:
        save_subset = etree.SubElement(root, f"{{{w_ns}}}saveSubsetFonts")
        save_subset.set(f"{{{w_ns}}}val", "false")

    tree.write(str(s_path), xml_declaration=True, encoding="UTF-8", standalone=True)


def embed(docx_path: Path) -> None:
    if not docx_path.is_file():
        raise SystemExit(f"Not a file: {docx_path}")
    with tempfile.TemporaryDirectory(prefix="shruggie-docs-embed-") as tmp:
        tmpdir = Path(tmp)
        unpack_docx(docx_path, tmpdir)
        ensure_font_payload(tmpdir)
        update_content_types(tmpdir)
        rid_map = update_document_rels(tmpdir)
        update_font_table(tmpdir, rid_map)
        update_settings(tmpdir)
        pack_docx(tmpdir, docx_path)


def verify(docx_path: Path) -> None:
    """Sanity check: confirm the six TTFs are present in the packed archive
    and that fontTable.xml references each one. Raises SystemExit on failure."""
    expected = {b["file"] for b in FONT_BINDINGS}
    with zipfile.ZipFile(docx_path, "r") as zf:
        names = set(zf.namelist())
        for f in expected:
            arc = f"word/fonts/{f}"
            if arc not in names:
                raise SystemExit(f"Verification failed: {arc} not in archive.")
        with zf.open("word/fontTable.xml") as fh:
            data = fh.read()
    for binding in FONT_BINDINGS:
        if binding["family"].encode("utf-8") not in data:
            raise SystemExit(f"Verification failed: {binding['family']} not referenced in fontTable.xml.")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Embed bundled fonts into a .docx")
    parser.add_argument("docx", type=Path, help="Path to the .docx file to modify in place")
    parser.add_argument("--verify-only", action="store_true", help="Skip embedding; only verify an already-embedded file")
    args = parser.parse_args(argv)

    if not args.verify_only:
        embed(args.docx)
    verify(args.docx)
    print(f"OK: {args.docx}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
