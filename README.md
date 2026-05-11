# ShruggieTech Claude Code Skills

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skills-D4A27F?logo=anthropic)](https://code.claude.com/docs/en/skills)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-Standard-555.svg)](https://agentskills.io)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Maintained](https://img.shields.io/badge/Maintained-yes-success.svg)](#status)

A curated collection of [Claude Code Skills](https://code.claude.com/docs/en/skills) used by ShruggieTech across client engagements, internal tooling, and ResoNova consulting work. Skills here encode consistent output formats, workflow automation, and house-style conventions so the same standards apply whether Claude Code is running on a Proxmox host, a personal workstation, or a collaborator's laptop.

Skills are modular folders containing a `SKILL.md` instruction file plus optional supporting assets. Claude Code loads them either automatically (when a user request matches the skill's description) or explicitly via `/skill-name`. See the [official skills documentation](https://code.claude.com/docs/en/skills) for the full model.

## Status

Actively maintained. Treat the `main` branch as the authoritative source; tagged releases are cut on a rolling basis when meaningful changes ship.

## Repository Structure

```
skills/
├── README.md                # This file
├── LICENSE                  # Apache 2.0
├── NOTICE                   # Required attribution notices
├── CHANGELOG.md
├── CONVENTIONS.md           # House-style rules every skill must follow
├── CONTRIBUTING.md          # How to propose or add a skill
├── scripts/
│   ├── install.sh           # Symlink helper for Linux and macOS
│   └── install.ps1          # Symlink helper for Windows 11 (PowerShell)
└── skills/
    ├── _template/           # Starting point for new skills
    │   └── SKILL.md
    └── <skill-name>/
        ├── SKILL.md         # Required: frontmatter + instructions
        ├── README.md        # Optional: human-facing notes
        ├── assets/          # Optional: templates, references, design tokens
        └── scripts/         # Optional: executable helpers (bash, python, etc.)
```

Each skill is a self-contained folder. `SKILL.md` is the only required file; everything else is optional and referenced from the body of `SKILL.md` when needed. Supporting files load lazily, so a skill can carry substantial reference material without inflating idle context.

## Installation

Claude Code discovers skills based on where they live on disk. The personal skills directory differs by platform:

| Platform   | Personal Skills Path                              | Project Skills Path                |
| ---------- | ------------------------------------------------- | ---------------------------------- |
| Linux      | `~/.claude/skills/<name>/`                        | `<project>/.claude/skills/<name>/` |
| macOS      | `~/.claude/skills/<name>/`                        | `<project>/.claude/skills/<name>/` |
| Windows 11 | `%USERPROFILE%\.claude\skills\<name>\`            | `<project>\.claude\skills\<name>\` |

Personal skills are available across all your projects. Project skills are scoped to one repository and travel with it through version control.

### Personal install (Linux and macOS)

Clone the repo somewhere stable, then run the install script to symlink each skill into `~/.claude/skills/`:

```bash
git clone https://github.com/shruggietech/skills.git ~/.shruggietech-skills
cd ~/.shruggietech-skills
./scripts/install.sh
```

### Personal install (Windows 11)

Symlinks on Windows 11 require either an elevated PowerShell session or [Developer Mode enabled](https://learn.microsoft.com/en-us/windows/apps/get-started/enable-your-device-for-development). Once one of those is in place, clone and run the PowerShell installer:

```powershell
git clone https://github.com/shruggietech/skills.git "$env:USERPROFILE\.shruggietech-skills"
Set-Location "$env:USERPROFILE\.shruggietech-skills"
.\scripts\install.ps1
```

Both installers create symlinks rather than copies, so a `git pull` updates every linked skill in place.

### Project install

If a skill should only apply to a single project, link it directly into that project's `.claude/skills/` directory.

Linux and macOS:

```bash
mkdir -p .claude/skills
ln -s ~/.shruggietech-skills/skills/<skill-name> .claude/skills/<skill-name>
```

Windows 11 (PowerShell):

```powershell
New-Item -ItemType Directory -Force -Path .claude\skills | Out-Null
New-Item -ItemType SymbolicLink `
    -Path ".claude\skills\<skill-name>" `
    -Target "$env:USERPROFILE\.shruggietech-skills\skills\<skill-name>"
```

Commit the symlink (or a copied folder) so collaborators get the same behavior.

### Live updates

Claude Code watches skill directories. Adding, editing, or removing a skill takes effect in the current session without restarting, as long as the parent skills directory existed when the session started.

## Conventions

Every skill in this repo follows a shared set of formatting and style rules so output stays consistent regardless of which skill is active. The full ruleset is in [`CONVENTIONS.md`](CONVENTIONS.md). Summary:

- UTF-8 encoding without BOM, no trailing whitespace
- No em-dashes in any prose output (use parentheses, commas, or standard hyphens)
- Markdown follows audience-conditional formatting (AI-only vs human-facing)
- Plans and logs are sequenced chronologically
- Every `SKILL.md` frontmatter declares at minimum: `description` (with clear trigger phrases) and an explicit `disable-model-invocation` value

## Contributing

New skills are welcome from ShruggieTech operators and trusted collaborators. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full workflow. Quick version:

1. Branch off `main`
2. Copy `skills/_template/` to `skills/<your-skill-name>/`
3. Fill in the frontmatter and body
4. Verify the skill triggers correctly with a local `claude` session
5. Update `CHANGELOG.md`
6. Open a pull request

Skill names use lowercase letters, numbers, and hyphens only (max 64 characters per the Agent Skills spec).

## License

Apache License, Version 2.0. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).

```
Copyright 2026 Shruggie LLC (DBA ShruggieTech)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
```

Individual skills may bundle scripts or assets under other compatible licenses; check the relevant skill's `README.md` if present.

## References

### Official documentation

- [Claude Code: Extend Claude with skills](https://code.claude.com/docs/en/skills) - canonical reference for skill structure, frontmatter, lifecycle, and sharing
- [Claude Code overview](https://code.claude.com/docs/en/overview) - top-level entry point for all Claude Code documentation
- [Claude Code commands reference](https://code.claude.com/docs/en/commands) - built-in commands and bundled skills (`/simplify`, `/debug`, etc.)
- [Claude Code plugins](https://code.claude.com/docs/en/plugins) - bundle skills and other extensions into installable packages
- [Claude Code subagents](https://code.claude.com/docs/en/sub-agents) - delegation patterns, including preloading skills into subagents
- [Claude Code hooks](https://code.claude.com/docs/en/hooks) - automate workflows around tool and skill lifecycle events
- [Claude Code permissions](https://code.claude.com/docs/en/permissions) - control tool and skill access at the workspace and managed-settings level
- [Claude Code settings reference](https://code.claude.com/docs/en/settings) - including `skillOverrides`, `skillListingBudgetFraction`, and managed settings
- [Agent Skills open standard](https://agentskills.io) - cross-tool spec that Claude Code skills implement

### Community resources

- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) - curated index of skills, hooks, plugins, and orchestrators
- [Thariq Shihipar: Using Claude Code, The Unreasonable Effectiveness of HTML](https://thariqs.github.io/html-effectiveness/) - rationale and examples for HTML-as-output workflows
- [Anthropic Engineering Blog](https://www.anthropic.com/engineering) - deeper dives on Claude Code internals and patterns
