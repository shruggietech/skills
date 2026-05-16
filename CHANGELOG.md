# Changelog

All notable changes to this repository are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this repository adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `shruggie-docs`: `buildDocument` now accepts an optional `partyMetadata: { [label: string]: string }` argument. For SOW, SOA, and MSA (which set `partyMetadataAfterTitle: true` in `doc-type-defaults.json`), the scaffold renders a horizontal-rule / metadata-row / horizontal-rule block immediately after TITLE and SUBTITLE. Each row is one paragraph with a tab stop at 108 PT; label is Geist 11 PT, value is Geist 11 PT, left-aligned. Key insertion order is preserved, so `{ Client, Partner, Date }` renders in that order

### Changed

- `shruggie-docs`: `assets/doc-type-defaults.json` `pageBreakRule` for SOW, SOA, and MSA changed from `"after-cover-and-major-sections"` to `"before-signature-block-only"`. The TOC now renders on page 1 immediately after the party metadata block; only the Signatures H1 (always the last H1 in the content array) carries `pageBreakBefore: true`
- `shruggie-docs`: `SKILL.md` updated with a "Relationship to the public docx skill" section (directly after "When to Use") clarifying that shruggie-docs takes precedence over the public docx skill for ShruggieTech-branded output; the public skill's role is limited to final OOXML validation and unpack-edit-repack of existing files
- `shruggie-docs`: `SKILL.md` frontmatter description amended with a disambiguation clause stating that shruggie-docs takes precedence over the public docx skill for ShruggieTech-branded output

### Fixed

- `shruggie-docs`: `SKILL.md` frontmatter `description` field was 1,374 characters, exceeding the 1,024-character upload limit. Trimmed to 881 characters by removing the redundant precedence-over-public-docx clause (already covered in the body's "Relationship to the public docx skill" section) and shortening the brand-identity parenthetical
- `shruggie-docs`: logo on the cover page was left-aligned (`"alignment": "START"` in `assets/style-spec.json`); changed to `"alignment": "CENTER"` so the logo centers horizontally. The template already called `alignmentFor(logoCfg.alignment)`, so this single token change is sufficient
- `shruggie-docs`: `assets/style-spec.json` `footer` block lacked a comment explaining that `"alignment": "END"` means right-aligned in OOXML. A `$comment` field now documents the binding for SOW, SOA, MSA, Internal Report, and Invoice, and Letter's `"CENTER"` override. `SKILL.md` step 7 of the build procedure now states that the build script must use the `Document` returned by `buildDocument` and must not construct `new Document(...)`, `new Footer(...)`, or footer paragraphs by hand
- `shruggie-docs`: `assets/embed-fonts.py` wrote the six font relationships to `word/_rels/document.xml.rels` instead of `word/_rels/fontTable.xml.rels`, so the `r:id` references in `word/fontTable.xml` did not resolve and Microsoft Word silently fell back to whatever fonts the reader had installed. Font embedding, the script's entire purpose, did not work. The function (now `update_font_table_rels`) targets the correct part-relationships file; idempotency and the existing duplicate-target guard are preserved
- `shruggie-docs`: `assets/embed-fonts.py` appended `<w:embedTrueTypeFonts>` and `<w:saveSubsetFonts>` to the end of `word/settings.xml`, violating the `CT_Settings` ordered sequence (they belong before `evenAndOddHeaders` and `compat`). The function now normalizes the child sequence after writing, so strict OOXML validators accept the part
- `shruggie-docs`: `assets/embed-fonts.py` wrote `<w:embed*>` children into each `<w:font>` in `FONT_BINDINGS` iteration order, which placed `<w:embedBold>` before `<w:embedRegular>` for Space Grotesk and violated the `CT_Font` ordered sequence. The function now normalizes each `<w:font>`'s child sequence after applying all bindings
- `shruggie-docs`: `assets/embed-fonts.py` `verify()` checked only that the six TTFs were present and that each family name string appeared in `fontTable.xml`; it returned `OK` on output that was functionally broken. `verify()` now parses both `fontTable.xml` and `fontTable.xml.rels`, confirms every `r:id` resolves to a relationship whose Target is a part present in the archive, rejects stray font relationships in `document.xml.rels`, and guards the `CT_Settings` and `CT_Font` orderings as regression checks. `--verify-only` now fails on a deliberately broken fixture
- `shruggie-docs`: removed the unused module-level `CONTENT_TYPE_FONT` constant from `assets/embed-fonts.py`. The constant referenced obfuscated-font handling that the script does not implement; `update_content_types()` correctly emits the non-obfuscated `application/x-font-ttf` content type for the `.ttf` `Default`
- `shruggie-docs`: `SKILL.md` step 8 of the build procedure and the `assets/embed-fonts.py` resource description updated to reflect that font relationships live in `word/_rels/fontTable.xml.rels` and that `verify()` performs relationship-resolution checks rather than presence-only checks

## [1.1.0] - 2026-05-14

### Added

- `shruggie-docs`: build a single self-contained `.docx` file using the official ShruggieTech parent-brand identity (light-surface color tokens, Space Grotesk and Geist typography embedded into the file, justified body text, brand-correct title color `#00AB21`, lightbg logo). The skill governs six document types (SOW, SOA, MSA, Internal Report, Invoice, Letter) with per-type defaults for TOC inclusion, top block, footer, page-break rule, and tagline inclusion. Bundles the six canonical TTFs (`SpaceGrotesk-Medium`, `SpaceGrotesk-Bold`, `Geist-Regular`, `Geist-Medium`, `Geist-Italic`, `GeistMono-Regular`) byte-identically from `https://cdn.shruggie.tech/brand/fonts/ttf/` and a byte-identical copy of the lightbg logo from the brand CDN. Includes a docx-js scaffold (`assets/document-template.js`) that reads `assets/style-spec.json` and `assets/doc-type-defaults.json` rather than hardcoding any style or layout values, and a font-embedding post-process (`assets/embed-fonts.py`) that drops the six TTFs into `word/fonts/`, patches `word/fontTable.xml` and `word/_rels/document.xml.rels`, and sets the embed flag in `word/settings.xml`
- `TODO.md`: running list of engineering follow-ups not yet scheduled for a release. Seeded with one item: `scripts/release.{sh,ps1}` does not create a GitHub Release by default (the `v1.0.0` Release was published manually after the tag was cut)

### Changed

- `README.md`: lead with a `Use a skill` section that targets the common Claude browser / desktop user story (download the per-skill zip from the latest GitHub Release, upload via Claude's in-app skill UI). The CLI symlink instructions move into a clearly-labeled `In Claude Code (the CLI)` subsection with an explicit note that symlinking `~/.claude/skills/` has no effect on the Claude browser or desktop apps. Repository Structure section gets `TODO.md` and the new `scripts/release.{sh,ps1}` files added to its tree

## [1.0.0] - 2026-05-13

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

[unreleased]: https://github.com/shruggietech/skills/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/shruggietech/skills/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/shruggietech/skills/releases/tag/v1.0.0
