#!/usr/bin/env node
// jira-format.js — Format JIRA issue JSON into readable markdown briefing.
// Usage: node jira-format.js <issue.json>

import { readFileSync } from 'node:fs';
import { formatJiraIssue } from './lib/jira-formatter.js';

const inputPath = process.argv[2];
if (!inputPath) {
  console.error('Usage: node jira-format.js <issue.json>');
  process.exit(1);
}

try {
  const json = JSON.parse(readFileSync(inputPath, 'utf-8'));
  const md = formatJiraIssue(json);
  process.stdout.write(md);
} catch (err) {
  console.error(`Error: ${err.message}`);
  process.exit(1);
}
