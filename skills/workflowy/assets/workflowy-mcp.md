# Workflowy Desktop MCP

## Verify availability and scope

The desktop app must be running and signed in to the intended account with Local MCP enabled. Configure its Connection Link in a client that supports local Streamable HTTP. Keep the Connection Link in trusted client settings. A node URL points to content. A client that cannot reach the workstation needs a separately configured connection. [Official Desktop MCP setup](https://community.workflowy.com/t/workflowy-desktop-mcp/1695) · [Workflowy REST API](https://workflowy.com/api-reference/)

Discover the active tool schema. For a normal read, use `tree_seek` with `wait_any_match: false`. Use `url_is_any` for a supplied Workflowy node URL. Find named roots with a scoped exact match. Read the parent and ancestry before editing. For an operator-requested watch, use the connector's wait mode and observe its timeout behavior.

```json
{
  "seek_requests": [
    {
      "start_from": "root",
      "direction": "downward-deep",
      "max_match_edge_distance_from_start": 1,
      "filter": { "text_matches_any": [{ "pattern": "^AI Agent Workspace$" }] },
      "limit": 8,
      "truncate_text_at": 160
    }
  ],
  "wait_any_match": false
}
```

## Patch existing records

Use `tree_patch` with the smallest scoped batch. Find the direct child field by label and replace it by handle. For a move, retain the node ID and check parent and sibling order afterward. Use an adjacent anchor for sorted insertion and explicit child nesting for fields. Read back per-request outcomes and the live nodes. Re-read before retrying a failed or uncertain request. The attached note and bullet title are different fields. Use child bullets for structured fields.

Write native hashtags as plain text. Use a supported HTML anchor such as `<a href="https://workflowy.com/#/NODE">Source title</a>` for an exact internal reference. The editor's `[[` picker can also create internal links. Verify the target and, when relevant, its backlink. A generated backlink can appear in a seek as an unlabeled container and excerpts under the target. Treat it as incoming navigation. User-authored empty bullets are a separate case. Use native mirrors for intentionally shared live content and keep one canonical record. [Links and backlinks](https://workflowy.com/help/internal-external-links/) · [Tags and mentions](https://workflowy.com/help/tags-mentions) · [Mirrors](https://workflowy.com/help/mirrors)

## Record source dates

Use ISO 8601 text for the exact date or timestamp in a note title. For a day-only date value, use the editor's `!!` or `/date` picker or the supported native `time` markup. Keep the markup alone on its own value bullet.

```html
<time startYear="2026" startMonth="11" startDay="20">Nov 20, 2026</time>
```

Read back the time attributes and any separate exact ISO timestamp. The app can normalize the display text. Use separate tag values under `Tags` and retain the source's finest verified precision. [Date tags](https://community.workflowy.com/t/date-tags/1675)

## Recover comments

Existing comments can appear as a separate container when inspecting a bullet. Seek from that container to read the contents available to the current connector. A comment draft may be visible only to its owner. Keep published comments and drafts separate from normal records. For recovery and deletion checks, follow [legacy remediation](legacy-remediation.md). [Workflowy comment documentation](https://community.workflowy.com/t/fractal-comments/1681)
