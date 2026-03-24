// Pre-processor: extracts LaTeX math and TOC markers from Markdown,
// replacing them with CFMD_* placeholders safe for the ADF parser.

import { PlaceholderMap } from './placeholder.js';

/**
 * Identifies byte ranges occupied by code fences and inline code spans.
 * Content inside these ranges must not be treated as math or TOC.
 * Returns a sorted array of [start, end) pairs.
 */
function findProtectedRanges(text) {
  const ranges = [];

  // Code fences: ``` ... ``` (possibly with info string)
  const fenceRe = /^(`{3,})[^\n]*\n([\s\S]*?)^\1\s*$/gm;
  for (const m of text.matchAll(fenceRe)) {
    ranges.push([m.index, m.index + m[0].length]);
  }

  // Inline code spans: `...` (non-greedy, single line)
  const codeSpanRe = /`[^`\n]+`/g;
  for (const m of text.matchAll(codeSpanRe)) {
    // Only count if not already inside a fence range
    const start = m.index;
    const end = start + m[0].length;
    if (!ranges.some(([rs, re]) => start >= rs && end <= re)) {
      ranges.push([start, end]);
    }
  }

  ranges.sort((a, b) => a[0] - b[0]);
  return ranges;
}

/**
 * Returns true if the character position falls inside any protected range.
 */
function isProtected(pos, ranges) {
  for (const [start, end] of ranges) {
    if (pos >= start && pos < end) return true;
    if (start > pos) break; // ranges are sorted
  }
  return false;
}

/**
 * Pre-processes Markdown text: extracts LaTeX math and TOC comments,
 * replacing them with CFMD_* placeholder tokens.
 *
 * Extraction order: block math → inline math → TOC.
 * Code fences and inline code spans are protected from extraction.
 *
 * @param {string} text - Raw Markdown text.
 * @returns {{ text: string, map: PlaceholderMap }}
 */
export function preprocessMd(text) {
  const map = new PlaceholderMap();

  // Step 1: identify protected ranges (code fences + code spans)
  let protectedRanges = findProtectedRanges(text);

  // Step 2: extract block math $$...$$
  // Two forms:
  //   Fenced: $$ on its own line, content on subsequent lines, $$ on its own line
  //   Inline: $$content$$ on a single line
  const blockMathFencedRe = /^\$\$\s*\n([\s\S]*?)\n\$\$\s*$/gm;
  const replacements = [];

  for (const m of text.matchAll(blockMathFencedRe)) {
    if (isProtected(m.index, protectedRanges)) continue;
    const content = m[1];
    const token = map.add('mathblk', content);
    replacements.push({ start: m.index, end: m.index + m[0].length, token });
  }

  // Apply fenced block math replacements (reverse order to preserve indices)
  replacements.sort((a, b) => b.start - a.start);
  for (const { start, end, token } of replacements) {
    text = text.slice(0, start) + token + text.slice(end);
  }

  // Recalculate protected ranges after modification
  protectedRanges = findProtectedRanges(text);

  // Inline-form block math: $$content$$ on a single line
  const blockMathInlineRe = /\$\$(.+?)\$\$/g;
  const inlineBlockReplacements = [];

  for (const m of text.matchAll(blockMathInlineRe)) {
    if (isProtected(m.index, protectedRanges)) continue;
    const content = m[1];
    const token = map.add('mathblk', content);
    inlineBlockReplacements.push({ start: m.index, end: m.index + m[0].length, token });
  }

  inlineBlockReplacements.sort((a, b) => b.start - a.start);
  for (const { start, end, token } of inlineBlockReplacements) {
    text = text.slice(0, start) + token + text.slice(end);
  }

  // Step 3: extract inline math $...$
  // Recalculate protected ranges after block math extraction
  protectedRanges = findProtectedRanges(text);

  const inlineMathReplacements = [];
  // Match $...$ but not \$ and not inside protected ranges.
  // Walk through the text character by character to handle escapes properly.
  let i = 0;
  while (i < text.length) {
    if (isProtected(i, protectedRanges)) {
      // Skip to end of protected range
      const range = protectedRanges.find(([s, e]) => i >= s && i < e);
      i = range[1];
      continue;
    }

    // Check for escaped dollar
    if (text[i] === '\\' && i + 1 < text.length && text[i + 1] === '$') {
      i += 2;
      continue;
    }

    if (text[i] === '$') {
      // Look for closing $ on the same line
      const openPos = i;
      let j = i + 1;
      let found = false;
      while (j < text.length && text[j] !== '\n') {
        if (text[j] === '\\' && j + 1 < text.length && text[j + 1] === '$') {
          j += 2;
          continue;
        }
        if (text[j] === '$') {
          // Found closing $
          const content = text.slice(openPos + 1, j);
          if (content.length > 0) {
            const token = map.add('mathinl', content);
            inlineMathReplacements.push({ start: openPos, end: j + 1, token });
            i = j + 1;
            found = true;
          }
          break;
        }
        j++;
      }
      if (!found) {
        i++;
      }
      continue;
    }

    i++;
  }

  // Apply inline math replacements (reverse order)
  inlineMathReplacements.sort((a, b) => b.start - a.start);
  for (const { start, end, token } of inlineMathReplacements) {
    text = text.slice(0, start) + token + text.slice(end);
  }

  // Step 4: extract TOC <!-- {toc} -->
  protectedRanges = findProtectedRanges(text);
  const tocRe = /<!--\s*\{toc\}\s*-->/g;
  text = text.replace(tocRe, (match, offset) => {
    if (isProtected(offset, protectedRanges)) return match;
    return map.add('toc', '');
  });

  return { text, map };
}
