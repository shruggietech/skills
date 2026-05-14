# gdocs-style-extract

Extract canonical styling information from Google Docs via the Docs REST API. Emits machine-readable JSON plus human-readable Markdown summaries.

This tool exists because Google Docs "Download as docx" exports distort styling details (font weights, spacing, indentation). The Docs REST API JSON is the only fidelity-preserving source. The output is intended as auxiliary input for authoring `SKILL.md` files that teach AI agents to produce `.docx` files matching reference Google Docs styling.

## Status

Auxiliary tooling, scope-proportional. Not a skill (no `SKILL.md`). Not a platform.

## Requirements

- Python 3.11 or newer
- [uv](https://docs.astral.sh/uv/) for project management
- A Google Cloud Platform project with the Google Docs API enabled
- OAuth 2.0 client credentials of type "Desktop application"

## Install

From the tool directory:

```bash
uv sync
```

This creates `.venv/` and installs dependencies pinned by `uv.lock`. You can then invoke the CLI via `uv run`:

```bash
uv run gdocs-style-extract --help
```

If you prefer activating the venv directly:

```bash
# Windows (PowerShell)
.venv\Scripts\Activate.ps1

# macOS / Linux
source .venv/bin/activate

gdocs-style-extract --help
```

## Set up Google credentials

1. Open the [Google Cloud Console](https://console.cloud.google.com/) and create or select a project.
2. Enable the **Google Docs API** for the project (APIs and Services > Library).
3. Configure the OAuth consent screen if you have not already (Internal or External, depending on your org).
4. Create OAuth client credentials of type **Desktop application** (APIs and Services > Credentials > Create credentials > OAuth client ID).
5. Download the JSON. Save it as `credentials.json` in the directory from which you will run the tool, or pass its path via `--credentials`.

The first run opens a browser for OAuth consent. A refresh token is then cached at:

- Windows: `%APPDATA%\gdocs-style-extract\token.json`
- Linux and macOS: `$XDG_CONFIG_HOME/gdocs-style-extract/token.json` (falls back to `~/.config/gdocs-style-extract/token.json`)

To force a fresh consent (for example, after revoking access in your Google account), delete `token.json` from the cache location above and re-run.

The only scope requested is `https://www.googleapis.com/auth/documents.readonly`. The tool does not request Drive access.

## Usage

```
gdocs-style-extract <doc_id> [<doc_id>...]
    [--out <path>]
    [--format json|markdown|both]
    [--credentials <path>]
```

The `doc_id` is the identifier from the document URL: `https://docs.google.com/document/d/<DOC_ID>/edit`.

Defaults:

- `--out ./gdocs-extract-out/` (created if missing)
- `--format both`
- `--credentials ./credentials.json`

### Single document

```bash
uv run gdocs-style-extract 1AbCdEf_replace_with_real_id_GhIjKl
```

Outputs:

- `gdocs-extract-out/<doc_id>.json`
- `gdocs-extract-out/<doc_id>.md`

### Multiple documents (with comparison)

```bash
uv run gdocs-style-extract \
    1AbCdEf_replace_with_real_id_GhIjKl \
    2MnOpQr_replace_with_real_id_StUvWx \
    --out style-samples
```

Adds `style-samples/comparison.md`, which flags which style attributes are consistent across all samples versus which vary across the sample set.

## Output format reference

### Per-document JSON (`<doc_id>.json`)

Top-level keys (each one mirrors a category from the extraction brief):

| Key | Contents |
|-----|----------|
| `document` | Title, document ID, page size, orientation, margins, header and footer references |
| `named_styles` | Every entry in `namedStyles` with both a summarized and raw view of text and paragraph styling |
| `body_observations` | Distinct `(textStyle, paragraphStyle)` fingerprints seen in the body, plus a deviations list flagging where observed styling diverges from the corresponding named style |
| `page_breaks` | Manual page breaks with surrounding paragraph context |
| `section_breaks` | Section properties: column count, margins, header and footer references |
| `table_of_contents` | Presence flag and per-instance heading levels |
| `headers_footers` | Per-header and per-footer paragraph text, alignment, and font styling |
| `inline_images` | Paragraph index, dimensions, anchor type, embedded object properties |
| `tables` | Row and column counts, per-cell borders, per-cell background colors |

Detail is preserved at a level sufficient to regenerate the styling without re-fetching the document.

### Per-document Markdown (`<doc_id>.md`)

Skill-author readable. Tables for named styles and observed deviations. Headings per extraction category. No HTML.

### Comparison Markdown (`comparison.md`)

Per-attribute consistency markers:

- `[x]` consistent across all samples
- `[~]` partial (some agree, some absent)
- `[ ]` varies across samples

Sections cover document-level fields, named-style attributes (font, size, weight, alignment, spacing), and a structural elements summary (counts of headers, footers, page breaks, sections, tables, inline images).

## Scope rationale

Drive folder traversal, `.docx` generation, round-trip validation, and a web UI are out of scope for v1. This tool extracts and reports; downstream consumers (humans authoring a `SKILL.md`, or other tooling) use the output.

## Library use

The package is importable, not just runnable. Useful entry points:

```python
from gdocs_style_extract.auth import get_credentials
from gdocs_style_extract.fetch import fetch_document
from gdocs_style_extract.extract import build_inventory

creds = get_credentials(Path("credentials.json"))
raw = fetch_document(creds, "DOC_ID_HERE")
inventory = build_inventory(raw)
```

## Troubleshooting

- **`OAuth client secrets file not found`**: download `credentials.json` from your GCP project (Desktop OAuth client) and place it next to your invocation, or pass `--credentials <path>`.
- **`Authentication failed (HTTP 401)`**: the cached refresh token is invalid. Delete `token.json` from the cache directory listed above and re-run.
- **`Permission denied (HTTP 403)`**: confirm the authenticated Google account has read access to the document, and that the Docs API is enabled on your GCP project.
- **`Document not found (HTTP 404)`**: verify the document ID. It is the segment between `/d/` and `/edit` in the document URL.

## License

Apache 2.0. See `LICENSE`.
