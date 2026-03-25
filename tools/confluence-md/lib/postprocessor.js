// Post-processors: replace CFMD_* placeholders with final output.
//
// postprocessAdf(doc, map) — placeholders → ADF extension nodes (MD→ADF direction)
// postprocessMd(text, map)  — placeholders → LaTeX/TOC syntax   (ADF→MD direction)

import { makeNode as makeMathNode } from './math-adapter.js';

const MACRO_TYPE = 'com.atlassian.confluence.macro.core';

// Matches any CFMD placeholder token in text.
const ANY_PLACEHOLDER_RE = /CFMD_(?:MATHINL|MATHBLK|TOC)_\d{4}/g;

/**
 * Walks the ADF JSON tree and replaces placeholder tokens with
 * the corresponding Confluence extension nodes.
 * Returns a new tree — does not mutate the input.
 */
export function postprocessAdf(doc, map) {
  const result = JSON.parse(JSON.stringify(doc));
  walkAndReplace(result, map);
  return result;
}

/**
 * Recursively processes node.content[], performing block-level and
 * inline-level placeholder replacements in place.
 */
function walkAndReplace(node, map) {
  if (!node.content) return;

  for (let i = 0; i < node.content.length; i++) {
    const child = node.content[i];

    // Block-level: paragraph whose sole child is a single placeholder text node.
    if (child.type === 'paragraph' && isSolePlaceholderParagraph(child, map)) {
      const text = child.content[0].text.trim();
      const entry = map.get(text);
      node.content[i] = buildBlockNode(text, entry);
      continue;
    }

    // Inline-level: text nodes that contain placeholder substrings.
    if (child.content) {
      expandInlinePlaceholders(child, map);
    }

    // Recurse into children.
    walkAndReplace(child, map);
  }
}

/**
 * Returns true when a paragraph has exactly one text child whose entire
 * text is a single CFMD_MATHBLK or CFMD_TOC placeholder.
 */
function isSolePlaceholderParagraph(para, map) {
  if (!para.content || para.content.length !== 1) return false;
  const child = para.content[0];
  if (child.type !== 'text') return false;
  const text = child.text.trim();
  const entry = map.get(text);
  if (!entry) return false;
  return entry.type === 'mathblk' || entry.type === 'toc';
}

/**
 * Builds a block-level replacement node for mathblk or toc placeholders.
 */
function buildBlockNode(id, entry) {
  if (entry.type === 'mathblk') {
    return makeMathNode(entry.content, 'block');
  }
  // toc
  return {
    type: 'extension',
    attrs: {
      extensionType: MACRO_TYPE,
      extensionKey: 'toc',
      parameters: {},
    },
  };
}

/**
 * Scans text children of a node for inline placeholders and splits them
 * into [text, inlineExtension, text, ...] sequences.
 */
function expandInlinePlaceholders(node, map) {
  if (!node.content) return;

  const newContent = [];
  for (const child of node.content) {
    if (child.type !== 'text') {
      newContent.push(child);
      continue;
    }
    const expanded = splitTextByPlaceholders(child, map);
    newContent.push(...expanded);
  }
  node.content = newContent;
}

/**
 * Splits a text node that may contain inline placeholder tokens into an
 * array of text nodes and inlineExtension nodes.
 * Preserves marks from the original text node on the resulting text fragments.
 */
function splitTextByPlaceholders(textNode, map) {
  const text = textNode.text;
  const marks = textNode.marks;

  // Use a fresh regex instance per call to avoid shared lastIndex state.
  const re = new RegExp(ANY_PLACEHOLDER_RE.source, 'g');

  const parts = [];
  let lastEnd = 0;
  let match;

  while ((match = re.exec(text)) !== null) {
    const id = match[0];
    const entry = map.get(id);
    if (!entry || entry.type !== 'mathinl') {
      // Not an inline placeholder — leave as-is.
      continue;
    }

    // Text before the placeholder.
    if (match.index > lastEnd) {
      parts.push(makeTextNode(text.slice(lastEnd, match.index), marks));
    }

    // The inline extension node (via math adapter).
    parts.push(makeMathNode(entry.content, 'inline'));

    lastEnd = match.index + id.length;
  }

  // If no inline placeholders were found, return the original node as-is.
  if (parts.length === 0) return [textNode];

  // Trailing text after last placeholder.
  if (lastEnd < text.length) {
    parts.push(makeTextNode(text.slice(lastEnd), marks));
  }

  return parts;
}

/**
 * Creates a text ADF node, optionally carrying over marks.
 */
function makeTextNode(text, marks) {
  const node = { type: 'text', text };
  if (marks) node.marks = marks;
  return node;
}

// ---------------------------------------------------------------------------
// Markdown post-processor (for ADF→MD pipeline)
// ---------------------------------------------------------------------------

/**
 * Replaces CFMD_* placeholder tokens in Markdown text with the
 * corresponding LaTeX math or TOC syntax.
 *
 * @param {string} text - Markdown text containing placeholders.
 * @param {PlaceholderMap} map - The placeholder map from preprocessAdf.
 * @returns {string}
 */
export function postprocessMd(text, map) {
  for (const [id, entry] of map.entries()) {
    if (!text.includes(id)) continue;

    let replacement;
    switch (entry.type) {
      case 'mathinl':
        replacement = '$' + entry.content + '$';
        break;
      case 'mathblk':
        replacement = '$$\n' + entry.content + '\n$$';
        break;
      case 'toc':
        replacement = '<!-- {toc} -->';
        break;
      default:
        continue;
    }
    // Use a replacer function to avoid $-special-character interpretation
    // in the replacement string (e.g. $$ → $ in String.replace).
    text = text.replace(id, () => replacement);
  }
  return text;
}
