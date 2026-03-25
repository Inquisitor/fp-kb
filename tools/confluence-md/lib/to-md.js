// ADF → MD pipeline: preprocessAdf → package parse → postprocessMd.

import { Parser } from 'extended-markdown-adf-parser';
import { preprocessAdf } from './preprocessor.js';
import { postprocessMd } from './postprocessor.js';
import { downgradeJiraLinks } from './jira-links.js';
import { downgradeImages } from './image-downgrader.js';

const parser = new Parser();

/**
 * Convert ADF JSON to annotated Markdown.
 * @param {object} adf - ADF document JSON
 * @param {object} [opts]
 * @param {Map<string,string>} [opts.fileIdToName] - fileId → filename map for image resolution
 * @returns {{ md: string, warnings: string[] }}
 */
export function toMd(adf, opts = {}) {
  const { fileIdToName } = opts;
  const { doc: imgDowngraded, warnings } = downgradeImages(adf, fileIdToName);
  const jiraDowngraded = downgradeJiraLinks(imgDowngraded);
  const { doc, map } = preprocessAdf(jiraDowngraded);
  const md = parser.adfToMarkdown(doc);
  return { md: postprocessMd(md, map), warnings };
}
