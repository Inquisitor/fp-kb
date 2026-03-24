# confluence-md Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a bidirectional MD ↔ ADF JSON file converter with pre/post-processing for LaTeX math and TOC macros.

**Architecture:** CLI Node.js tool using `extended-markdown-adf-parser` as the core converter. Our code adds a thin pre/post-processing layer that extracts LaTeX (`$...$`, `$$...$$`) and TOC (`<!-- {toc} -->`) before the package sees the text, then injects the corresponding ADF extension nodes after conversion (and vice versa for the reverse direction).

**Tech Stack:** Node.js (ESM), `extended-markdown-adf-parser` ^2.4.0, `js-yaml` (for media registry), `node:test` (built-in test runner)

**Spec:** `D:\kb\fishing-planet\tasks\FP-41844--weight-gen-docs\artifacts\confluence-md-design.md`

---

## File Map

| File | Responsibility |
|------|---------------|
| `confluence-md.js` | CLI entry point: arg parsing, dispatch to `to-adf` or `to-md` |
| `lib/placeholder.js` | Placeholder map: create/store/retrieve `CFMD_*` tokens |
| `lib/preprocessor.js` | Two exports: `preprocessMd(text)` — extract LaTeX/TOC from MD; `preprocessAdf(doc)` — extract extension nodes from ADF tree |
| `lib/postprocessor.js` | Two exports: `postprocessAdf(doc, map)` — inject extension nodes into ADF; `postprocessMd(text, map)` — inject `$...$`/`$$...$$`/`<!-- {toc} -->` into MD |
| `lib/to-adf.js` | Pipeline: read MD → preprocessMd → package → postprocessAdf → write JSON |
| `lib/to-md.js` | Pipeline: read JSON → preprocessAdf → package → postprocessMd → write MD |
| `lib/media.js` | Media registry: load/save YAML, lookup by filename, lookup by UUID |
| `test/placeholder.test.js` | Tests for placeholder map |
| `test/preprocessor.test.js` | Tests for MD and ADF pre-processing |
| `test/postprocessor.test.js` | Tests for ADF and MD post-processing |
| `test/integration.test.js` | End-to-end: MD → ADF → MD roundtrip |
| `test/fixtures/` | Sample `.md` and `.adf.json` files |

---

## Task 1: Project Setup and API Discovery

**Files:**
- Create: `D:\kb\tools\confluence-md\package.json`
- Create: `D:\kb\tools\confluence-md\lib\` (directory)
- Create: `D:\kb\tools\confluence-md\test\` (directory)
- Create: `D:\kb\tools\confluence-md\test\fixtures\` (directory)

- [ ] **Step 1: Create project directory and package.json**

```json
{
  "name": "confluence-md",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "test": "node --test test/*.test.js"
  },
  "dependencies": {
    "extended-markdown-adf-parser": "^2.4.0",
    "js-yaml": "^4.1.0"
  }
}
```

Run: `cd D:\kb\tools\confluence-md && mkdir lib test test/fixtures`

- [ ] **Step 2: Install dependencies**

Run: `npm install`
Expected: `node_modules/` created, both packages installed.

- [ ] **Step 3: Discover package API**

Create a throwaway script `_discover.js`:

```javascript
import * as pkg from 'extended-markdown-adf-parser';
console.log('Exports:', Object.keys(pkg));

// Try the expected API shape
const md = '# Hello\n\nSome **bold** text.';
// Attempt conversion — adjust based on actual exports
```

Run: `node _discover.js`

Document the actual API in a comment at the top of `lib/to-adf.js` for reference. Delete `_discover.js` after.

**Key questions to answer:**
- What is the import path? (default export? named exports?)
- MD→ADF function signature: `convert(string) → object` or `parse(string) → string`?
- ADF→MD function signature?
- Does ADF output include the `doc` wrapper (`{"type":"doc","version":1,"content":[...]}`) or just the content array?

- [ ] **Step 4: Create a minimal test fixture**

Create `test/fixtures/simple.md`:
```markdown
# Hello

Some **bold** text and a [link](https://example.com).
```

- [ ] **Step 5: Verify package works with a smoke test**

Create `test/smoke.test.js`:
```javascript
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
// Import adjusted based on Step 3 findings
import { /* actual export name */ } from 'extended-markdown-adf-parser';

describe('package smoke test', () => {
  it('converts simple markdown to ADF', () => {
    const md = '# Hello\n\nSome **bold** text.';
    const adf = /* call package */;
    assert.equal(adf.type, 'doc');
    assert.ok(adf.content.length > 0);
  });

  it('converts ADF back to markdown', () => {
    const adf = { type: 'doc', version: 1, content: [
      { type: 'heading', attrs: { level: 1 }, content: [{ type: 'text', text: 'Hello' }] }
    ]};
    const md = /* call package */;
    assert.ok(md.includes('# Hello'));
  });
});
```

Run: `npm test`
Expected: 2 tests pass. Adjust imports/calls based on Step 3 findings.

- [ ] **Step 6: Commit**

Message: `[confluence-md] Project setup with extended-markdown-adf-parser`

---

## Task 2: Placeholder Map

**Files:**
- Create: `D:\kb\tools\confluence-md\lib\placeholder.js`
- Create: `D:\kb\tools\confluence-md\test\placeholder.test.js`

- [ ] **Step 1: Write tests**

```javascript
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { PlaceholderMap } from '../lib/placeholder.js';

describe('PlaceholderMap', () => {
  it('creates sequential inline math placeholders', () => {
    const map = new PlaceholderMap();
    const p1 = map.add('mathinl', 'x + y');
    const p2 = map.add('mathinl', 'a^2');
    assert.equal(p1, 'CFMD_MATHINL_0001');
    assert.equal(p2, 'CFMD_MATHINL_0002');
  });

  it('creates block math placeholders', () => {
    const map = new PlaceholderMap();
    const p = map.add('mathblk', 'p(s) = (1-s)^\\alpha');
    assert.equal(p, 'CFMD_MATHBLK_0001');
  });

  it('creates TOC placeholders', () => {
    const map = new PlaceholderMap();
    const p = map.add('toc', '');
    assert.equal(p, 'CFMD_TOC_0001');
  });

  it('retrieves stored content by placeholder ID', () => {
    const map = new PlaceholderMap();
    const p = map.add('mathinl', 'x + y');
    const entry = map.get(p);
    assert.deepEqual(entry, { type: 'mathinl', content: 'x + y' });
  });

  it('returns undefined for unknown placeholder', () => {
    const map = new PlaceholderMap();
    assert.equal(map.get('CFMD_MATHINL_9999'), undefined);
  });

  it('lists all entries', () => {
    const map = new PlaceholderMap();
    map.add('mathinl', 'a');
    map.add('mathblk', 'b');
    assert.equal(map.size, 2);
  });

  it('builds regex matching all placeholders of a given type', () => {
    const map = new PlaceholderMap();
    map.add('mathinl', 'x');
    map.add('mathinl', 'y');
    const re = map.regex('mathinl');
    assert.ok(re.test('CFMD_MATHINL_0001'));
    assert.ok(re.test('CFMD_MATHINL_0002'));
    assert.ok(!re.test('CFMD_MATHBLK_0001'));
  });
});
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `npm test`
Expected: All tests fail (module not found).

- [ ] **Step 3: Implement PlaceholderMap**

```javascript
// lib/placeholder.js

const PREFIX = 'CFMD';
const TYPE_MAP = {
  mathinl: 'MATHINL',
  mathblk: 'MATHBLK',
  toc: 'TOC',
};

export class PlaceholderMap {
  #entries = new Map();
  #counters = { mathinl: 0, mathblk: 0, toc: 0 };

  add(type, content) {
    if (!(type in TYPE_MAP)) throw new Error(`Unknown type: ${type}`);
    const n = ++this.#counters[type];
    const id = `${PREFIX}_${TYPE_MAP[type]}_${String(n).padStart(4, '0')}`;
    this.#entries.set(id, { type, content });
    return id;
  }

  get(id) {
    return this.#entries.get(id);
  }

  get size() {
    return this.#entries.size;
  }

  entries() {
    return this.#entries.entries();
  }

  regex(type) {
    const tag = TYPE_MAP[type];
    if (!tag) throw new Error(`Unknown type: ${type}`);
    return new RegExp(`${PREFIX}_${tag}_\\d{4}`, 'g');
  }
}
```

- [ ] **Step 4: Run tests, verify they pass**

Run: `npm test`
Expected: All placeholder tests pass.

- [ ] **Step 5: Commit**

Message: `[confluence-md] Add PlaceholderMap for CFMD_* token management`

---

## Task 3: MD Pre-processor (LaTeX/TOC extraction)

**Files:**
- Create: `D:\kb\tools\confluence-md\lib\preprocessor.js`
- Create: `D:\kb\tools\confluence-md\test\preprocessor.test.js`

- [ ] **Step 1: Write tests for inline math extraction**

```javascript
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { preprocessMd } from '../lib/preprocessor.js';

describe('preprocessMd — inline math', () => {
  it('extracts single inline math', () => {
    const { text, map } = preprocessMd('The value $x + y$ is positive.');
    assert.ok(!text.includes('$'));
    assert.ok(text.includes('CFMD_MATHINL_0001'));
    assert.equal(map.get('CFMD_MATHINL_0001').content, 'x + y');
  });

  it('extracts multiple inline math', () => {
    const { text, map } = preprocessMd('Given $a$ and $b$, compute $a + b$.');
    assert.equal(map.size, 3);
    assert.ok(!text.includes('$'));
  });

  it('ignores $ inside inline code', () => {
    const { text, map } = preprocessMd('Use `$variable` in code.');
    assert.equal(map.size, 0);
    assert.ok(text.includes('`$variable`'));
  });

  it('ignores $ inside code fence', () => {
    const input = '```\nlet $x = 5;\n```';
    const { text, map } = preprocessMd(input);
    assert.equal(map.size, 0);
  });

  it('ignores escaped \\$', () => {
    const { text, map } = preprocessMd('The price is \\$100.');
    assert.equal(map.size, 0);
    assert.ok(text.includes('\\$100'));
  });
});
```

- [ ] **Step 2: Write tests for block math extraction**

```javascript
describe('preprocessMd — block math', () => {
  it('extracts fenced block math (separate lines)', () => {
    const input = 'Before.\n\n$$\np(s) = (1-s)^\\alpha\n$$\n\nAfter.';
    const { text, map } = preprocessMd(input);
    assert.ok(text.includes('CFMD_MATHBLK_0001'));
    assert.equal(map.get('CFMD_MATHBLK_0001').content, 'p(s) = (1-s)^\\alpha');
    assert.equal(map.get('CFMD_MATHBLK_0001').type, 'mathblk');
  });

  it('extracts inline-form block math (single line)', () => {
    const input = 'Before.\n\n$$p(s) = (1-s)^\\alpha$$\n\nAfter.';
    const { text, map } = preprocessMd(input);
    assert.ok(text.includes('CFMD_MATHBLK_0001'));
    assert.equal(map.get('CFMD_MATHBLK_0001').content, 'p(s) = (1-s)^\\alpha');
  });

  it('extracts multiline block math', () => {
    const input = '$$\nline1\nline2\nline3\n$$';
    const { text, map } = preprocessMd(input);
    assert.equal(map.get('CFMD_MATHBLK_0001').content, 'line1\nline2\nline3');
  });

  it('ignores $$ inside code fence', () => {
    const input = '```\n$$\nnot math\n$$\n```';
    const { text, map } = preprocessMd(input);
    assert.equal(map.size, 0);
  });
});
```

- [ ] **Step 3: Write tests for TOC extraction**

```javascript
describe('preprocessMd — TOC', () => {
  it('extracts TOC comment', () => {
    const { text, map } = preprocessMd('# Title\n\n<!-- {toc} -->\n\n## Section');
    assert.ok(text.includes('CFMD_TOC_0001'));
    assert.ok(!text.includes('<!-- {toc} -->'));
    assert.equal(map.get('CFMD_TOC_0001').type, 'toc');
  });

  it('handles TOC with extra whitespace', () => {
    const { text, map } = preprocessMd('<!--  {toc}  -->');
    assert.equal(map.size, 1);
  });
});
```

- [ ] **Step 4: Run tests, verify they fail**

Run: `npm test`
Expected: All fail (module not found).

- [ ] **Step 5: Implement `preprocessMd`**

Key implementation logic:

1. Identify protected ranges (code fences, code spans)
2. Extract block math `$$...$$` (fenced and inline forms), skipping protected ranges
3. Extract inline math `$...$`, skipping protected ranges and escaped `\$`
4. Extract TOC `<!-- {toc} -->`

The regex patterns are starting points — edge cases from testing may require refinement, especially the interaction between code fence detection and `$$` detection.

- [ ] **Step 6: Run tests, iterate until all pass**

Run: `npm test`
Iterate on regex patterns until all pre-processor tests pass.

- [ ] **Step 7: Commit**

Message: `[confluence-md] Add MD pre-processor: LaTeX and TOC extraction`

---

## Task 4: ADF Post-processor (placeholder → extension nodes)

**Files:**
- Create: `D:\kb\tools\confluence-md\lib\postprocessor.js`
- Create: `D:\kb\tools\confluence-md\test\postprocessor.test.js`

- [ ] **Step 1: Write tests for inline math injection**

```javascript
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { postprocessAdf } from '../lib/postprocessor.js';
import { PlaceholderMap } from '../lib/placeholder.js';

describe('postprocessAdf — inline math', () => {
  it('replaces inline placeholder in text node with inlineExtension', () => {
    const map = new PlaceholderMap();
    const ph = map.add('mathinl', 'x + y');

    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'paragraph',
        content: [
          { type: 'text', text: `The value ${ph} is positive.` }
        ]
      }]
    };

    const result = postprocessAdf(doc, map);
    const para = result.content[0];
    // Should be split: text + inlineExtension + text
    assert.ok(para.content.length >= 2);
    const ext = para.content.find(n => n.type === 'inlineExtension');
    assert.ok(ext);
    assert.equal(ext.attrs.extensionKey, 'mathinline');
    assert.equal(ext.attrs.parameters.body, 'x + y');
  });
});
```

- [ ] **Step 2: Write tests for block math and TOC injection**

Test that a paragraph containing only `CFMD_MATHBLK_*` is replaced with a `bodiedExtension` node, and `CFMD_TOC_*` with an `extension` node. (See spec for exact ADF schemas.)

- [ ] **Step 3: Run tests, verify they fail**

Run: `npm test`

- [ ] **Step 4: Implement `postprocessAdf`**

Key logic: recursive ADF tree walk.
- Block/TOC: paragraph with sole text child matching placeholder → replace entire paragraph with extension node
- Inline: text node containing placeholder substring → split text node into [text, inlineExtension, text] parts

- [ ] **Step 5: Run tests, iterate until all pass**

Run: `npm test`

- [ ] **Step 6: Commit**

Message: `[confluence-md] Add ADF post-processor: inject extension nodes from placeholders`

---

## Task 5: to-adf Pipeline

**Files:**
- Create: `D:\kb\tools\confluence-md\lib\to-adf.js`
- Create: `D:\kb\tools\confluence-md\test\to-adf.test.js`
- Create: `D:\kb\tools\confluence-md\test\fixtures\math-and-panels.md`

- [ ] **Step 1: Create a test fixture with LaTeX, panels, status**

Create `test/fixtures/math-and-panels.md`:
```markdown
# Edge Distribution

The edge function is $p(s) = (1-s)^\alpha$ where $\alpha > 0$.

$$
c = \frac{1}{T + z \cdot A}
$$

~~~panel type=info title="Explanation"
This formula ensures total probability = 1.
~~~

<!-- {toc} -->

{status:PowerLaw|color:red} uses $p(1) = 0$.
```

- [ ] **Step 2: Write integration test for to-adf**

Verify the pipeline output contains `inlineExtension[mathinline]`, `bodiedExtension[mathblock]`, `extension[toc]`, `panel`, `status` nodes — and no remaining `CFMD_*` placeholders.

- [ ] **Step 3: Implement `toAdf` (wire up preprocess → package → postprocess)**

```javascript
// lib/to-adf.js
import { preprocessMd } from './preprocessor.js';
import { postprocessAdf } from './postprocessor.js';
// Import adjusted based on Task 1 API discovery
import { /* package export */ } from 'extended-markdown-adf-parser';

export function toAdf(md) {
  const { text, map } = preprocessMd(md);
  const adf = /* package MD→ADF call */;
  return postprocessAdf(adf, map);
}
```

- [ ] **Step 4: Run tests, iterate until pass**

Run: `npm test`

- [ ] **Step 5: Commit**

Message: `[confluence-md] Add to-adf pipeline: MD → pre-process → package → post-process → ADF`

---

## Task 6: ADF Pre-processor and MD Post-processor (to-md direction)

**Files:**
- Modify: `D:\kb\tools\confluence-md\lib\preprocessor.js` (add `preprocessAdf`)
- Modify: `D:\kb\tools\confluence-md\lib\postprocessor.js` (add `postprocessMd`)
- Modify: `D:\kb\tools\confluence-md\test\preprocessor.test.js`
- Modify: `D:\kb\tools\confluence-md\test\postprocessor.test.js`

- [ ] **Step 1: Write tests for `preprocessAdf`**

Test cases:
- `inlineExtension[mathinline]` → replaced with text node containing `CFMD_MATHINL_*`, LaTeX extracted from `attrs.parameters.body`
- `bodiedExtension[mathblock]` → replaced with paragraph containing `CFMD_MATHBLK_*`, LaTeX extracted from `content[0].content[0].text`
- `extension[toc]` → replaced with paragraph containing `CFMD_TOC_*`
- Unrecognized extension nodes (e.g. `jira`) → passed through unchanged

- [ ] **Step 2: Write tests for `postprocessMd`**

Test cases:
- `CFMD_MATHINL_*` in text → `$content$`
- `CFMD_MATHBLK_*` on its own line → `$$\ncontent\n$$`
- `CFMD_TOC_*` → `<!-- {toc} -->`

- [ ] **Step 3: Run tests, verify they fail**

Run: `npm test`

- [ ] **Step 4: Implement `preprocessAdf`**

Recursive ADF tree walk: find extension nodes with matching `extensionType` + `extensionKey`, extract content, replace with placeholder text/paragraph nodes. All other nodes pass through.

- [ ] **Step 5: Implement `postprocessMd`**

Simple string replacement: iterate over map entries, replace each placeholder token with the corresponding LaTeX or TOC syntax.

- [ ] **Step 6: Run tests, iterate until all pass**

Run: `npm test`

- [ ] **Step 7: Commit**

Message: `[confluence-md] Add ADF pre-processor and MD post-processor for to-md direction`

---

## Task 7: to-md Pipeline

**Files:**
- Create: `D:\kb\tools\confluence-md\lib\to-md.js`
- Create: `D:\kb\tools\confluence-md\test\to-md.test.js`

- [ ] **Step 1: Write test — ADF with math extensions converts to MD with `$...$`**

Feed a hand-crafted ADF doc containing `inlineExtension[mathinline]`, `bodiedExtension[mathblock]`, `extension[toc]`, heading, paragraph. Verify output contains `$x + y$`, `$$...$$`, `<!-- {toc} -->`, `# Title`, and no `CFMD_*`.

- [ ] **Step 2: Implement `toMd` (wire up preprocessAdf → package → postprocessMd)**

- [ ] **Step 3: Run tests, iterate until pass**

Run: `npm test`

- [ ] **Step 4: Commit**

Message: `[confluence-md] Add to-md pipeline: ADF → pre-process → package → post-process → MD`

---

## Task 8: Roundtrip Integration Tests

**Files:**
- Create: `D:\kb\tools\confluence-md\test\integration.test.js`

- [ ] **Step 1: Write roundtrip tests**

Test cases:
- Inline math survives `MD → ADF → MD`
- Block math survives roundtrip
- TOC survives roundtrip
- Full fixture file (`math-and-panels.md`) roundtrip: key content preserved, no `CFMD_*` leaks

- [ ] **Step 2: Run tests**

Run: `npm test`
Expected: All roundtrip tests pass. If not — debug which direction loses information.

- [ ] **Step 3: Commit**

Message: `[confluence-md] Add roundtrip integration tests`

---

## Task 9: Media Registry

**Files:**
- Create: `D:\kb\tools\confluence-md\lib\media.js`
- Create: `D:\kb\tools\confluence-md\test\media.test.js`

- [ ] **Step 1: Write tests**

Test cases:
- `fromYaml(text)` — parse a YAML string into registry
- `findByFilename(name, pageId)` — returns `{id, filename, page_id, ...}` or null
- `findById(uuid)` — returns entry or null
- `add(id, fields)` — adds entry
- `toYaml()` — serializes back to YAML

- [ ] **Step 2: Implement `MediaRegistry`**

Uses `js-yaml` for parse/dump. Internal `Map<id, {filename, page_id, source?, uploaded}>`.

- [ ] **Step 3: Run tests, iterate**

Run: `npm test`

- [ ] **Step 4: Commit**

Message: `[confluence-md] Add MediaRegistry for image ID tracking`

---

## Task 10: CLI Entry Point

**Files:**
- Create: `D:\kb\tools\confluence-md\confluence-md.js`

- [ ] **Step 1: Implement CLI**

Arg parsing: `to-adf <file.md> [-o out.adf.json]` / `to-md <file.adf.json> [-o out.md]`.
Default output: swap extension `.md` ↔ `.adf.json`.
Exit 0 on success, exit 1 on error. Status messages to stderr.

- [ ] **Step 2: Manual smoke test**

Run: `node confluence-md.js to-adf test/fixtures/math-and-panels.md -o /tmp/test.adf.json`
Expected: File created, no errors.

Run: `node confluence-md.js to-md /tmp/test.adf.json -o /tmp/test-roundtrip.md`
Expected: File created, contains `$...$` and `<!-- {toc} -->`.

- [ ] **Step 3: Commit**

Message: `[confluence-md] Add CLI entry point`

---

## Task 11: Test with Real Draft

**Files:**
- Create: `D:\kb\tools\confluence-md\test\fixtures\real-draft-excerpt.md`

- [ ] **Step 1: Adapt a section of the real draft to the new convention**

Take a representative excerpt (~50 lines) from `D:\kb\confluence\workspace\FP-41844--edge-distribution-design-analysis.md` containing LaTeX, panels, status lozenges, TOC. Convert old conventions to new:

- `<div class="panel blue">` → `~~~panel type=info`
- `<span class="lozenge red">X</span>` → `{status:X|color:red}`
- `<details><summary>` → `~~~expand title="..."`
- `$...$`, `$$...$$`, `<!-- {toc} -->` — unchanged

- [ ] **Step 2: Run to-adf on the real excerpt**

Run: `node confluence-md.js to-adf test/fixtures/real-draft-excerpt.md`

Inspect the `.adf.json` output: all math converted to extension nodes, status/panel nodes present, no CFMD_ placeholders remaining.

- [ ] **Step 3: Run roundtrip**

Run: `node confluence-md.js to-md test/fixtures/real-draft-excerpt.adf.json`

Compare restored MD with original — key content should survive.

- [ ] **Step 4: Fix any issues found**

Iterate on preprocessor/postprocessor if edge cases surface.

- [ ] **Step 5: Commit**

Message: `[confluence-md] Verify with real draft excerpt; fix edge cases`

---

## Deferred (not in this plan)

- **Automated image upload** (Phase 2 of image workflow) — requires Confluence REST API auth
- **Media-aware conversion** — resolving `![alt](filename.svg)` via `media-registry.yml` during `to-adf`
- **Claude Code skill** — wrap CLI into a skill once workflow stabilizes
- **`to-md` image download** — download attachments and save locally
