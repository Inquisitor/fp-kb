// MD → ADF pipeline: preprocessMd → package parse → postprocessAdf.

import { Parser } from 'extended-markdown-adf-parser';
import { preprocessMd } from './preprocessor.js';
import { postprocessAdf } from './postprocessor.js';

const parser = new Parser();

/**
 * Convert annotated Markdown to ADF JSON.
 * @param {string} md - Markdown source text
 * @returns {object} ADF document
 */
export function toAdf(md) {
  const { text, map } = preprocessMd(md);
  const adf = parser.markdownToAdf(text);
  return postprocessAdf(adf, map);
}
