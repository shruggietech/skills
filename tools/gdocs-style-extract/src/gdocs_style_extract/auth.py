"""OAuth 2.0 installed-application flow with a local token cache."""

from __future__ import annotations

from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow

from gdocs_style_extract.paths import token_path

SCOPES = ["https://www.googleapis.com/auth/documents.readonly"]


class AuthError(Exception):
    """Raised when OAuth credentials cannot be obtained or refreshed."""


def get_credentials(credentials_path: Path) -> Credentials:
    """Return valid OAuth credentials, prompting the user if needed.

    Loads cached credentials from the platform token cache. Refreshes them if
    expired. Falls back to an interactive installed-app flow using the supplied
    client secrets at credentials_path.
    """
    cache = token_path()
    creds: Credentials | None = None
    if cache.exists():
        try:
            creds = Credentials.from_authorized_user_file(str(cache), SCOPES)
        except (ValueError, OSError) as exc:
            raise AuthError(
                f"Cached token at {cache} could not be loaded: {exc}. "
                "Delete it and re-run to start a fresh OAuth flow."
            ) from exc

    if creds and creds.valid:
        return creds

    if creds and creds.expired and creds.refresh_token:
        try:
            creds.refresh(Request())
        except Exception as exc:
            raise AuthError(
                f"Refreshing the cached token failed ({exc}). "
                f"Delete {cache} and re-run to start a fresh OAuth flow."
            ) from exc
        _save(creds, cache)
        return creds

    if not credentials_path.exists():
        raise AuthError(
            f"OAuth client secrets file not found at {credentials_path}. "
            "Download one from your GCP project (Desktop application) and "
            "pass its path via --credentials, or place it at "
            "./credentials.json. See the README for setup instructions."
        )

    flow = InstalledAppFlow.from_client_secrets_file(str(credentials_path), SCOPES)
    creds = flow.run_local_server(port=0)
    _save(creds, cache)
    return creds


def _save(creds: Credentials, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(creds.to_json(), encoding="utf-8")
