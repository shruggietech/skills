"""Google Docs API client wrapper with friendly error mapping."""

from __future__ import annotations

from typing import Any

from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from google.oauth2.credentials import Credentials


class FetchError(Exception):
    """Raised when a Docs API call cannot be completed."""


def fetch_document(creds: Credentials, doc_id: str) -> dict[str, Any]:
    """Fetch a single document by ID and return the raw API JSON.

    Maps Google API errors to FetchError with actionable messages.
    """
    try:
        service = build("docs", "v1", credentials=creds, cache_discovery=False)
        return service.documents().get(documentId=doc_id).execute()
    except HttpError as exc:
        status = getattr(exc.resp, "status", None)
        body = _safe_body(exc)
        if status == 404:
            raise FetchError(
                f"Document {doc_id!r} not found (HTTP 404). Verify the ID is "
                "correct and that you have access. API response: "
                f"{body}"
            ) from exc
        if status == 403:
            raise FetchError(
                f"Permission denied fetching {doc_id!r} (HTTP 403). The "
                "authenticated account may lack read access, or the Docs API "
                f"may not be enabled on the GCP project. API response: {body}"
            ) from exc
        if status == 401:
            raise FetchError(
                "Authentication failed (HTTP 401). The cached token is likely "
                "expired or revoked. Delete the token cache and re-run. "
                f"API response: {body}"
            ) from exc
        raise FetchError(
            f"Docs API request failed (HTTP {status}). Body: {body}"
        ) from exc
    except Exception as exc:
        raise FetchError(f"Unexpected error fetching {doc_id!r}: {exc}") from exc


def _safe_body(exc: HttpError) -> str:
    try:
        return exc.content.decode("utf-8", errors="replace")
    except Exception:
        return str(exc)
