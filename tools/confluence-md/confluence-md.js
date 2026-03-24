#!/usr/bin/env node
// confluence-md.js — CLI entry point
import { readFileSync, writeFileSync } from 'node:fs';
import { toAdf } from './lib/to-adf.js';
import { toMd } from './lib/to-md.js';

const [,, command, inputPath, ...rest] = process.argv;

if (!command || !inputPath) {
  console.error('Usage:');
  console.error('  confluence-md to-adf <file.md> [-o output.adf.json]');
  console.error('  confluence-md to-md <file.adf.json> [-o output.md]');
  process.exit(1);
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
  } else {
    console.error(`Unknown command: ${command}`);
    process.exit(1);
  }
} catch (err) {
  console.error(`Error: ${err.message}`);
  process.exit(1);
}
