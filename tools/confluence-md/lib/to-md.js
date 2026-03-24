// ADF → MD pipeline: preprocessAdf → package parse → postprocessMd.

import { Parser } from 'extended-markdown-adf-parser';
import { preprocessAdf } from './preprocessor.js';
import { postprocessMd } from './postprocessor.js';

const parser = new Parser();

/**
 * Convert ADF JSON to annotated Markdown.
 * @param {object} adf - ADF document JSON
 * @returns {string} Markdown text
 */
export function toMd(adf) {
  const { doc, map } = preprocessAdf(adf);
  const md = parser.adfToMarkdown(doc);
  return postprocessMd(md, map);
}
