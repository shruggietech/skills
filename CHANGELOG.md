# Changelog

All notable changes to this repository are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this repository adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Fixed

- `shruggie-html`: section-surface tokens (`--color-section-services`, `--color-section-work`, `--color-section-research`, `--color-section-cta`) and the `.card-glass` rule were missing from the `[data-theme="dark"]` block in `assets/brand.css`, so a light-system-preference browser opening a `data-theme="dark"` page rendered white text on light gray section surfaces; the dark attribute now fully pins those surfaces regardless of system preference
- `shruggie-html`: removed the broken `https://cdn.shruggie.tech/brand/logo/logo-icon-green.png` reference from `SKILL.md` and `assets/brand-rules.md` (the CDN URL returned 404)
- `shruggie-html`: logos and favicons in generated HTML failed to render in sandboxed environments (Claude chat artifacts, email clients, offline opens) because they loaded from the brand CDN; they now embed as inline base64 `data:` URIs so generated pages are fully self-contained
- `scripts/install.ps1`: wrap `Get-ChildItem` result in `@()` so `.Count` resolves correctly when only one skill directory is present (Set-StrictMode -Version Latest forbids `.Count` on scalars)

### Added

- `scripts/release.sh` and `scripts/release.ps1`: parallel release-cutting scripts. Roll the Keep a Changelog `Unreleased` section into a new versioned section, write a `release-notes/vX.Y.Z.md` extract, build one zip per non-template skill in `dist/vX.Y.Z/` (each zip wraps a single top-level skill directory so it drops directly into the Claude UI skill upload), compute a `SHA256SUMS.txt` manifest, create the release commit (`chore(release): cut vX.Y.Z`), tag it as an annotated `vX.Y.Z`, and push. Default bump is patch; flags select major, minor, or an explicit version. Both scripts ship `--dry-run` / `-WhatIf`, verbosity controls, and a `--gh-release` / `-GhRelease` opt-in that wraps `gh release create`
- `shruggie-html`: `assets/brand/` directory with byte-identical local copies of the 3 brand logos and 7 favicon files mirrored from the brand CDN, plus `assets/inline-assets.md` with pre-computed base64 `data:` URIs keyed by placeholder token for the build step to paste into generated HTML
- `shruggie-html`: build a single self-contained HTML file using the official ShruggieTech parent-brand identity (immutable color tokens, CDN-wired Space Grotesk and Geist typography, dark-mode-first layout, voice rules, exact tagline)

### Changed

- `CONTRIBUTING.md`: new `Cutting a Release` section documenting the bash and PowerShell release scripts, the dry-run validation flow, the produced artifacts (CHANGELOG roll, release notes, per-skill zips, SHA256SUMS), and guidance on when to choose major / minor / patch / explicit version bumps
- `.gitignore`: ignore `.claude/` (Claude Code harness-managed local state: worktrees, plans, settings) so it stops showing as untracked content during `git status` and release-script preflight checks
- `shruggie-html`: `assets/page-template.html` now uses `{{LOGO_DARKBG_DATA_URI}}`, `{{OG_IMAGE_DATA_URI}}`, and `{{FAVICON_*_DATA_URI}}` placeholders for every logo, favicon, and social-share image; the build step substitutes them from `assets/inline-assets.md`, so generated HTML contains no `cdn.shruggie.tech/brand/(logo|favicon)/` URLs. The typography stylesheet at `https://cdn.shruggie.tech/brand/typography.css` is the one remaining remote dependency (the brand CSS has system-font fallback stacks if it fails to load)
- Initial repository scaffolding
- `README.md` covering purpose, installation (Linux, macOS, Windows 11), conventions summary, and references
- `CONVENTIONS.md` with house-style rules for every skill (encoding, frontmatter, body discipline, prose constraints, invocation control)
- `CONTRIBUTING.md` with workflow, local testing checklist, review criteria, and security guidance
- `LICENSE` (Apache License, Version 2.0)
- `NOTICE` for Apache 2.0 attribution
- `.gitattributes` enforcing LF line endings across all platforms
- `.gitignore` covering OS detritus, editor state, and common build outputs
- `scripts/install.sh` symlink installer for Linux and macOS
- `scripts/install.ps1` symlink installer for Windows 11 (PowerShell 5.1+)
- `skills/_template/SKILL.md` starting point for new skill authoring
