import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { formatJiraIssue } from '../lib/jira-formatter.js';
import { execFileSync } from 'node:child_process';
import { writeFileSync, unlinkSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve, dirname } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const cli = resolve(__dirname, '..', 'jira-format.js');
const fixturePath = resolve(__dirname, 'fixtures', 'jira-issue-minimal.json');

describe('formatJiraIssue — structure validation', () => {
  it('throws on empty JSON', () => {
    assert.throws(() => formatJiraIssue({}), /No issue data found/);
  });

  it('throws on missing nodes', () => {
    assert.throws(() => formatJiraIssue({ issues: { nodes: [] } }), /No issue data found/);
  });

  it('throws on missing comment field', () => {
    const json = {
      issues: { totalCount: 1, nodes: [{ key: 'X-1', fields: { summary: 'x' } }] }
    };
    assert.throws(() => formatJiraIssue(json), /Comment field not found/);
  });

  it('accepts content-block wrapper format', () => {
    const wrapped = [{ type: 'text', text: JSON.stringify(fixture.issues.nodes[0]) }];
    const md = formatJiraIssue(wrapped);
    assert.ok(md.includes('# FP-99999:'));
  });

  it('accepts raw JIRA REST response format', () => {
    const raw = fixture.issues.nodes[0];
    const md = formatJiraIssue(raw);
    assert.ok(md.includes('# FP-99999:'));
  });

  it('throws on malformed comment structure', () => {
    const json = {
      issues: { totalCount: 1, nodes: [{ key: 'X-1', fields: {
        summary: 'x',
        comment: { total: 0 }  // missing .comments array
      }}] }
    };
    assert.throws(() => formatJiraIssue(json), /Unexpected comment structure/);
  });
});

const fixture = JSON.parse(
  readFileSync(new URL('./fixtures/jira-issue-minimal.json', import.meta.url), 'utf-8')
);

describe('formatJiraIssue — header', () => {
  const md = formatJiraIssue(fixture);

  it('starts with issue key and summary as H1', () => {
    assert.ok(md.startsWith('# FP-99999: Test issue summary'));
  });

  it('contains status with category', () => {
    assert.ok(md.includes('**Status:** In Progress (In Progress)'));
  });

  it('contains assignee', () => {
    assert.ok(md.includes('**Assignee:** John Doe'));
  });

  it('omits resolution line when resolution is null', () => {
    assert.ok(!md.includes('**Resolution:**'));
  });
});

describe('formatJiraIssue — header with resolution', () => {
  const resolved = structuredClone(fixture);
  resolved.issues.nodes[0].fields.resolution = { name: 'Done' };
  resolved.issues.nodes[0].fields.resolutiondate = '2026-03-05T12:00:00.000+0200';
  const md = formatJiraIssue(resolved);

  it('shows resolution and date', () => {
    assert.ok(md.includes('**Resolution:** Done'));
    assert.ok(md.includes('**Resolved:** 2026-03-05'));
  });
});

describe('formatJiraIssue — description', () => {
  const md = formatJiraIssue(fixture);

  it('contains Description section', () => {
    assert.ok(md.includes('## Description'));
  });

  it('converts ADF description to markdown', () => {
    assert.ok(md.includes('Issue description text.'));
  });
});

describe('formatJiraIssue — no description', () => {
  const noDesc = structuredClone(fixture);
  noDesc.issues.nodes[0].fields.description = null;
  const md = formatJiraIssue(noDesc);

  it('shows placeholder for missing description', () => {
    assert.ok(md.includes('[No description]'));
  });
});

describe('formatJiraIssue — comments', () => {
  const md = formatJiraIssue(fixture);

  it('shows comment count', () => {
    assert.ok(md.includes('## Comments (2)'));
  });

  it('formats comment header with author, date, id', () => {
    assert.ok(md.includes('### Alice — 2026-03-01 10:00 [id:10001]'));
  });

  it('converts comment body ADF to markdown', () => {
    assert.ok(md.includes('First comment.'));
  });

  it('shows edited indicator when updated differs from created', () => {
    assert.ok(md.includes('[id:10002] *(edited 2026-03-02 15:00)*'));
  });

  it('does not show edited indicator when dates match', () => {
    assert.ok(!md.includes('[id:10001] *(edited'));
  });

  it('preserves bold and code marks from ADF', () => {
    assert.ok(md.includes('**bold**'));
    assert.ok(md.includes('`code`'));
  });
});

describe('formatJiraIssue — no comments', () => {
  const empty = structuredClone(fixture);
  empty.issues.nodes[0].fields.comment = { total: 0, comments: [] };
  const md = formatJiraIssue(empty);

  it('shows Comments (0)', () => {
    assert.ok(md.includes('## Comments (0)'));
  });
});

describe('formatJiraIssue — ADF conversion error in comment', () => {
  const bad = structuredClone(fixture);
  bad.issues.nodes[0].fields.comment.comments[0].body = 'not-valid-adf';
  const md = formatJiraIssue(bad);

  it('shows error for broken comment, still formats others', () => {
    assert.ok(md.includes('[ADF conversion error'));
    assert.ok(md.includes('**bold**'));  // second comment still works
  });
});

describe('formatJiraIssue — timeline', () => {
  const md = formatJiraIssue(fixture);

  it('contains Timeline section', () => {
    assert.ok(md.includes('## Timeline'));
  });

  it('includes status transitions', () => {
    assert.ok(md.includes('→ In Progress (Alice)'));
    assert.ok(md.includes('→ Resolved (Bob)'));
  });

  it('includes assignee changes', () => {
    assert.ok(md.includes('Assignee → John Doe'));
  });

  it('excludes non-tracked fields (priority)', () => {
    assert.ok(!md.includes('High'));
  });

  it('sorts events chronologically', () => {
    const inProgress = md.indexOf('→ In Progress');
    const resolved = md.indexOf('→ Resolved');
    assert.ok(inProgress < resolved, 'In Progress should appear before Resolved');
  });
});

describe('formatJiraIssue — no changelog', () => {
  const noCl = structuredClone(fixture);
  delete noCl.issues.nodes[0].changelog;
  const md = formatJiraIssue(noCl);

  it('shows notice when changelog is missing', () => {
    assert.ok(md.includes('[Changelog not available'));
  });
});

describe('jira-format.js CLI', () => {
  it('outputs markdown to stdout', () => {
    const result = execFileSync('node', [cli, fixturePath], { encoding: 'utf-8' });
    assert.ok(result.includes('# FP-99999:'));
    assert.ok(result.includes('## Description'));
    assert.ok(result.includes('## Timeline'));
    assert.ok(result.includes('## Comments (2)'));
  });

  it('exits with code 1 on missing file', () => {
    assert.throws(
      () => execFileSync('node', [cli, '/tmp/nonexistent.json'], { encoding: 'utf-8' }),
      (err) => err.status === 1
    );
  });

  it('exits with code 1 on invalid JSON structure', () => {
    const tmpPath = resolve(__dirname, 'fixtures', '_tmp_bad.json');
    writeFileSync(tmpPath, '{"not":"jira"}');
    try {
      assert.throws(
        () => execFileSync('node', [cli, tmpPath], { encoding: 'utf-8' }),
        (err) => err.status === 1
      );
    } finally {
      unlinkSync(tmpPath);
    }
  });
});
