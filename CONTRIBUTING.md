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

## Cutting a Release

Releases are cut from `main` once a meaningful batch of changes has accumulated under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md). The scripts in `scripts/` handle the version bump, CHANGELOG roll, release-notes generation, per-skill zip artifacts, tag, and push as a single command.

Defaults: increment is **patch** (the third segment of `MAJOR.MINOR.PATCH`); branch is `main`; zips are built; push happens at the end. Both scripts refuse to run if the working tree is dirty, the current branch is not `main`, the local branch is out of sync with `origin/main`, the target tag already exists, or the `Unreleased` section is empty.

### Linux and macOS

```bash
./scripts/release.sh --dry-run --verbose          # preview the patch release
./scripts/release.sh                              # cut a patch release
./scripts/release.sh --minor                      # cut a minor release
./scripts/release.sh --version 2.0.0              # cut an explicit version
./scripts/release.sh --major --no-push            # bump major locally, review, push manually
./scripts/release.sh --gh-release                 # also create the GitHub release with `gh`
./scripts/release.sh --help
```

### Windows 11 (PowerShell)

```powershell
.\scripts\release.ps1 -WhatIf -Verbose            # preview the patch release
.\scripts\release.ps1                             # cut a patch release
.\scripts\release.ps1 -Minor                      # cut a minor release
.\scripts\release.ps1 -Version '2.0.0'            # cut an explicit version
.\scripts\release.ps1 -Major -NoPush              # bump major locally, review, push manually
.\scripts\release.ps1 -GhRelease                  # also create the GitHub release with `gh`
Get-Help .\scripts\release.ps1 -Full
```

### What gets produced

A successful release writes:

- An updated `CHANGELOG.md` (the `[Unreleased]` contents become `[X.Y.Z] - YYYY-MM-DD`; a fresh empty `[Unreleased]` heading takes their place, and Keep a Changelog footer comparison links are maintained at the bottom of the file).
- A new `release-notes/vX.Y.Z.md` (the new version's CHANGELOG section, ready to paste into release announcements or GitHub release bodies).
- One zip per skill at `dist/vX.Y.Z/<skill-name>-vX.Y.Z.zip`, each containing a single top-level directory matching the skill name. These are the files to upload to Claude UI: one skill, one zip, one upload.
- A `dist/vX.Y.Z/SHA256SUMS.txt` checksum manifest covering the zips.
- A single annotated tag `vX.Y.Z` whose message body is the contents of the new release-notes file.
- A single commit (`chore(release): cut vX.Y.Z`) that contains only the CHANGELOG and release-notes changes.

`dist/` is gitignored. `release-notes/` is tracked so historical notes stay with the repo.

### When to use which bump

- **Patch** (default): bug fixes, documentation tweaks, internal refactors that do not change skill behavior.
- **Minor**: new skills, new flags or capabilities on existing skills, anything that meaningfully changes the trigger phrasing or output shape of a skill (per `CONVENTIONS.md`).
- **Major**: removals or backwards-incompatible reorganizations (rename of a skill slug, removal of a long-standing flag, etc.).
- **Explicit version**: only for the first release, or when a coordinated bump is needed for non-default reasons. Must be strictly greater than the highest existing tag.

### Validate with dry-run first

Always run with `--dry-run` (bash) or `-WhatIf` (PowerShell) before cutting a real release. The dry-run runs every preflight check and prints exactly what the real run would do (CHANGELOG transform, zips, commits, tags, push commands) without writing or pushing anything. Pair with `--verbose` / `-Verbose` to see the full CHANGELOG and release-notes previews inline.

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
