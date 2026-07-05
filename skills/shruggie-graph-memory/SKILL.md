---
name: shruggie-graph-memory
description: Automatically capture durable knowledge from an ordinary conversation into ShruggieGraph (a permission-scoped, source-backed AI memory) by calling its create_note MCP tool, and recall it later with search_knowledge. Use whenever the ShruggieGraph MCP tools are connected and the conversation surfaces a durable, reusable fact worth keeping across sessions and AI providers (a decision, preference, commitment, deadline, or person/project/org detail). Trigger on phrasings like "remember this", "save that to my memory", "note that for later", "what do I know about X", "check my memory for", and also proactively whenever a lasting fact appears that the user will want again. Skip trivia, transient chit-chat, secrets the user has not asked to store, and any session where the ShruggieGraph tools are not connected.
disable-model-invocation: false
---

# ShruggieGraph Memory

Turn an ordinary working conversation into durable, retrievable memory in ShruggieGraph, a
permission-scoped, source-backed AI memory backend the user owns and carries across AI providers.
When the ShruggieGraph MCP tools are connected, this skill has you write durable knowledge as
notes with the `create_note` tool (each note becomes a cited source with an audit trail) and
recall it with `search_knowledge`. The ShruggieGraph backend decides all access; this skill never
makes a permission decision of its own, it only chooses what is worth remembering and writes it to
the memory the user's connection is linked to.

## When to Use

Invoke this skill when:

- The user explicitly asks to remember, save, note, or store something ("remember this", "save
  that to my memory", "note that for later").
- The user asks what is already known ("what do I know about X", "check my memory for", "have I
  noted anything about Y").
- A conversation surfaces a durable, reusable fact even without an explicit save instruction: a
  decision, a stated preference, a commitment or deadline, a stable detail about a person,
  project, organization, or tool, or a recurring theme the user will want again later.

Do not invoke this skill when:

- The ShruggieGraph MCP tools (`create_note`, `search_knowledge`) are not connected in the
  session. Without them there is nothing to write to; do not pretend to save anything.
- The content is transient chit-chat, one-off scratch work, or trivia with no lasting value.
- The content is a secret, credential, or sensitive personal detail the user has not asked you to
  store. Ask first before writing anything sensitive.
- The user is working inside a different memory or note system; defer to the tool they named.

## Instructions

Treat capture as a steady background habit, not a feature the user has to trigger. The default is:
when a durable fact appears, save it; when the user asks what they know, search first.

### Knowing where to write

There is nothing to configure and no id to ask for. The user's connection (an `sgmcp_` token or
an OAuth-connected client) is linked to one or more memories when it is created, and `create_note`
writes to the only linked memory by default. Only if the user has linked several memories to one
connection does targeting matter: pass the optional `context` string describing which memory they
mean (for example their personal memory versus a shared group memory). Never invent a `context`
value; if a write fails on targeting, ask the user which memory they intend rather than retrying
blindly.

### What to capture

Write a note when the conversation produces something the user will plausibly want weeks later:

- Decisions and their rationale ("we picked Postgres over Mongo because ...").
- Stated preferences and conventions ("I always want commit messages in imperative mood").
- Commitments, deadlines, and plans with dates (convert relative dates to absolute).
- Stable facts about people, projects, organizations, and tools.
- Recurring themes, open questions, and things explicitly flagged as "for later".

Keep each note self-contained: a clear `title` and a `content` body that will still make sense out
of context, with enough detail that a future reader does not need this conversation to understand
it. One idea per note. Prefer the user's own wording for anything where phrasing matters.

### What not to capture

- Trivia, small talk, and ephemeral state ("what time is it", "thanks").
- Content already saved this session or clearly already in memory (search first; see below).
- Secrets, credentials, and sensitive personal data unless the user asked you to store them.
  `create_note` only accepts normal-sensitivity notes, so stricter material does not belong here.

### Avoiding duplicates

Before writing a fact you suspect may already exist, run `search_knowledge` for it. If a close
match comes back, do not create a near-duplicate; note the overlap to the user instead. Batch
several related facts from one exchange into a small number of clear notes rather than many
fragments.

### Recall

When the user asks what they know, or when a question would be answered by their own memory, call
`search_knowledge` with a focused query and answer from what it returns. ShruggieGraph returns
permission-filtered, cited context and does not generate answers itself; you do the reasoning over
the returned context and cite the notes you used. Never imply a fact is stored if the search did
not return it.

### Confirmation and honesty

After a successful write, tell the user in one short line what you saved and where (for example,
"Saved to ShruggieGraph: 'Q3 launch moved to October'"), so the capture is visible and the audit
trail is honest. If a write fails, say so plainly rather than implying the note was stored.

For the tool input shapes, scopes, and setup details, read
[assets/capture-reference.md](assets/capture-reference.md).

## Examples

### Example: proactive capture without an explicit instruction

**User input:**

```
Let's go with Caddy for TLS termination on the alpha VM instead of nginx, mainly because
it does automatic certs and we don't want to manage renewals by hand.
```

**Expected output:**

```
Got it. (calls create_note with title = "TLS termination: Caddy on the alpha VM", content =
"Decision: use Caddy (not nginx) for TLS on the alpha VM. Reason: automatic certificate
issuance and renewal, so no manual renewal management.")

Saved to ShruggieGraph: "TLS termination: Caddy on the alpha VM".
```

### Example: recall before answering

**User input:**

```
What did we decide about TLS on the VM again?
```

**Expected output:**

```
(calls search_knowledge with query = "TLS termination decision alpha VM")

From your memory: you chose Caddy over nginx for TLS on the alpha VM, for automatic certificate
issuance and renewal (no manual renewals).
```

### Example: declining to capture

**User input:**

```
ugh, long day. anyway what's 12 * 7?
```

**Expected output:**

```
84. (no note written; this is transient chatter with nothing durable to remember)
```

## Additional Resources

- [assets/capture-reference.md](assets/capture-reference.md) - the `create_note` and
  `search_knowledge` input shapes, scopes, the normal-sensitivity cap, and memory targeting.
- `README.md` - human-facing setup: connecting claude.ai or Claude Desktop to ShruggieGraph and
  minting a token.
