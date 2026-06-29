# shruggie-graph-memory

A companion skill that makes Claude capture durable knowledge from ordinary conversation into
[ShruggieGraph](https://graph.shruggie.tech), a permission-scoped, source-backed AI memory you own
and carry across AI providers, and recall it later. When the ShruggieGraph MCP tools are connected,
Claude proactively saves lasting facts (decisions, preferences, commitments, stable details) as
notes and searches them back when you ask what you know.

This README is human-facing setup. The skill behavior itself lives in `SKILL.md`, and the tool
reference in `assets/capture-reference.md`.

## What it does

- Writes durable facts to a ShruggieGraph workspace with the `create_note` MCP tool. Each note
  becomes a cited source with an audit trail; the backend enforces all access.
- Recalls them with `search_knowledge`, which returns permission-filtered, cited context.
- Stays quiet on trivia, transient chatter, and unrequested secrets.

The skill makes no permission decisions. ShruggieGraph is the sole authority for what a token may
read or write.

## Prerequisites

- A ShruggieGraph account and a workspace to write into.
- The ShruggieGraph MCP tools connected to your Claude client (see "Connect Claude Desktop").

## One-time setup

### 1. Mint a token (ShruggieGraph console)

1. Sign in to the ShruggieGraph console.
2. If you do not yet have a shared/team space, create an organization (this also creates a first
   workspace and makes you Owner). Note the **workspace id** shown.
3. Switch the scope selector to that organization's tenant.
4. Open **MCP Tokens** and create a token:
   - Client name: `Claude Desktop` (or your client).
   - Scopes: `mcp:note.create`, `mcp:search`, `mcp:read`.
   - Workspace links: tick the workspace you want memory written to.
5. Copy the `sgmcp_...` secret (shown once).

### 2. Connect Claude Desktop

ShruggieGraph's MCP endpoint is request/response JSON-RPC, so Claude Desktop connects through the
bundled `mcp-stdio` adapter from the ShruggieGraph CLI (which speaks HTTPS). In
`claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "shruggie-graph": {
      "command": "/path/to/shruggiegraph-cli",
      "args": ["mcp-stdio", "--endpoint", "https://graph.shruggie.tech/api/mcp"],
      "env": { "SHRUGGIE_MCP_TOKEN": "sgmcp_..." }
    }
  }
}
```

For a more secure setup that keeps the secret out of the config file, mint the token with the CLI
flag `--store-account <name>` (which stores it in the OS keyring), then replace the `env` block
with `"--account", "<name>"` in `args`.

### 3. Tell the skill your workspace id

`create_note` needs an explicit workspace id, and there is no way to list a token's workspaces from
the client. So state your workspace id to Claude once per session (for example, "my ShruggieGraph
workspace is <uuid>"), and the skill reuses it. If you do not, the skill asks once before writing.

## Install

See the repository [README](../../README.md) for install options (per-skill zip upload for Claude
Desktop, or symlink for Claude Code).

## A note on automatic invocation

This skill sets `disable-model-invocation: false` on purpose. Automatic capture during ordinary
conversation is the whole point, so Claude must be able to pick the skill up by context rather than
waiting for an explicit `/shruggie-graph-memory` command. The actual write is performed by the
`create_note` MCP tool, which you enabled by connecting the connector and minting a
`mcp:note.create` token, and which the ShruggieGraph backend independently authorizes. This is a
deliberate departure from the usual "side-effecting skills are explicit-invocation only" guideline,
recorded here so it is not mistaken for an oversight.
