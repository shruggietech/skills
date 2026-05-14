---
name: shruggie-docs
description: Build a single self-contained .docx file using the official ShruggieTech parent-brand identity (light-surface color tokens, Space Grotesk and Geist typography embedded into the file, justified body text, brand-correct title color, lightbg logo). Use whenever the user asks for a Word document, contract, statement of work, scope of work agreement, master subcontract agreement, internal report, invoice, or letter that should read as a ShruggieTech artifact. Trigger on phrasings like "make me a docx", "draft a Statement of Work", "produce a Master Subcontract", "send an invoice for", "write a letter to", or any .docx request that touches a ShruggieTech, Shruggie LLC, or parent-brand surface. The skill collaborates with the operator on document-type selection, TOC inclusion, signatories, and any field that carries legal weight; default to asking the human rather than guessing. Skip for Google Docs API output, PDF generation, slide decks, spreadsheets, and React or Next.js component work.
disable-model-invocation: false
---

# Shruggie Docs

Produce a single self-contained `.docx` file that conforms to the ShruggieTech parent-brand identity. The skill bundles the brand color tokens, typography (six TTFs), the lightbg logo bytes, the layout invariants, and the style spec so Claude can emit on-brand Word documents without re-deriving any of them per task. Every generated `.docx` has the six brand TTFs embedded into the archive so recipients without Geist or Space Grotesk installed still render the document with the correct typography. The skill governs six document types: Statement of Work (SOW), Scope of Work Agreement (SOA), Master Subcontract Agreement (MSA), Internal Report, Invoice, and Letter.

## When to Use

Invoke this skill when:

- The user asks for a Word document, `.docx`, or any Word-format deliverable in a ShruggieTech, Shruggie LLC, or parent-brand context.
- The user names a Statement of Work, Scope of Work Agreement, Master Subcontract Agreement, Internal Report, Invoice, or Letter and wants it as a Word file.
- The user iterates on the content of an existing on-brand `.docx` and wants the next revision built the same way.

Do not invoke this skill for:

- Google Docs API output (a separate skill is planned).
- PDF generation (use the appropriate PDF skill or convert from `.docx` downstream).
- Slide decks (`.pptx`) and spreadsheets (`.xlsx`).
- React, Next.js, Svelte, Vue, or other component-framework work.
- Pages that are primarily about a product sub-brand (metadexer, Covarity, Knox.Dance, SparkPlan, rustif, shruggie-indexer, shruggie-feedtools). Each sub-brand maintains its own visual identity. If a parent-brand document mentions a sub-brand in passing that is fine; if the document is mostly about the sub-brand, flag the scope conflict and ask whether to defer to the sub-brand's own system.
- Reformatting the existing SOW/SOA/MSA contract corpus retroactively. The skill governs new documents only.

## Instructions

The skill's deliverable is always a single `.docx` file with the six brand TTFs embedded inside the archive. The production code path reads only from local bundled assets (`assets/brand/`, `assets/fonts/`); the CDN URLs in `assets/brand-rules.md` document the canonical origin of those bundled bytes and never appear in the build path.

### Toolchain

Generation runs on top of `docx-js` (the npm `docx` package). The skill bundles a docx-js scaffold at `assets/document-template.js` and a font-embedding post-process at `assets/embed-fonts.py`. The public `docx` skill at `/mnt/skills/public/docx/` (when present in the execution environment) provides `scripts/office/validate.py` for the final OOXML pass; if the public skill is not available, the embed script's built-in `--verify-only` check is the minimum acceptable verification.

Output encoding is UTF-8 without BOM for any text artifact the skill writes. The `.docx` itself is a ZIP archive; the UTF-8 rule applies to the skill source files in `assets/`.

### Collaboration rule (binding)

Document type selection and the most-overridden parameters are operator-collaborative by default. Ask the human operator before committing to any of these:

- Which of the six document types the request maps to, when the request is ambiguous. For example, "draft a contract" maps equally to SOW, SOA, or MSA.
- Whether to include a table of contents, even when the default for the chosen type would auto-include one.
- Signatory names, titles, and party identification on any document carrying legal weight (SOW, SOA, MSA, Letter, Invoice).
- Currency, payment terms, and tax handling for Invoice.

Defaults in `assets/doc-type-defaults.json` exist as fallbacks for unattended runs (batch generation, CI pipelines), not as the preferred path. A confused generation produced from defaults is a worse outcome than a clarifying question.

### Brand fidelity

The five immutable brand color tokens are `#000000` (Black), `#2BCC73` (Green Bright), `#00AB21` (Green Deep), `#FF5300` (Orange), and `#D1D3D4` (Gray Light). Their hex values do not change. The full token set, including the extended gray palette, is in `assets/brand-rules.md` and the machine-readable `assets/style-spec.json`.

Light-surface accessibility rule (binding): Green Bright fails WCAG AA on white paper (roughly 2.4:1). Green Bright must not appear anywhere in any document the skill produces. Every accent that would be Green Bright on a dark surface substitutes to Green Deep on the light surface that `.docx` output renders on.

### Typography

Three families, all loaded from `assets/fonts/` and embedded into every emitted `.docx`:

- Space Grotesk 500 (Medium) and 700 (Bold): TITLE, H1, H2 use 700; H3, H4, H5, H6 use 500.
- Geist 400 (Regular) and 500 (Medium): Body uses 400; inline bold within body uses 500.
- Geist Mono 400: code blocks, inline code, eyebrow labels.

Italic policy: only base `Geist-Italic.ttf` ships. Do not attempt bold-italic combinations. Use italic sparingly in prose only. The six TTFs in `assets/fonts/` are the complete embed list; do not embed Geist Pixel and do not embed Geist weights other than 400, 500, and base italic.

System fonts (Arial, Calibri, Times New Roman, Inter) are graceful-degradation fallbacks only. Never specify Arial or Calibri as a primary face in any style.

### Document layout (invariants)

- Page size: US Letter portrait, 612 PT x 792 PT (8.5 inch x 11 inch).
- Margins: 36 PT top, 54 PT bottom, 36 PT left, 36 PT right.
- One section, continuous; no header; one right-aligned footer.
- Logo first paragraph of every document: width 180 PT, height computed at build time from the bundled PNG's native aspect ratio rounded to the nearest 0.5 PT, 9 PT margins on all four sides, alt text `ShruggieTech`. The logo is always loaded from `assets/brand/logo/logo-lightbg.png` on disk; never request it from the CDN.

### Justification rule (binding)

All paragraph body text uses JUSTIFY alignment. This applies to every paragraph rendered with the Body style. It does NOT apply to:

- Bullet list items (left-aligned).
- Numbered list items (left-aligned).
- Table cell text (left-aligned).
- Footer text (right-aligned per the footer spec).
- Headings (left-aligned per the style spec; TITLE and SUBTITLE are centered).
- Captions (centered).
- Eyebrow labels (left-aligned).
- Recipient blocks in letters (left-aligned).
- Sender and bill-to blocks in invoices (left-aligned).

The justified body is part of the ShruggieTech document layout standard. Verify in the pre-output checklist.

### Document-type behaviors

| Type | TOC default | Top block | Footer | Tagline in footer |
|---|---|---|---|---|
| SOW | yes | TITLE + SUBTITLE | standard | no |
| SOA | yes | TITLE + SUBTITLE | standard | no |
| MSA | yes | TITLE + SUBTITLE | standard | no |
| Internal Report | no | TITLE + SUBTITLE | standard | yes |
| Invoice | no | invoice header block | invoice (payment terms) | no |
| Letter | no | date + recipient + subject | minimal (omit on single page) | no |

The full table with `pageBreakRule` and other fields is in `assets/doc-type-defaults.json`. Invoice and Letter layouts have type-specific top blocks documented in detail in that file and in the handoff brief.

### Voice rules

Every line of copy the skill emits follows these:

1. Second person. Speak to the reader. The reader is the subject, not the company.
2. No competitive jabs. Do not name competitors. Vendor-displacement narratives are fine as positioning; named attacks are not.
3. No unsubstantiated claims. A capability appears in copy only if it can be backed by concrete work.
4. Confidence without arrogance. State plainly. Avoid `we might be able to help` and avoid `industry-leading experts`.
5. Plain English over consulting-speak. No `synergy`, `leverage`, `best-in-class`, `turnkey`, `solutioning`.
6. Humor is permitted in small doses. The shruggie identity invites a wry self-aware tone; do not force it.

If the operator supplies draft copy that violates a rule, surface the conflict and ask before silently rewriting.

### Tagline and attribution

The exact tagline string is `¯\_(ツ)_/¯ We'll figure it out.` Use only in marketing-adjacent documents (Internal Report covers, capabilities one-pagers). Do not paraphrase. Do not place in legal documents (SOW, SOA, MSA), where tone calls for a more formal close.

Attribution conventions:

- `By ShruggieTech` (default footer attribution).
- `A ShruggieTech product` (marketing copy in capabilities documents).
- `Shruggie LLC` (legal-entity attribution; appears in license headers, copyright notices, contract parties, invoice sender block).

The legal name `Shruggie LLC` appears in any document that carries legal weight. The DBA `ShruggieTech` appears in marketing prose, capability descriptions, and operational copy.

### Output hygiene

Every file the skill writes (the `.docx`, this `SKILL.md`, the JSON specs, the JS scaffold, the Python embed script):

- UTF-8 encoding, no BOM.
- LF line endings (not CRLF) for any text file in the skill repo.
- No trailing whitespace on any line in text files.
- A single trailing newline at end of every text file.
- No em-dashes and no en-dashes anywhere in the document, including comments, alt text, footer template strings, and prose. Use parentheses, commas, or standard hyphens instead.
- Every image has meaningful alt text. Decorative-only images are not used in document templates.

### Build procedure

When the operator has confirmed scope (document type, TOC inclusion, signatories, currency for invoices) and you are ready to emit the file:

1. Resolve the document type. Read `assets/doc-type-defaults.json` for the type's defaults (TOC, footer template, page-break rule, tagline inclusion). If anything is ambiguous, ask the operator per the collaboration rule.
2. Read `assets/style-spec.json` to materialize the named-styles map.
3. Construct a `Document` via docx-js using `assets/document-template.js` as the scaffold. Pass `assetsDir` to `buildDocument` so the template can locate the bundled logo and JSON specs.
4. The scaffold configures page size, margins, section, no header, and the right-aligned footer per the resolved type. The first paragraph is the lightbg logo at 180 PT width with build-time-computed height and 9 PT margins on all four sides.
5. Insert the type-appropriate top block: TITLE plus optional SUBTITLE for SOW/SOA/MSA/Internal Report, header block for Invoice, date plus recipient block for Letter.
6. Insert optional TOC (per resolved decision), then body content. The scaffold applies the named-styles map; do not write per-paragraph overrides except for explicit operator-supplied formatting in the body content.
7. Pack the `.docx` with `Packer.toBuffer(doc)` and write the buffer to disk.
8. Run the font-embedding post-process: `python assets/embed-fonts.py <path-to-docx>`. This drops the six bundled TTFs into `word/fonts/`, patches `word/fontTable.xml` to reference each embed, updates `word/_rels/document.xml.rels`, and sets the embed flag in `word/settings.xml`. This step is mandatory; there is no flag to skip it.
9. Validate the final file. Prefer `python /mnt/skills/public/docx/scripts/office/validate.py <path>` when the public docx skill is available in the execution environment. Otherwise, rely on the embed script's `--verify-only` check, which confirms the six TTFs are present in the archive and referenced in `fontTable.xml`.
10. Write to the path the operator specified, or to `./<slug>.docx` where the slug derives from the document title (lowercase, hyphenated).

### Pre-output checklist

Before writing the final file, verify:

- Page size is 612 PT x 792 PT, portrait.
- Margins are exactly 36 PT top, 54 PT bottom, 36 PT left, 36 PT right.
- The first paragraph contains the lightbg logo with width 180 PT, height computed from the bundled PNG's native aspect ratio, and 9 PT margins on all sides. The logo was loaded from `assets/brand/logo/logo-lightbg.png` on disk, not from the CDN.
- TITLE (for SOW, SOA, MSA, Internal Report) uses Space Grotesk 700, 24 PT, color `#00AB21`, centered. Invoice and Letter skip this check because they use document-type-specific top blocks.
- Every body paragraph uses JUSTIFY alignment. List items, table cells, headings, captions, eyebrow labels, footer text, recipient blocks (letters), and sender / bill-to blocks (invoices) are exempted per the justification rule.
- No Body paragraph uses Arial, Inter, Calibri, or Times New Roman. Body is Geist throughout.
- Headings are Space Grotesk (500 or 700 per the style spec).
- Footer matches the per-type footer rule (standard for contracts and reports, payment-terms for invoices, minimal or absent for letters) using OOXML `PAGE` and `NUMPAGES` field codes where page numbers are rendered.
- Green Bright (`#2BCC73`) does not appear anywhere in the document.
- If TOC is included, it renders before any H1 and uses Space Grotesk Medium for TOC entry text.
- The unpacked archive contains all six TTFs under `word/fonts/`, and `word/fontTable.xml` references each one with the appropriate `<w:embedRegular>`, `<w:embedBold>`, or `<w:embedItalic>` element.
- The unpacked archive contains no font files for Geist Pixel or for Geist weights other than 400, 500, and base italic.
- The validator (public docx skill or the embed script's `--verify-only`) returns a clean pass.

## Examples

### Example: Statement of Work

**User input:**

```
Draft a SOW for the Acme observability engagement. Six-week phase, fixed price, two milestones, signatures at the bottom.
```

**Expected output:**

A single `.docx` file containing:

- The lightbg logo as the first paragraph, 180 PT wide, 9 PT margins.
- TITLE: `Statement of Work`, Space Grotesk 700, 24 PT, Green Deep, centered.
- SUBTITLE: `Acme Observability Engagement`, Geist 14 PT, Gray 600, centered.
- A table of contents (default for SOW).
- Numbered sections (`1. Engagement Summary`, `2. Scope`, `3. Deliverables`, `4. Milestones and Schedule`, `5. Fees and Payment`, `6. Acceptance Criteria`, `7. Signatures`) with H1 headings.
- Body paragraphs all justified, Geist 11 PT.
- A two-row signature block at the end (Shruggie LLC and Acme), party names and titles supplied by the operator.
- Footer right-aligned: `Statement of Work - Page X of Y`, Geist 10 PT, Gray 600.
- Six TTFs embedded into the archive under `word/fonts/`.

Saved to `./acme-observability-sow.docx`.

### Example: Invoice

**User input:**

```
Make me an invoice for $4,800 to Acme Corp for the November observability work. Net 30, no tax.
```

**Expected output:**

A single `.docx` file containing:

- The lightbg logo as the first paragraph.
- Two-column borderless header table: left column has `Shruggie LLC` plus mailing address, email, phone (left-aligned, Geist 11 PT body). Right column has eyebrow labels `INVOICE #`, `ISSUE DATE`, `DUE DATE` with the corresponding values in Body Bold, right-aligned.
- Below the header, `BILL TO:` eyebrow label followed by Acme Corp's name and address.
- Line-items table: columns `DESCRIPTION`, `QTY`, `RATE`, `AMOUNT`. One row for the November observability work at $4,800. Borders Gray 200 0.5 PT. Header row Gray 100 background, Geist Medium 10 PT.
- Summary rows: Subtotal `$4,800.00`, Total `$4,800.00` (Tax row omitted because tax is zero). Total row has a single top border in Gray 950, 1 PT.
- Horizontal rule, then payment-terms block: `Net 30 from issue date`, accepted methods bullet list, remit-to address matching the sender block, contact email.
- Footer right-aligned: `Shruggie LLC | Invoice {INVOICE_NUMBER} | Payment terms: Net 30 from issue date`. Page numbers only render if the invoice spans more than one page.
- Six TTFs embedded.

Saved to `./acme-corp-november-invoice.docx`.

## Additional Resources

- [`assets/brand-rules.md`](assets/brand-rules.md): light-surface brand reference. Color tokens, typography, voice rules, tagline, attribution, sub-brand exclusion list, output file rules. Consult this when you need an exact value rather than guessing.
- [`assets/style-spec.json`](assets/style-spec.json): machine-readable named-styles map. Authoritative source for every style the document scaffold materializes (TITLE, SUBTITLE, H1 through H6, Body, lists, table cells, code, eyebrow, footer, caption, hyperlink, horizontal rule, table default). The scaffold reads this file rather than hardcoding values.
- [`assets/doc-type-defaults.json`](assets/doc-type-defaults.json): per-document-type defaults (TOC, top block, footer, page-break rule, tagline inclusion) for SOW, SOA, MSA, Internal Report, Invoice, and Letter. Includes the binding `operatorCollaborationRequired` block and the invoice line-items table spec.
- [`assets/document-template.js`](assets/document-template.js): docx-js scaffold. Exports `buildDocument({ docType, title, subtitle, content, overrides, assetsDir })` plus helpers (`Packer`, `measurePngAspect`, `roundToHalf`, `ptToTwip`, `ptToEmu`). No layout or style values are hardcoded; everything comes from the JSON files.
- [`assets/embed-fonts.py`](assets/embed-fonts.py): post-generation font embedding. Unpacks the `.docx`, drops the six bundled TTFs into `word/fonts/`, patches `word/fontTable.xml` and `word/_rels/document.xml.rels`, sets the embed flag in `word/settings.xml`, and repacks. Has a `--verify-only` mode for sanity-checking an already-embedded file.
- [`assets/brand/logo/logo-lightbg.png`](assets/brand/logo/logo-lightbg.png): byte-identical local copy of `https://cdn.shruggie.tech/brand/logo/logo-lightbg.png`. The build path reads from this file on disk; the CDN URL exists only to trace the canonical origin.
- [`assets/fonts/`](assets/fonts/): byte-identical local copies of the six TTFs from `https://cdn.shruggie.tech/brand/fonts/ttf/` (SpaceGrotesk-Medium, SpaceGrotesk-Bold, Geist-Regular, Geist-Medium, Geist-Italic, GeistMono-Regular). These are the complete embed list; refresh them when the CDN updates.
