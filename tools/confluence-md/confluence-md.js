#!/usr/bin/env node
// confluence-md.js — CLI entry point
import { readFileSync, writeFileSync } from 'node:fs';
import { toAdf } from './lib/to-adf.js';
import { toMd } from './lib/to-md.js';

const [,, command, inputPath, ...rest] = process.argv;

function showUsage() {
  console.error('Usage:');
  console.error('  confluence-md to-adf <file.md> [-o output.adf.json]');
  console.error('  confluence-md to-md <file.adf.json> [-o output.md]');
  console.error('  confluence-md publish <file.md> --page-id=ID [--message="version message"]');
  console.error('  confluence-md download <page-id> [-o output.md]');
  process.exit(1);
}

if (!command || !inputPath) {
  showUsage();
}

/** Parse --key=value flags from an args array. */
function parseFlags(args) {
  const flags = {};
  for (const arg of args) {
    const m = arg.match(/^--([a-z][-a-z]*)=(.*)$/);
    if (m) {
      flags[m[1]] = m[2];
    }
  }
  return flags;
}

const outputFlag = rest.indexOf('-o');
let outputPath;
if (outputFlag !== -1 && rest[outputFlag + 1]) {
  outputPath = rest[outputFlag + 1];
}

try {
  if (command === 'to-adf') {
    outputPath ??= inputPath.replace(/\.md$/, '.adf.json');
    const md = readFileSync(inputPath, 'utf8');
    const adf = toAdf(md);
    writeFileSync(outputPath, JSON.stringify(adf, null, 2) + '\n');
    console.error(`Written: ${outputPath}`);
  } else if (command === 'to-md') {
    outputPath ??= inputPath.replace(/\.adf\.json$/, '.md');
    const json = readFileSync(inputPath, 'utf8');
    const adf = JSON.parse(json);
    const md = toMd(adf);
    writeFileSync(outputPath, md.endsWith('\n') ? md : md + '\n');
    console.error(`Written: ${outputPath}`);
  } else if (command === 'publish') {
    const flags = parseFlags(rest);
    const pageId = flags['page-id'];
    if (!pageId) {
      console.error('Error: --page-id=ID is required for publish');
      showUsage();
    }
    const md = readFileSync(inputPath, 'utf8');
    const adf = toAdf(md);

    const { loadCredentials, updatePage } = await import('./lib/confluence-api.js');
    const creds = loadCredentials();
    const result = await updatePage(pageId, adf, creds, flags['message']);
    console.error(`Published "${result.title}" (version ${result.version})`);
  } else if (command === 'download') {
    // For download, inputPath is the page ID (not a file)
    const pageId = inputPath;

    const { loadCredentials, getPage } = await import('./lib/confluence-api.js');
    const creds = loadCredentials();
    const page = await getPage(pageId, creds);

    const md = toMd(page.adf);
    const mdOut = outputPath ?? `${pageId}.md`;
    const adfOut = mdOut.replace(/\.md$/, '.adf.json');

    writeFileSync(mdOut, md.endsWith('\n') ? md : md + '\n');
    writeFileSync(adfOut, JSON.stringify(page.adf, null, 2) + '\n');
    console.error(`Downloaded "${page.title}" (version ${page.version})`);
    console.error(`  Markdown: ${mdOut}`);
    console.error(`  ADF JSON: ${adfOut}`);
  } else {
    console.error(`Unknown command: ${command}`);
    process.exit(1);
  }
} catch (err) {
  console.error(`Error: ${err.message}`);
  process.exit(1);
}
