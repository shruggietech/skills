"""CLI entry point for gdocs-style-extract."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from gdocs_style_extract import __version__
from gdocs_style_extract.auth import AuthError, get_credentials
from gdocs_style_extract.compare import write_comparison
from gdocs_style_extract.emit_json import write_json
from gdocs_style_extract.emit_markdown import write_markdown
from gdocs_style_extract.extract import build_inventory
from gdocs_style_extract.fetch import FetchError, fetch_document


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="gdocs-style-extract",
        description=(
            "Extract canonical styling from Google Docs via the Docs REST API. "
            "Emits per-document JSON and Markdown summaries, plus a comparison "
            "report when multiple documents are supplied."
        ),
    )
    parser.add_argument(
        "doc_ids",
        nargs="+",
        metavar="doc_id",
        help="Google Docs document ID. Pass multiple to also emit comparison.md.",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("gdocs-extract-out"),
        help="Output directory. Created if missing. Default: ./gdocs-extract-out/",
    )
    parser.add_argument(
        "--format",
        choices=("json", "markdown", "both"),
        default="both",
        help="Which output formats to emit. Default: both.",
    )
    parser.add_argument(
        "--credentials",
        type=Path,
        default=Path("credentials.json"),
        help=(
            "Path to OAuth client secrets (Desktop application) JSON. "
            "Default: ./credentials.json"
        ),
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"gdocs-style-extract {__version__}",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        creds = get_credentials(args.credentials)
    except AuthError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    out_dir: Path = args.out
    out_dir.mkdir(parents=True, exist_ok=True)

    inventories: list[tuple[str, dict]] = []
    failures: list[tuple[str, str]] = []

    for doc_id in args.doc_ids:
        try:
            print(f"Fetching {doc_id}...", file=sys.stderr)
            raw = fetch_document(creds, doc_id)
        except FetchError as exc:
            print(f"error: {exc}", file=sys.stderr)
            failures.append((doc_id, str(exc)))
            continue

        inventory = build_inventory(raw)
        inventories.append((doc_id, inventory))

        if args.format in ("json", "both"):
            target = out_dir / f"{doc_id}.json"
            write_json(inventory, target)
            print(f"wrote {target}", file=sys.stderr)
        if args.format in ("markdown", "both"):
            target = out_dir / f"{doc_id}.md"
            write_markdown(inventory, target)
            print(f"wrote {target}", file=sys.stderr)

    if len(inventories) >= 2:
        target = out_dir / "comparison.md"
        write_comparison(inventories, target)
        print(f"wrote {target}", file=sys.stderr)

    if failures:
        print(
            f"\n{len(failures)} of {len(args.doc_ids)} document(s) failed.",
            file=sys.stderr,
        )
        return 1
    return 0
