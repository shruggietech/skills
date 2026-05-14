"""Platform-appropriate paths for the OAuth token cache."""

from __future__ import annotations

import os
import sys
from pathlib import Path

APP_DIRNAME = "gdocs-style-extract"


def token_cache_dir() -> Path:
    """Return the directory used to cache the OAuth token.

    Windows: %APPDATA%\\gdocs-style-extract\\
    Other:   $XDG_CONFIG_HOME/gdocs-style-extract/ (falls back to ~/.config/...)
    """
    if sys.platform == "win32":
        base = os.environ.get("APPDATA")
        if base:
            return Path(base) / APP_DIRNAME
        return Path.home() / "AppData" / "Roaming" / APP_DIRNAME

    xdg = os.environ.get("XDG_CONFIG_HOME")
    if xdg:
        return Path(xdg) / APP_DIRNAME
    return Path.home() / ".config" / APP_DIRNAME


def token_path() -> Path:
    """Return the full path to token.json, creating the parent dir as needed."""
    d = token_cache_dir()
    d.mkdir(parents=True, exist_ok=True)
    return d / "token.json"
