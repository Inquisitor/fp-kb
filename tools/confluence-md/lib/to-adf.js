// MD → ADF pipeline: preprocessMd → package parse → postprocessAdf.

import { Parser } from 'extended-markdown-adf-parser';
import { preprocessMd } from './preprocessor.js';
import { postprocessAdf } from './postprocessor.js';

const parser = new Parser();

/**
 * Convert annotated Markdown to ADF JSON.
 * @param {string} md - Markdown source text
 * @param {object} [opts]
 * @param {boolean} [opts.stripH1=true] - Remove the first top-level H1 heading
 *   (Confluence uses the page title; a duplicate H1 in the body is unwanted).
 * @returns {object} ADF document
 */
export function toAdf(md, opts = {}) {
  const { stripH1 = true } = opts;
  const { text, map } = preprocessMd(md);
  const adf = parser.markdownToAdf(text);
  const result = postprocessAdf(adf, map);
  if (stripH1) {
    removeFirstH1(result);
  }
  return result;
}

/**
 * Removes the first top-level heading[level=1] node from doc.content[].
 * Mutates the document in place.
 */
function removeFirstH1(doc) {
  if (!doc.content) return;
  const idx = doc.content.findIndex(
    n => n.type === 'heading' && n.attrs?.level === 1
  );
  if (idx !== -1) {
    doc.content.splice(idx, 1);
  }
}
