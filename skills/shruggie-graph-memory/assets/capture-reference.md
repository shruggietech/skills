# Capture reference: ShruggieGraph MCP tools

Reference for the ShruggieGraph MCP tools. This skill uses `create_note` and `search_knowledge`;
the three read tools below (`get_source`, `get_guideline_context`, `get_project_context`) are also
on the connection and documented here for completeness and to match the live server surface. Read
this when you need the exact input shape, the scopes a token must carry, or how memory targeting
and sensitivity work. The ShruggieGraph backend is the sole authority for access; everything below
describes how to call it correctly, not how to bypass it.

## `create_note` (write)

Creates a note as a manual-note source in the connected memory, with provenance and an audit
record.

Inputs:

- `title` (string, required): a short, self-contained title.
- `content` (string, required): the note body; self-contained and understandable out of context.
- `sensitivity` (string, optional): defaults to `normal`. MCP writes may only set `normal`;
  stricter values are rejected, so do not put secrets or sensitive personal data in a note.
- `visibility` (string, optional): leave default unless the user asks otherwise.
- `context` (string, optional): which linked memory to write to, when the connection is linked
  to more than one. Omit it when only one memory is linked (the default targets it).

Requires the connection to carry the `mcp:note.create` scope. A write without the scope, or to a
memory the connection is not linked to, fails closed.

## `search_knowledge` (recall)

Returns permission-filtered, cited context for a query. It calls no language model and generates
no answer; you reason over what it returns and cite the notes you used.

Inputs:

- `query` (string, required): a focused natural-language query.
- `context` (string, optional): the memory to search when the connection is linked to more than
  one. Omit it when only one memory is linked.
- `require_citations` (boolean, optional): leave default unless the user asks.

Requires `mcp:search` or `mcp:read`. Results are filtered to what the connection is authorized
for; content from other people's memories is never returned.

## Read tools (source and context)

These support recall and are available on the connection; the skill reaches for them when a
`search_knowledge` result needs to be followed to its source or when the user asks for guideline or
project context directly.

- `get_source` (read): retrieve a source's metadata and its allowed text or spans, including source
  availability state. Input: `source_id` (string, required). Requires `mcp:source.read`.
- `get_guideline_context` (read): return accepted guideline rules for the connected memory. Inputs:
  `artifact_type` (string, optional), `context` (string, optional). No required input. Requires
  read access.
- `get_project_context` (read): return source-backed context for the connected memory. Inputs:
  `query` (string, required), `context` (string, optional). Requires read access.

## Memory targeting

There is no id to resolve and nothing to ask the user for. The credential itself carries the
targeting: an `sgmcp_` token or an OAuth connection is linked to one or more memories when it is
minted or consented, and every tool defaults to the only linked memory. Only when the user has
linked several memories to one connection does the optional `context` string matter; describe
which memory you mean (for example the user's personal memory versus a shared group memory) and
the backend resolves it. Never invent a `context` value; if a call fails on targeting, ask the
user which memory they intend.

## Scopes a memory connection should carry

For this skill the token minted in the ShruggieGraph console (Connected apps page), or the OAuth
consent granted at connect time, should carry:

- `mcp:note.create` (to write notes)
- `mcp:search` and `mcp:read` (to recall)
- `mcp:source.read` (to follow a result to its source with `get_source`)

These four are the scopes the server advertises. A connection's effective authority is the live intersection of its scopes, its linked memories,
and the owner's current permissions. If a write or search starts failing, the connection may have
been revoked or its permissions changed; surface the error rather than retrying blindly.
