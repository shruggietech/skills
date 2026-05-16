/*
 * shruggie-docs document-template.js
 *
 * docx-js scaffold for the shruggie-docs skill. Reads style-spec.json and
 * doc-type-defaults.json at runtime and constructs a docx Document per the
 * layout spec. No style or layout values are hardcoded here; all values
 * come from the JSON files so the skill can be retuned without code edits.
 *
 * Usage:
 *   const { buildDocument } = require('./document-template');
 *   const doc = buildDocument({
 *     docType: 'SOW',
 *     title: 'Statement of Work',
 *     subtitle: 'Project Alpha',
 *     content: [...],          // array of section descriptors (see below)
 *     overrides: {},           // operator-supplied overrides for type defaults
 *     assetsDir: __dirname,    // absolute path to assets directory
 *     partyMetadata: {         // SOW/SOA/MSA only; key order is preserved
 *       Client: 'Acme Corp',
 *       Partner: 'Shruggie LLC',
 *       Date: 'June 1, 2026',
 *     },
 *   });
 *   const buffer = await Packer.toBuffer(doc);
 *   fs.writeFileSync(outPath, buffer);
 *   // Then run embed-fonts.py against outPath to embed the six TTFs.
 *
 * The caller is responsible for translating user-facing content into the
 * section-descriptor array. See SKILL.md for the descriptor grammar.
 */

const fs = require('fs');
const path = require('path');

let docx;
try {
  docx = require('docx');
} catch (err) {
  throw new Error(
    'docx-js is required. Run `npm install docx` in the skill execution environment, or invoke this template from a host that has the package installed.'
  );
}

const {
  Document,
  Packer,
  Paragraph,
  TextRun,
  ImageRun,
  Header,
  Footer,
  PageNumber,
  AlignmentType,
  HeightRule,
  Table,
  TableRow,
  TableCell,
  WidthType,
  BorderStyle,
  ShadingType,
  TabStopType,
  TabStopPosition,
  HorizontalPositionAlign,
  VerticalPositionAlign,
  HorizontalPositionRelativeFrom,
  VerticalPositionRelativeFrom,
  PageOrientation,
  convertInchesToTwip,
  LevelFormat,
  HeadingLevel,
} = docx;

const PT_TO_TWIP = 20;
const ptToTwip = (pt) => Math.round(pt * PT_TO_TWIP);
const ptToEmu = (pt) => Math.round(pt * 12700);

function loadJSON(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function alignmentFor(name) {
  switch (name) {
    case 'START': return AlignmentType.START;
    case 'END': return AlignmentType.END;
    case 'CENTER': return AlignmentType.CENTER;
    case 'JUSTIFY': return AlignmentType.JUSTIFIED;
    default: return AlignmentType.START;
  }
}

function measurePngAspect(pngPath) {
  const buf = fs.readFileSync(pngPath);
  if (buf.length < 24) {
    throw new Error(`PNG too small to read dimensions: ${pngPath}`);
  }
  const sig = buf.slice(0, 8).toString('hex');
  if (sig !== '89504e470d0a1a0a') {
    throw new Error(`Not a PNG: ${pngPath}`);
  }
  const width = buf.readUInt32BE(16);
  const height = buf.readUInt32BE(20);
  if (width === 0 || height === 0) {
    throw new Error(`PNG has zero dimension: ${pngPath}`);
  }
  return { width, height, aspect: width / height };
}

function roundToHalf(n) {
  return Math.round(n * 2) / 2;
}

function buildLogoParagraph(styleSpec, assetsDir) {
  const logoCfg = styleSpec.logo;
  const pngPath = path.join(assetsDir, logoCfg.path);
  const { aspect } = measurePngAspect(pngPath);
  const widthPT = logoCfg.widthPT;
  const heightPT = roundToHalf(widthPT / aspect);

  return new Paragraph({
    alignment: alignmentFor(logoCfg.alignment),
    spacing: {
      before: ptToTwip(logoCfg.marginsPT.top),
      after: ptToTwip(logoCfg.marginsPT.bottom),
    },
    indent: {
      left: ptToTwip(logoCfg.marginsPT.left),
      right: ptToTwip(logoCfg.marginsPT.right),
    },
    children: [
      new ImageRun({
        data: fs.readFileSync(pngPath),
        transformation: {
          width: ptToEmu(widthPT) / 9525,
          height: ptToEmu(heightPT) / 9525,
        },
        altText: {
          title: logoCfg.altText,
          description: logoCfg.altText,
          name: logoCfg.altText,
        },
      }),
    ],
  });
}

function styleRun(text, styleName, styleSpec, opts) {
  const s = styleSpec.styles[styleName];
  if (!s) throw new Error(`Unknown style: ${styleName}`);
  const runOpts = {
    text,
    font: s.font === 'inherit' ? undefined : s.font,
    size: s.sizePT === 'inherit' ? undefined : Math.round(s.sizePT * 2),
    bold: typeof s.weight === 'number' && s.weight >= 600,
    italics: s.italic === true,
    color: s.color === 'inherit' ? undefined : s.color,
  };
  if (opts && opts.italics) runOpts.italics = true;
  if (opts && opts.bold) runOpts.bold = true;
  return new TextRun(runOpts);
}

function styleParagraph(text, styleName, styleSpec, paragraphOpts) {
  const s = styleSpec.styles[styleName];
  if (!s) throw new Error(`Unknown style: ${styleName}`);
  const spacing = {};
  if (typeof s.spaceAbovePT === 'number') spacing.before = ptToTwip(s.spaceAbovePT);
  if (typeof s.spaceBelowPT === 'number') spacing.after = ptToTwip(s.spaceBelowPT);
  if (typeof s.lineSpacing === 'number') spacing.line = s.lineSpacing;

  const p = {
    alignment: alignmentFor(s.alignment),
    spacing,
    children: [styleRun(text, styleName, styleSpec)],
  };
  if (paragraphOpts && paragraphOpts.pageBreakBefore) p.pageBreakBefore = true;
  return new Paragraph(p);
}

function buildFooterParagraph(footerCfg, docTitle) {
  const template = footerCfg.template || footerCfg.defaultTemplate;
  const parts = [];
  const split = template.split(/(\{[A-Z_]+\})/g);
  for (const piece of split) {
    if (piece === '{PAGE}') {
      parts.push(new TextRun({ children: [PageNumber.CURRENT], font: 'Geist', size: 20, color: '6B6B6B' }));
    } else if (piece === '{NUMPAGES}') {
      parts.push(new TextRun({ children: [PageNumber.TOTAL_PAGES], font: 'Geist', size: 20, color: '6B6B6B' }));
    } else if (piece === '{DOCUMENT_TITLE}') {
      parts.push(new TextRun({ text: docTitle, font: 'Geist', size: 20, color: '6B6B6B' }));
    } else if (piece.length > 0) {
      parts.push(new TextRun({ text: piece, font: 'Geist', size: 20, color: '6B6B6B' }));
    }
  }
  return new Paragraph({
    alignment: alignmentFor(footerCfg.alignment || 'END'),
    children: parts,
  });
}

function buildHorizontalRule(styleSpec) {
  const r = styleSpec.horizontalRule;
  return new Paragraph({
    spacing: {
      before: ptToTwip(r.spaceAbovePT),
      after: ptToTwip(r.spaceBelowPT),
    },
    border: {
      bottom: {
        color: r.color,
        space: 1,
        style: BorderStyle.SINGLE,
        size: Math.max(1, Math.round(r.weightPT * 8)),
      },
    },
    children: [],
  });
}

function renderContent(content, styleSpec) {
  const out = [];
  for (const node of content) {
    switch (node.type) {
      case 'title':
        out.push(styleParagraph(node.text, 'TITLE', styleSpec));
        break;
      case 'subtitle':
        out.push(styleParagraph(node.text, 'SUBTITLE', styleSpec));
        break;
      case 'h1':
        out.push(styleParagraph(node.text, 'H1', styleSpec, { pageBreakBefore: node.pageBreakBefore }));
        break;
      case 'h2':
        out.push(styleParagraph(node.text, 'H2', styleSpec));
        break;
      case 'h3':
        out.push(styleParagraph(node.text, 'H3', styleSpec));
        break;
      case 'h4':
        out.push(styleParagraph(node.text, 'H4', styleSpec));
        break;
      case 'h5':
        out.push(styleParagraph(node.text, 'H5', styleSpec));
        break;
      case 'h6':
        out.push(styleParagraph(node.text, 'H6', styleSpec));
        break;
      case 'body':
        out.push(styleParagraph(node.text, 'Body', styleSpec));
        break;
      case 'eyebrow':
        out.push(styleParagraph((node.text || '').toUpperCase(), 'EyebrowLabel', styleSpec));
        break;
      case 'caption':
        out.push(styleParagraph(node.text, 'Caption', styleSpec));
        break;
      case 'hr':
        out.push(buildHorizontalRule(styleSpec));
        break;
      case 'pageBreak':
        out.push(new Paragraph({ children: [], pageBreakBefore: true }));
        break;
      case 'bullets':
        for (const item of node.items) {
          out.push(new Paragraph({
            alignment: AlignmentType.START,
            bullet: { level: 0 },
            spacing: { after: ptToTwip(4), line: 276 },
            children: [styleRun(item, 'BulletListItem', styleSpec)],
          }));
        }
        break;
      case 'numbered':
        for (let i = 0; i < node.items.length; i++) {
          out.push(new Paragraph({
            alignment: AlignmentType.START,
            numbering: { reference: node.reference || 'default-numbered', level: 0 },
            spacing: { after: ptToTwip(4), line: 276 },
            children: [styleRun(node.items[i], 'NumberedListItem', styleSpec)],
          }));
        }
        break;
      case 'codeBlock':
        out.push(new Paragraph({
          alignment: AlignmentType.START,
          spacing: { before: ptToTwip(4), after: ptToTwip(4), line: 276 },
          shading: { type: ShadingType.CLEAR, fill: 'F5F5F5', color: 'auto' },
          children: [styleRun(node.text, 'CodeBlock', styleSpec)],
        }));
        break;
      case 'table':
        out.push(buildTable(node, styleSpec));
        break;
      case 'raw':
        if (node.paragraph instanceof Paragraph) out.push(node.paragraph);
        break;
      default:
        throw new Error(`Unknown content node type: ${node.type}`);
    }
  }
  return out;
}

function buildTable(node, styleSpec) {
  const tableCfg = styleSpec.table;
  const rows = [];
  if (node.header) {
    rows.push(new TableRow({
      tableHeader: true,
      children: node.header.map((cellText) => new TableCell({
        shading: { type: ShadingType.CLEAR, fill: tableCfg.headerRow.backgroundColor, color: 'auto' },
        children: [new Paragraph({
          alignment: AlignmentType.START,
          children: [new TextRun({
            text: cellText,
            font: tableCfg.headerRow.font,
            size: Math.round(tableCfg.headerRow.sizePT * 2),
            bold: tableCfg.headerRow.weight >= 600,
            color: tableCfg.headerRow.color,
          })],
        })],
      })),
    }));
  }
  for (const row of node.rows) {
    rows.push(new TableRow({
      children: row.map((cellText) => new TableCell({
        children: [new Paragraph({
          alignment: AlignmentType.START,
          children: [styleRun(String(cellText), 'TableCell', styleSpec)],
        })],
      })),
    }));
  }
  return new Table({
    rows,
    width: { size: 100, type: WidthType.PERCENTAGE },
    borders: {
      top: { style: BorderStyle.SINGLE, size: 4, color: tableCfg.defaultBorder.color },
      bottom: { style: BorderStyle.SINGLE, size: 4, color: tableCfg.defaultBorder.color },
      left: { style: BorderStyle.SINGLE, size: 4, color: tableCfg.defaultBorder.color },
      right: { style: BorderStyle.SINGLE, size: 4, color: tableCfg.defaultBorder.color },
      insideHorizontal: { style: BorderStyle.SINGLE, size: 4, color: tableCfg.defaultBorder.color },
      insideVertical: { style: BorderStyle.SINGLE, size: 4, color: tableCfg.defaultBorder.color },
    },
  });
}

function buildPartyMetadataBlock(partyMetadata, styleSpec) {
  const TAB_STOP_TWIP = ptToTwip(108);
  const paragraphs = [];
  for (const [label, value] of Object.entries(partyMetadata)) {
    paragraphs.push(new Paragraph({
      alignment: AlignmentType.START,
      tabStops: [{ type: TabStopType.LEFT, position: TAB_STOP_TWIP }],
      children: [
        new TextRun({ text: label + ':', font: 'Geist', size: 22, color: '0A0A0A' }),
        new TextRun({ text: '\t' }),
        new TextRun({ text: value, font: 'Geist', size: 22, color: '0A0A0A' }),
      ],
    }));
  }
  return paragraphs;
}

function buildDocument({ docType, title, subtitle, content, overrides, assetsDir, partyMetadata }) {
  if (!assetsDir) {
    throw new Error('assetsDir is required (absolute path to the skill assets directory).');
  }
  const styleSpec = loadJSON(path.join(assetsDir, 'style-spec.json'));
  const typeDefaults = loadJSON(path.join(assetsDir, 'doc-type-defaults.json'));
  const typeCfg = typeDefaults.documentTypes[docType];
  if (!typeCfg) {
    throw new Error(`Unknown document type: ${docType}. Valid types: ${Object.keys(typeDefaults.documentTypes).join(', ')}`);
  }
  const resolved = Object.assign({}, typeCfg, overrides || {});

  const sectionChildren = [];
  sectionChildren.push(buildLogoParagraph(styleSpec, assetsDir));

  if (resolved.topBlock === 'title-subtitle') {
    if (title) sectionChildren.push(styleParagraph(title, 'TITLE', styleSpec));
    if (subtitle) sectionChildren.push(styleParagraph(subtitle, 'SUBTITLE', styleSpec));
    if (resolved.partyMetadataAfterTitle === true && partyMetadata && Object.keys(partyMetadata).length > 0) {
      sectionChildren.push(buildHorizontalRule(styleSpec));
      sectionChildren.push(...buildPartyMetadataBlock(partyMetadata, styleSpec));
      sectionChildren.push(buildHorizontalRule(styleSpec));
    }
  }

  if (Array.isArray(content) && content.length > 0) {
    sectionChildren.push(...renderContent(content, styleSpec));
  }

  if (resolved.taglineInFooter !== true && resolved.taglineInBody === true) {
    sectionChildren.push(styleParagraph("¯\\_(ツ)_/¯ We'll figure it out.", 'Body', styleSpec));
  }

  const footerCfg = Object.assign({}, styleSpec.footer, {
    template: resolved.footerTemplate || styleSpec.footer.defaultTemplate,
    alignment: resolved.footerAlignment || styleSpec.footer.alignment,
  });

  const doc = new Document({
    creator: 'Shruggie LLC',
    title: title || resolved.label,
    description: resolved.label,
    styles: {
      default: {
        document: {
          run: { font: 'Geist', size: 22, color: '0A0A0A' },
        },
      },
    },
    numbering: {
      config: [
        {
          reference: 'default-numbered',
          levels: [
            {
              level: 0,
              format: LevelFormat.DECIMAL,
              text: '%1.',
              alignment: AlignmentType.START,
              style: { paragraph: { indent: { left: ptToTwip(18), hanging: ptToTwip(18) } } },
            },
          ],
        },
      ],
    },
    sections: [
      {
        properties: {
          page: {
            size: {
              width: ptToTwip(styleSpec.page.sizePT.width),
              height: ptToTwip(styleSpec.page.sizePT.height),
              orientation: PageOrientation.PORTRAIT,
            },
            margin: {
              top: ptToTwip(styleSpec.page.marginsPT.top),
              bottom: ptToTwip(styleSpec.page.marginsPT.bottom),
              left: ptToTwip(styleSpec.page.marginsPT.left),
              right: ptToTwip(styleSpec.page.marginsPT.right),
            },
          },
        },
        footers: {
          default: new Footer({
            children: [buildFooterParagraph(footerCfg, title || resolved.label)],
          }),
        },
        children: sectionChildren,
      },
    ],
  });
  return doc;
}

module.exports = {
  buildDocument,
  Packer,
  measurePngAspect,
  roundToHalf,
  ptToTwip,
  ptToEmu,
};
