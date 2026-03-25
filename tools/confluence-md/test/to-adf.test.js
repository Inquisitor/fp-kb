import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { toAdf } from '../lib/to-adf.js';

describe('toAdf pipeline', () => {
  it('converts fixture with math, panels, status, TOC to valid ADF', () => {
    const md = readFileSync(new URL('./fixtures/math-and-panels.md', import.meta.url), 'utf8');
    const adf = toAdf(md);

    assert.equal(adf.type, 'doc');
    const json = JSON.stringify(adf);

    // Math extension nodes present (texblox-macro format)
    assert.ok(json.includes('texblox-macro'), 'should have texblox-macro nodes');
    assert.ok(json.includes('"displayMode":"inline"'), 'should have inline math');
    assert.ok(json.includes('"displayMode":"block"'), 'should have block math');
    assert.ok(json.includes('"extensionKey":"toc"'), 'should have toc');

    // No raw placeholders remaining
    assert.ok(!json.includes('CFMD_'), 'should have no CFMD_ placeholders');

    // Native features handled by package
    assert.ok(json.includes('"type":"panel"'), 'should have panel');
    assert.ok(json.includes('"type":"status"'), 'should have status');
  });

  it('preserves LaTeX content in extension nodes', () => {
    const md = 'The value $x + y$ is positive.';
    const adf = toAdf(md);
    const json = JSON.stringify(adf);
    assert.ok(json.includes('x + y'), 'LaTeX content should be preserved');
  });

  it('handles block math', () => {
    const md = '$$\np(s) = (1-s)^\\alpha\n$$';
    const adf = toAdf(md);
    const json = JSON.stringify(adf);
    assert.ok(json.includes('texblox-macro'));
    assert.ok(json.includes('"displayMode":"block"'));
    assert.ok(json.includes('p(s) = (1-s)^\\\\alpha'));
  });
});
