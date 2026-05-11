# Contributing

How to propose, build, and ship a new skill in this repo. The goal is to keep the bar high without creating friction.

## Who Can Contribute

This is primarily a ShruggieTech operational repo. Pull requests are welcome from ShruggieTech operators, ResoNova collaborators, and engaged clients. Outside contributions are reviewed case by case. Open an issue first if you are not sure whether something belongs here.

## Prerequisites

- Claude Code installed and working locally
- Familiarity with skills (read [CONVENTIONS.md](CONVENTIONS.md) and the [official skills documentation](https://code.claude.com/docs/en/skills) first)
- Git, and write access or the ability to fork

## Branching and Pull Request Workflow

1. Fork or create a feature branch off `main`
2. Use a branch name that reflects the skill: `add-skill-<skill-name>` or `fix-skill-<skill-name>`
3. Commit in logical units; squash trivial fixups before requesting review
4. Update `CHANGELOG.md` in the same PR that introduces the change
5. Open the PR against `main` with a description that covers what the skill does, how to test it, and any caveats
6. Address review feedback in additional commits; reviewers will squash on merge unless the history is meaningful

## Creating a New Skill

1. Copy the template directory:

   Linux and macOS:

   ```bash
   cp -r skills/_template skills/<your-skill-name>
   ```

   Windows 11 (PowerShell):

   ```powershell
   Copy-Item -Recurse skills\_template skills\<your-skill-name>
   ```

2. Edit `skills/<your-skill-name>/SKILL.md`:
   - Replace every placeholder in the frontmatter with real values
   - Set `disable-model-invocation` explicitly (do not let it default)
   - Write the body as standing instructions, not one-off steps
   - Fill in or remove the example sections so nothing is left as a placeholder

3. Add supporting material if needed:
   - Templates and reference docs go in `assets/`
   - Executable helpers go in `scripts/`
   - Reference each supporting file from `SKILL.md` so Claude knows it exists and when to read it

4. Link the skill into your local Claude install for testing (see [README.md](README.md) for platform-specific commands)

5. Test the skill in a real `claude` session against several phrasings of the trigger

## Local Testing Checklist

Before opening the PR, verify each of these in a live Claude Code session:

- The skill appears in `/` autocomplete (unless `user-invocable: false` was set deliberately)
- Manual invocation via `/skill-name` loads the skill and produces the expected behavior
- Auto-invocation fires when the skill is set to `disable-model-invocation: false` and the user phrasing matches the description; try at least three natural variations
- Auto-invocation does not fire on near-miss phrasings that should not trigger the skill
- Any bundled scripts execute correctly with the declared `allowed-tools` permissions
- Supporting files referenced from `SKILL.md` resolve and load when the body instructs Claude to read them
- The skill produces output that complies with [CONVENTIONS.md](CONVENTIONS.md), including the no-em-dash rule and audience-conditional markdown rules

## Review Criteria

Reviewers will check for:

- **Frontmatter completeness**: `description` is specific and includes natural trigger phrases; `disable-model-invocation` is set explicitly
- **Body discipline**: under 500 lines, no narrative bloat, reference material moved to supporting files where appropriate
- **Encoding hygiene**: UTF-8 without BOM, LF endings, no trailing whitespace, no mojibake
- **Style compliance**: no em-dashes, no en-dashes, no AI-trope phrasing, chronological sequencing where applicable
- **Tool scoping**: `allowed-tools` is minimal and uses narrow patterns where possible
- **Naming**: slug uses only lowercase letters, digits, and hyphens; does not collide with bundled Claude Code skills
- **Trigger quality**: skill activates on intended phrasings and stays quiet on near misses

Cosmetic issues (typos, formatting nits) are inline comments. Structural issues (wrong invocation mode, leaky tool permissions, overlapping responsibility with an existing skill) are blocking and require a follow-up commit.

## Updating CHANGELOG.md

Every PR that adds, modifies, or removes a skill updates `CHANGELOG.md`. Entries live under an `Unreleased` heading until the next tag is cut. Format:

```markdown
## Unreleased

### Added
- `skill-name`: brief description of what it does

### Changed
- `skill-name`: brief description of the change

### Removed
- `skill-name`: brief description of why
```

Breaking changes to existing skill behavior are called out explicitly under `Changed` and require a minor-version bump at the next tag.

## Security and Sensitive Material

Skills are loaded into Claude's context and may pre-approve tool access. Do not:

- Hardcode credentials, API keys, or tokens in any skill file
- Pre-approve broad shell access (`Bash`, `Bash(*)`) for skills that do not strictly need it
- Bundle binary executables without explaining what they do and why
- Reference internal-only URLs or paths that won't resolve outside ShruggieTech infrastructure

If a skill needs credentials at runtime, instruct Claude to read them from environment variables or a designated secrets file at invocation time. Do not commit the secrets themselves.

## Maintainers

- William Thompson ([@h8rt3rmin8r](https://github.com/h8rt3rmin8r))
- Natalie Thompson

Open an issue for questions, bug reports, or skill proposals. For sensitive matters, contact via the channels listed on the ShruggieTech website rather than GitHub issues.

## License of Contributions

By submitting a pull request, you agree that your contribution will be licensed under the Apache License, Version 2.0, consistent with the rest of the repository. If you bundle third-party assets under different licenses, declare them in the affected skill's `README.md` and ensure they are Apache 2.0 compatible.
