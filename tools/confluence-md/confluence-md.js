#!/usr/bin/env node
// confluence-md.js — CLI entry point
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { resolve, dirname, basename } from 'node:path';
import { toAdf } from './lib/to-adf.js';
import { toMd } from './lib/to-md.js';
import { resolveImages } from './lib/image-resolver.js';

const [,, command, inputPath, ...rest] = process.argv;

function showUsage() {
  console.error('Usage:');
  console.error('  confluence-md to-adf <file.md> [-o output.adf.json]');
  console.error('  confluence-md to-md <file.adf.json> [-o output.md]');
  console.error('  confluence-md publish <file.md> --page-id=ID [--message="version message"]');
  console.error('  confluence-md create <file.md> --parent-id=ID --title="Page Title"');
  console.error('  confluence-md download <page-id> [-o output.md]');
  process.exit(1);
}

if (!command || !inputPath) {
  showUsage();
}

/** Parse --key=value and --flag (boolean) from an args array. */
function parseFlags(args) {
  const flags = {};
  for (const arg of args) {
    const kv = arg.match(/^--([a-z][-a-z]*)=(.*)$/);
    if (kv) {
      flags[kv[1]] = kv[2];
      continue;
    }
    const bool = arg.match(/^--([a-z][-a-z]*)$/);
    if (bool) {
      flags[bool[1]] = true;
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
  const flags = parseFlags(rest);
  const keepH1 = 'keep-h1' in flags;

  if (command === 'to-adf') {
    outputPath ??= inputPath.replace(/\.md$/, '.adf.json');
    const md = readFileSync(inputPath, 'utf8');
    const { doc: adf, map } = toAdf(md, { stripH1: !keepH1, returnMap: true });

    // Try to resolve images via attachment lookup if --page-id given
    const pageId = flags['page-id'];
    const fileIdMap = new Map();
    if (pageId) {
      try {
        const { loadCredentials, listAttachments } = await import('./lib/confluence-api.js');
        const creds = loadCredentials();
        const attachments = await listAttachments(pageId, creds);
        for (const att of attachments) {
          fileIdMap.set(att.filename, att.fileId);
        }
      } catch (err) {
        console.error(`Warning: could not fetch attachments: ${err.message}`);
      }
    }

    const { doc: finalAdf, warnings } = resolveImages(adf, map, fileIdMap, pageId || '0');
    for (const w of warnings) {
      console.error(`Warning: ${w}`);
    }

    writeFileSync(outputPath, JSON.stringify(finalAdf, null, 2) + '\n');
    console.error(`Written: ${outputPath}`);
  } else if (command === 'to-md') {
    outputPath ??= inputPath.replace(/\.adf\.json$/, '.md');
    const json = readFileSync(inputPath, 'utf8');
    const adf = JSON.parse(json);

    // Try to resolve media IDs → filenames via attachment lookup
    const fileIdToName = new Map();
    const pageIds = extractPageIds(adf);
    if (pageIds.size > 0) {
      try {
        const { loadCredentials, listAttachments } = await import('./lib/confluence-api.js');
        const creds = loadCredentials();
        for (const pid of pageIds) {
          const attachments = await listAttachments(pid, creds);
          for (const att of attachments) {
            fileIdToName.set(att.fileId, att.filename);
          }
        }
      } catch (err) {
        console.error(`Warning: could not fetch attachments: ${err.message}`);
      }
    }

    const { md, warnings } = toMd(adf, { fileIdToName });
    for (const w of warnings) {
      console.error(`Warning: ${w}`);
    }
    writeFileSync(outputPath, md.endsWith('\n') ? md : md + '\n');
    console.error(`Written: ${outputPath}`);
  } else if (command === 'publish') {
    const pageId = flags['page-id'];
    if (!pageId) {
      console.error('Error: --page-id=ID is required for publish');
      showUsage();
    }
    const md = readFileSync(inputPath, 'utf8');
    const { doc: adf, map } = toAdf(md, { stripH1: !keepH1, returnMap: true });

    const { loadCredentials, updatePage, uploadAttachment } = await import('./lib/confluence-api.js');
    const creds = loadCredentials();

    // Upload images referenced in the document
    const mdDir = dirname(resolve(inputPath));
    const fileIdMap = new Map();
    for (const [id, entry] of map.entries()) {
      if (entry.type !== 'image') continue;
      const imgPath = resolve(mdDir, entry.content.path);
      const filename = basename(imgPath);
      if (!existsSync(imgPath)) {
        console.error(`Warning: image file not found: ${imgPath}`);
        continue;
      }
      try {
        const fileData = readFileSync(imgPath);
        const att = await uploadAttachment(pageId, filename, fileData, creds);
        fileIdMap.set(filename, att.fileId);
        console.error(`  Uploaded: ${filename} → ${att.fileId}`);
      } catch (err) {
        console.error(`Warning: failed to upload ${filename}: ${err.message}`);
      }
    }

    // Resolve image placeholders in ADF
    const { doc: finalAdf, warnings } = resolveImages(adf, map, fileIdMap, pageId);
    for (const w of warnings) {
      console.error(`Warning: ${w}`);
    }

    const result = await updatePage(pageId, finalAdf, creds, flags['message']);
    console.error(`Published "${result.title}" (version ${result.version})`);
  } else if (command === 'create') {
    const parentId = flags['parent-id'];
    const title = flags['title'];
    if (!parentId || !title) {
      console.error('Error: --parent-id=ID and --title="Page Title" are required for create');
      showUsage();
    }
    const md = readFileSync(inputPath, 'utf8');
    const { doc: adf, map } = toAdf(md, { stripH1: !keepH1, returnMap: true });

    const { loadCredentials, createPage, uploadAttachment } = await import('./lib/confluence-api.js');
    const creds = loadCredentials();

    // Create page first (need page ID for attachment uploads)
    const emptyAdf = { type: 'doc', version: 1, content: [] };
    const created = await createPage(parentId, title, emptyAdf, creds);
    const pageId = created.id;
    console.error(`Created page "${created.title}" (id: ${pageId})`);

    // Upload images
    const mdDir = dirname(resolve(inputPath));
    const fileIdMap = new Map();
    for (const [id, entry] of map.entries()) {
      if (entry.type !== 'image') continue;
      const imgPath = resolve(mdDir, entry.content.path);
      const filename = basename(imgPath);
      if (!existsSync(imgPath)) {
        console.error(`Warning: image file not found: ${imgPath}`);
        continue;
      }
      try {
        const fileData = readFileSync(imgPath);
        const att = await uploadAttachment(pageId, filename, fileData, creds);
        fileIdMap.set(filename, att.fileId);
        console.error(`  Uploaded: ${filename} → ${att.fileId}`);
      } catch (err) {
        console.error(`Warning: failed to upload ${filename}: ${err.message}`);
      }
    }

    // Resolve images and update the page with full content
    const { doc: finalAdf, warnings } = resolveImages(adf, map, fileIdMap, pageId);
    for (const w of warnings) {
      console.error(`Warning: ${w}`);
    }

    const { updatePage } = await import('./lib/confluence-api.js');
    const updated = await updatePage(pageId, finalAdf, creds, 'Initial content via confluence-md');
    console.error(`Updated "${updated.title}" (version ${updated.version})`);
  } else if (command === 'download') {
    // For download, inputPath is the page ID (not a file)
    const pageId = inputPath;

    const { loadCredentials, getPage, listAttachments } = await import('./lib/confluence-api.js');
    const creds = loadCredentials();
    const page = await getPage(pageId, creds);

    // Build fileId → filename map from page attachments
    const fileIdToName = new Map();
    try {
      const attachments = await listAttachments(pageId, creds);
      for (const att of attachments) {
        fileIdToName.set(att.fileId, att.filename);
      }
    } catch (err) {
      console.error(`Warning: could not fetch attachments: ${err.message}`);
    }

    const { md, warnings } = toMd(page.adf, { fileIdToName });
    for (const w of warnings) {
      console.error(`Warning: ${w}`);
    }
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

/** Extract page IDs from media node collection attrs in an ADF tree. */
function extractPageIds(node) {
  const ids = new Set();
  const json = JSON.stringify(node);
  const collectionRe = /contentId-(\d+)/g;
  let m;
  while ((m = collectionRe.exec(json)) !== null) {
    ids.add(m[1]);
  }
  return ids;
}
