# Conventions

House-style rules every skill in this repo must follow. These exist so output stays consistent across skills, contributors, and platforms regardless of which skill is active or who authored it.

## File Encoding

- UTF-8 without BOM
- LF line endings (not CRLF), even on Windows
- No trailing whitespace on lines
- File ends with a single trailing newline

Authors on Windows: configure your editor and `.gitattributes` to normalize line endings on commit. Mojibake from mixed encodings shows up in skill output and is a pain to track down after the fact.

## Skill Directory Layout

Every skill is a directory under `skills/` whose name matches the invocation slug:

```
skills/<skill-name>/
  SKILL.md           # Required
  README.md          # Optional, human-facing notes
  assets/            # Optional, templates and reference material
  scripts/           # Optional, executable helpers
```

Naming rules from the Agent Skills standard:

- Lowercase letters, digits, and hyphens only
- Maximum 64 characters
- Slug should match what a user would naturally type for `/skill-name`
- Avoid generic names that could collide with bundled Claude Code skills (`debug`, `simplify`, `loop`, `batch`, `claude-api`)

## SKILL.md Frontmatter

Required fields:

- `description` - what the skill does and when Claude should invoke it; include trigger phrases users would naturally say
- `disable-model-invocation` - explicit `true` or `false`; never omit, never let it default silently

Recommended fields:

- `allowed-tools` - any tools the skill needs without per-use approval
- `argument-hint` - autocomplete hint when the skill takes arguments
- `when_to_use` - additional trigger phrases that didn't fit cleanly in `description`

The combined `description` and `when_to_use` text is truncated at 1,536 characters in the skill listing. Put the most important trigger phrase first.

## SKILL.md Body

Keep the body concise. Once invoked, the rendered SKILL.md sits in conversation context for the rest of the session and gets re-attached after compaction. Every line is a recurring token cost.

Guidelines:

- State what to do as standing instructions, not one-time steps
- Move detailed reference material to supporting files; link from the body
- Keep the body under 500 lines; if it grows beyond that, split reference content into separate files
- Use semantic section headings so the contents are skimmable
- Show example invocations and example outputs where they clarify expected behavior

If the skill needs deterministic logic, bundle a script in `scripts/` and have the body instruct Claude to run it. Use `${CLAUDE_SKILL_DIR}` to reference bundled assets so paths resolve regardless of install location.

## Audience and Markdown Formatting

Skill content is consumed by Claude at invocation time. Treat SKILL.md as AI-facing:

- Pure Markdown only
- No inline HTML except where an established convention requires it
- No anchor tags, page-break rules, or div wrappers
- No decorative formatting

Supporting documentation that humans read (README.md inside a skill directory, CONTRIBUTING.md, this file) follows human-facing markdown conventions: prose, headings, lists, code blocks, judicious tables.

## Prose Style

These rules apply to all output the skill produces, not just the skill body itself:

- No em-dashes in any prose; use parentheses, commas, or standard hyphens
- No en-dashes either
- Avoid AI rhetorical tropes, especially the contrasting device ("it's not just X, it's Y")
- For plans, sprint documents, and code update logs: sequence development sessions in chronological order
- Skip unsolicited restructuring, over-explanation, and hedging

## Invocation Control

Pick the right invocation mode for the skill's purpose:

| Skill Type                | Recommended Setting               | Rationale                                                |
| ------------------------- | --------------------------------- | -------------------------------------------------------- |
| Output formatting         | `disable-model-invocation: false` | Claude should pick it up when format applies             |
| Conventions/reference     | `disable-model-invocation: false` | Knowledge that applies whenever relevant                 |
| Actions with side effects | `disable-model-invocation: true`  | Deploys, commits, sends, deletes; never auto-trigger     |
| Manual workflows          | `disable-model-invocation: true`  | Multi-step procedures the user controls timing on        |

Hide background-knowledge skills from the `/` menu with `user-invocable: false` if they aren't actionable as commands.

## Pre-Approved Tools

The `allowed-tools` field grants permission while the skill is active. Be deliberate:

- List the minimum set the skill actually needs
- Prefer narrow patterns (`Bash(git status *)`) over broad ones (`Bash`)
- For destructive operations, leave the approval prompt in place even when convenient

## Supporting Files

When a skill needs supporting files, reference them from SKILL.md so Claude knows what each one contains:

```markdown
## Additional resources

- For complete API details, see [reference.md](reference.md)
- For example outputs, see [examples.md](examples.md)
```

Scripts go in `scripts/` and are executed, not loaded into context. Templates and reference docs go in `assets/` or the skill root and are loaded only when SKILL.md instructs Claude to read them.

## Changelog and Versioning

Every meaningful change to a skill gets an entry in the top-level `CHANGELOG.md` under the appropriate version heading. Skill authors do not maintain per-skill changelogs. Use semantic-ish versioning at the repo level: breaking changes to skill behavior bump the minor version at minimum.

## Pre-Commit Checklist

Before opening a pull request, verify:

- UTF-8 without BOM, LF line endings, no trailing whitespace
- No em-dashes or en-dashes anywhere
- Frontmatter declares `description` and `disable-model-invocation` explicitly
- SKILL.md body is under 500 lines (or has supporting files for the overflow)
- Skill triggers correctly in a local `claude` session
- CHANGELOG.md updated
- No mojibake or encoding artifacts in any committed file
