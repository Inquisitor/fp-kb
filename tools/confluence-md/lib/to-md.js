// ADF → MD pipeline: preprocessAdf → package parse → postprocessMd.

import { Parser } from 'extended-markdown-adf-parser';
import { preprocessAdf } from './preprocessor.js';
import { postprocessMd } from './postprocessor.js';
import { downgradeJiraLinks } from './jira-links.js';

const parser = new Parser();

/**
 * Convert ADF JSON to annotated Markdown.
 * @param {object} adf - ADF document JSON
 * @returns {string} Markdown text
 */
export function toMd(adf) {
  const downgraded = downgradeJiraLinks(adf);
  const { doc, map } = preprocessAdf(downgraded);
  const md = parser.adfToMarkdown(doc);
  return postprocessMd(md, map);
}
