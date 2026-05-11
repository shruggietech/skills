---
name: shruggie-html
description: Build a single self-contained HTML file using the official ShruggieTech parent-brand identity (immutable color tokens, Space Grotesk and Geist typography wired through the brand CDN, dark-mode-first layout, voice rules, exact tagline). Use whenever the user asks for an HTML page, landing page, one-pager, mini-site, internal report, pitch page, or any standalone HTML deliverable that should read as a ShruggieTech artifact. Trigger on phrasings like "make an HTML page", "build a landing page", "spin up a one-pager", "write me an internal report as HTML", "shruggie-branded page", or any HTML request that touches a ShruggieTech, Shruggie LLC, or parent-brand surface. Skip for React or Next.js component work, multi-route apps, and pages that are primarily about a product sub-brand (metadexer, Covarity, Knox.Dance, SparkPlan, rustif, shruggie-indexer, shruggie-feedtools), which carry their own visual identities.
disable-model-invocation: false
---

# Shruggie HTML

Produce a single self-contained `.html` file that conforms to the ShruggieTech parent-brand identity. The skill bundles the brand color tokens, typography wiring, section primitives, and voice rules so Claude can emit on-brand HTML without re-deriving any of them per task. The default deliverable shape is one `.html` file with all CSS inlined inside a single `<style>` block; fonts and images load from the ShruggieTech CDN so the file survives email, CMS, and PDF pipelines without breaking.

## When to Use

Invoke this skill when:

- The user asks for an HTML page, landing page, one-pager, mini-site, internal report, or pitch page in a ShruggieTech, Shruggie LLC, or parent-brand context.
- The user names a ShruggieTech audience landing surface, services page, work showcase, or research write-up to be delivered as a standalone HTML file.
- The user asks for a "shruggie-branded" or "on-brand" HTML deliverable without naming a specific product sub-brand.
- The user is iterating on the content of an existing single-file HTML artifact that already follows these rules.

Do not invoke this skill for:

- React, Next.js, Svelte, Vue, or other component-framework work. Those surfaces live in their host project and follow the project's local conventions.
- Multi-route static sites or full mini-apps with build steps. The skill's deliverable is one file, not a project.
- Pages that are primarily about a product sub-brand (metadexer, Covarity, Knox.Dance, SparkPlan, rustif, shruggie-indexer, shruggie-feedtools). Each sub-brand maintains its own visual identity; this skill speaks only for the parent brand. If a parent-brand page mentions a sub-brand in passing that is fine; if the page is mostly about the sub-brand, flag the scope conflict and ask whether to defer to the sub-brand's own system.
- Google Business Profile content and any other platform that requires authentic photography. The kawaii mark is not permitted there.
- Editing source files inside the `shruggietech-website` Next.js project. That repo has its own design tokens already wired into Tailwind.

## Instructions

The skill's deliverable is always **a single self-contained `.html` file** unless the user explicitly asks for a multi-file structure. The whole stylesheet is inlined inside one `<style>` block in `<head>`; the only external references are the brand CDN URLs (typography stylesheet, logo, favicon, OG image).

### Brand fidelity

The five immutable brand color tokens are `--color-black` (`#000000`), `--color-green-bright` (`#2BCC73`), `--color-green-deep` (`#00AB21`), `--color-orange` (`#FF5300`), and `--color-gray-light` (`#D1D3D4`). Their hex values do not change. If an accessibility or layout constraint requires a deviation, branch at the derived `--color-gray-*` tokens or at the section surface layer, never at the brand tokens. The full token set, including derived and section surface tokens, is defined in `assets/brand.css`; that file is the single source of truth, and the skill inlines its full contents into the page.

Light-mode accessibility: Green Bright passes WCAG AA on black but fails on white. The brand CSS already handles this with a `prefers-color-scheme: light` block that swaps green accent text to `var(--color-green-deep)`. Do not author light-mode overrides inline in the page; rely on the bundled CSS.

Typography is three faces, all loaded through the CDN stylesheet:

- Space Grotesk (500, 700) for display, headings, button labels, logotype.
- Geist (400, 500) for body, UI, paragraphs, lists.
- Geist Mono (400) for code, eyebrow labels, metadata.

Fonts load through `@import url("https://cdn.shruggie.tech/brand/typography.css");` at the top of the inlined `<style>` block. Never inline `@font-face` rules in the page; the CDN stylesheet is authoritative and may evolve. Never substitute system fonts in production output; the fallback stacks in `brand.css` are for graceful degradation only.

### Document shape

The page renders dark by default: `<html lang="en" data-theme="dark">` plus `<meta name="color-scheme" content="dark light">`. The `data-theme="dark"` attribute pins the dark palette regardless of system preference, matching the brand's dark-mode-first stance. If the user explicitly asks for a light-default page, drop the `data-theme` attribute and let `prefers-color-scheme` drive the mode.

Every page has:

- A `site-header` with the dark-bg logo (`https://cdn.shruggie.tech/brand/logo/logo-darkbg.png`) and primary nav. If the page renders light-default, swap to the light-bg logo.
- A `<main>` composed of one hero plus zero or more sections from `assets/sections.md`.
- A `site-footer` with the `By ShruggieTech` attribution and the tagline component. The tagline string is exact: `¯\_(ツ)_/¯ We'll figure it out.` Never paraphrase. Mark the emoticon `aria-hidden="true"` and color it with `var(--text-accent)`; the rest of the tagline renders muted.
- Favicon link tags pointing at the CDN `.ico` and at least one PNG size for the apple-touch-icon slot. URLs come from `assets/brand-rules.md`; never hand-construct a CDN URL.

### Logo URLs

Pull logo images by URL from the CDN. Never substitute a hand-made or off-CDN URL. The full list lives in `assets/brand-rules.md`. The three you will use most often:

- Dark surfaces (default): `https://cdn.shruggie.tech/brand/logo/logo-darkbg.png`
- Light surfaces: `https://cdn.shruggie.tech/brand/logo/logo-lightbg.png`
- Mark only (no wordmark): `https://cdn.shruggie.tech/brand/logo/logo-icon-green.png`

The OG image and Twitter card image both point at `https://cdn.shruggie.tech/brand/logo/github-social-share.png` unless the user supplies a custom social image.

### Voice and copy

All body copy follows the ShruggieTech voice rules:

1. Second person. Speak to the reader.
2. No competitive jabs and no named attacks on vendors.
3. No unsubstantiated claims. Only state capabilities the team can demonstrate.
4. Confidence without arrogance. Plain assertions, no hedging.
5. Plain English. No `synergy`, `leverage`, `best-in-class`, `turnkey`, `solutioning`.
6. Humor is permitted in small doses where it lands naturally.

If the user gives you draft copy that violates a rule (for example, a competitor name in marketing prose), surface the conflict and ask before silently rewriting.

### Motion

Single-file HTML one-offs ship without animation by default. If the user asks for motion, stay inside the permitted catalog from `assets/brand-rules.md` (scroll reveal, hover feedback, page transition cross-fade, link underline). Wrap every animation in `@media (prefers-reduced-motion: reduce)` and reduce to zero duration; the bundled CSS already handles this for transitions but new keyframes need the guard.

### Output hygiene

Every file the skill writes complies with the repo CONVENTIONS:

- UTF-8 encoding, no BOM.
- LF line endings.
- No trailing whitespace on any line.
- A single trailing newline at end of file.
- Zero em-dashes and zero en-dashes anywhere in the document, including HTML comments, `alt` text, and meta-tag content. Use parentheses, commas, or standard hyphens instead.
- Every `<img>` has meaningful `alt` text. Decorative-only images use `alt=""` plus `aria-hidden="true"`.

### Build procedure

When the user has confirmed scope and you are ready to emit the file:

1. Read `assets/brand.css` and `assets/page-template.html`.
2. Confirm the deliverable type (landing page, one-pager, internal report) and pick the section primitives you will need.
3. Read `assets/sections.md` and copy the fragments you need into the template's `<main>` in order.
4. Inline the full contents of `assets/brand.css` into the template's `<style>` block, replacing the placeholder comment. Keep the `@import` line as the first statement inside the block.
5. Replace template placeholders (`{{PAGE_TITLE}}`, `{{PAGE_DESCRIPTION}}`, `{{HEADLINE}}`, `{{LEDE}}`, `{{CTA_LABEL}}`, `{{EYEBROW}}`) with the real content. If the page does not use a placeholder, delete it; do not leave it in the file.
6. Run the pre-output checklist below and only then write the file.
7. Write the file to the path the user specified, or to `./<slug>.html` if no path was given. Pick a slug derived from the page title (lowercase, hyphenated).

### Pre-output checklist

Before writing the file, verify:

- The five brand color tokens appear on `:root` with the exact hex values from `brand-rules.md`.
- The `@import` for `https://cdn.shruggie.tech/brand/typography.css` is the first declaration inside the `<style>` block.
- `data-theme="dark"` is set on `<html>` (unless the user asked for light-default).
- The tagline renders exactly as `¯\_(ツ)_/¯ We'll figure it out.` with `aria-hidden="true"` on the shruggie span.
- Every logo and favicon URL is one from the bundled CDN list, not hand-constructed.
- Every `<img>` has `alt` text. Decorative images use `alt=""` and `aria-hidden="true"`.
- No em-dashes, no en-dashes anywhere in the document.
- File saves UTF-8 no-BOM, LF endings, single trailing newline.

## Examples

### Example: services landing page

**User input:**

```
Make me a single-page HTML landing for ShruggieTech's AI engineering services. Hero, three value props, a CTA to book a call.
```

**Expected output:**

A single `.html` file containing:

- `<html lang="en" data-theme="dark">` with the standard meta tags and CDN favicon links.
- A `<style>` block opening with the CDN typography `@import`, followed by the full brand CSS.
- A `site-header` with the dark-bg logo and three nav links.
- A `hero` section with eyebrow text (`AI ENGINEERING`), the headline, a one-sentence lede, and an orange `button-primary` reading `Book a call`.
- A `section-services` block containing a `.grid-3` of three `.card` value props.
- A `section-cta` block closing with the headline, a single CTA button, and the tagline element.
- The footer with `By ShruggieTech` and the tagline.

Body copy uses second person, no consulting-speak, no em-dashes. Saved to `./ai-engineering-services.html`.

### Example: internal launch report

**User input:**

```
I need a single HTML report I can share with the team about the Q3 launch. TOC at the top, three sections, a code sample, ship it as report.html.
```

**Expected output:**

A single `report.html` file containing:

- The same dark-default document shell as above, with `<title>` set to the report title.
- A simple eyebrow + headline + lede block at the top, no marketing hero.
- A table-of-contents block (anchor links to the three sections) styled with the eyebrow utility for the TOC header.
- Three `<section class="section">` blocks, each constrained to roughly 760px width inside the container for comfortable line length.
- One `<pre><code>` block rendering in Geist Mono via the brand stylesheet.
- The standard footer with attribution and tagline.

No CTA button on this one (the deliverable is internal, not marketing). All voice rules still apply.

## Additional Resources

- [`assets/brand.css`](assets/brand.css): authoritative brand stylesheet. Inline the whole file into the page's `<style>` block.
- [`assets/page-template.html`](assets/page-template.html): starting skeleton with all meta tags, favicon links, header, main placeholder, and footer wired up.
- [`assets/sections.md`](assets/sections.md): copyable section primitives (hero, value-props grid, two-column feature, article body, CTA block, footer variants).
- [`assets/brand-rules.md`](assets/brand-rules.md): compressed reference for token values, typography roles, logo and favicon URLs, voice rules, tagline string, and output-file rules. Consult this when you need an exact value rather than guessing.
