# Capture reference: ShruggieGraph MCP tools

Reference for the two ShruggieGraph MCP tools this skill uses. Read this when you need the exact
input shape, the scopes a token must carry, or how workspace targeting and sensitivity work. The
ShruggieGraph backend is the sole authority for access; everything below describes how to call it
correctly, not how to bypass it.

## `create_note` (write)

Creates a note as a manual-note source in one workspace, with provenance and an audit record.

Inputs:

- `workspace_id` (string, required): the target workspace UUID. See "Workspace id" below.
- `title` (string, required): a short, self-contained title.
- `content` (string, required): the note body; self-contained and understandable out of context.
- `sensitivity` (string, optional): defaults to `normal`. Tokens may only set `normal`; stricter
  values are rejected, so do not put secrets or sensitive personal data in a note.
- `visibility` (string, optional): leave default unless the user asks otherwise.

Requires the token to carry the `mcp:note.create` scope and to be linked to `workspace_id`. A
write to an unlinked workspace, or without the scope, fails closed.

## `search_knowledge` (recall)

Returns permission-filtered, cited context for a query. It calls no language model and generates
no answer; you reason over what it returns and cite the notes you used.

Inputs:

- `query` (string, required): a focused natural-language query.
- `workspace_ids` (array of string, optional): narrow to specific workspaces; omit to search all
  workspaces the token is authorized for.
- `require_citations` (boolean, optional): leave default unless the user asks.

Requires the token to carry `mcp:search` or `mcp:read`. Results are filtered to the caller's
authorized tenant and workspace scope; cross-tenant and cross-workspace content is never returned.

## Workspace id

`create_note` needs an explicit `workspace_id` and there is no client-side way to list a token's
workspaces, so the target workspace must be supplied to you:

- Preferred: the user states their ShruggieGraph workspace id once (in setup or at the start of a
  session), and you reuse it for the session.
- If unknown, ask the user for it once. Do not guess.

The user finds their workspace id in the ShruggieGraph console: it is shown when an organization is
created (the "First workspace id") and in the workspace switcher. See `README.md`.

## Scopes a memory token should carry

For this skill the token minted in the ShruggieGraph console (MCP Tokens page) should carry:

- `mcp:note.create` (to write notes)
- `mcp:search` and `mcp:read` (to recall)

A token's effective authority is the live intersection of its scopes, its linked workspaces, and
the owner's current memberships. If a write or search starts failing, the owner's membership or the
token may have changed; surface the error rather than retrying blindly.
