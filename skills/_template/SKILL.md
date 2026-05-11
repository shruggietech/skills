---
name: skill-name-here
description: One sentence describing what this skill does and when Claude should invoke it. Include trigger phrases users would naturally say like "do the thing" or "run the thing" or "format this as the thing." Replace this entire field.
disable-model-invocation: false
---

# Skill Name

One paragraph describing what this skill does, who it is for, and what problem it solves. Replace this with real content.

## When to Use

Invoke this skill when:

- Trigger phrase one (replace with real trigger)
- Trigger phrase two (replace with real trigger)
- Trigger phrase three (replace with real trigger)

Do not invoke this skill for:

- Near-miss case one (replace or remove)
- Near-miss case two (replace or remove)

## Instructions

Write standing instructions here, not one-time steps. Claude reads this section every time the skill is active, so phrase rules as ongoing constraints rather than a sequential procedure.

Examples of good standing instructions:

- Output is always a single self-contained file (replace with real rule)
- Use the design tokens defined in `assets/tokens.md` (replace with real rule)
- Never include trailing commas in generated JSON (replace with real rule)

If the skill needs a sequential procedure for a specific task, describe it as a procedure inside the instructions rather than turning the whole body into a checklist.

## Examples

### Example: descriptive name of the example case

**User input:**

```
Replace with a realistic user prompt that should trigger this skill.
```

**Expected output:**

```
Replace with the expected output for that prompt. Keep it short enough to be useful as a reference but long enough to show the format.
```

### Example: a second case showing variation

**User input:**

```
Replace with another realistic prompt.
```

**Expected output:**

```
Replace with the expected output.
```

## Additional Resources

Reference any bundled supporting files here so Claude knows they exist and when to read them:

- `assets/reference.md` - replace this line, or remove if no supporting files
- `scripts/helper.sh` - replace this line, or remove if no helper scripts

If the skill has no supporting files, delete this section entirely.

## Notes for Skill Authors

Delete this entire section before committing the skill. It is here as a reminder, not as part of the skill body.

- Verify the frontmatter `name` matches the directory name
- Verify `disable-model-invocation` is set explicitly to `true` or `false`
- Run the [pre-commit checklist](../../CONVENTIONS.md#pre-commit-checklist) before opening a PR
- Test the skill in a real Claude Code session with at least three trigger phrasings
- Confirm the skill does not collide with bundled Claude Code skills or other skills in this repo
