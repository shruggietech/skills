# shruggie-graph-memory

A companion skill that makes Claude capture durable knowledge from ordinary conversation into
[ShruggieGraph](https://graph.shruggie.tech), a permission-scoped, source-backed AI memory you own
and carry across AI providers, and recall it later. When the ShruggieGraph MCP tools are connected,
Claude proactively saves lasting facts (decisions, preferences, commitments, stable details) as
notes and searches them back when you ask what you know.

This README is human-facing setup. The skill behavior itself lives in `SKILL.md`, and the tool
reference in `assets/capture-reference.md`.

## What it does

- Writes durable facts to your ShruggieGraph memory with the `create_note` MCP tool. Each note
  becomes a cited source with an audit trail; the backend enforces all access.
- Recalls them with `search_knowledge`, which returns permission-filtered, cited context.
- Stays quiet on trivia, transient chatter, and unrequested secrets.

The skill makes no permission decisions. ShruggieGraph is the sole authority for what a
connection may read or write, and the connection itself determines which memory notes land in;
there is nothing to configure in the skill.

## Prerequisites

- A ShruggieGraph account.
- The ShruggieGraph MCP tools connected to your Claude client (either path below). The console's
  **Connect** guide (linked from the Connected apps page) documents both paths end to end.

## Connect claude.ai (web)

Add a custom connector in claude.ai with the URL `https://graph.shruggie.tech/mcp`. claude.ai
discovers the ShruggieGraph OAuth server, registers, and sends you to the console consent page,
where you sign in, pick which memory to link, and approve the scopes. Disconnecting in claude.ai
revokes the connection server-side; you can also sever any connection yourself on the console's
**Connected apps** page.

## Connect Claude Desktop

ShruggieGraph's MCP endpoint is request/response JSON-RPC, so Claude Desktop connects through the
bundled `mcp-stdio` adapter from the ShruggieGraph CLI (which speaks HTTPS).

1. In the console, open **Connected apps** (in the account menu) and create a token:
   - Client name: `Claude Desktop` (or your client).
   - Scopes: `mcp:note.create`, `mcp:search`, `mcp:read`.
   - Memory: pick the memory this connection writes to and reads from.
2. Copy the `sgmcp_...` secret (shown once).
3. In `claude_desktop_config.json`:

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

## Where notes land

The connection carries the targeting: notes are written to the memory you linked at consent or
token-mint time, and searches read from it. If you link several memories to one connection, the
skill passes an optional `context` describing which one you mean. There is no workspace id or any
other identifier to configure.

## Install

See the repository [README](../../README.md) for install options (per-skill zip upload for Claude
Desktop, or symlink for Claude Code).

## A note on automatic invocation

This skill sets `disable-model-invocation: false` on purpose. Automatic capture during ordinary
conversation is the whole point, so Claude must be able to pick the skill up by context rather than
waiting for an explicit `/shruggie-graph-memory` command. The actual write is performed by the
`create_note` MCP tool, which you enabled by connecting the connector with the `mcp:note.create`
scope, and which the ShruggieGraph backend independently authorizes. This is a deliberate
departure from the usual "side-effecting skills are explicit-invocation only" guideline, recorded
here so it is not mistaken for an oversight.
