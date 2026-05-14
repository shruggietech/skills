"""Inventory -> JSON file."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def write_json(inventory: dict[str, Any], out_path: Path) -> None:
    """Write the inventory to out_path as UTF-8 JSON with two-space indent."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(inventory, indent=2, ensure_ascii=False, sort_keys=False)
    # Ensure single trailing newline, LF endings, no BOM.
    out_path.write_text(text + "\n", encoding="utf-8", newline="\n")
