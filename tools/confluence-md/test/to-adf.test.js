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

  it('strips first H1 by default', () => {
    const md = '# Page Title\n\nSome content.';
    const adf = toAdf(md);
    const headings = adf.content.filter(
      n => n.type === 'heading' && n.attrs?.level === 1
    );
    assert.equal(headings.length, 0, 'H1 should be stripped');
    // Content after H1 should survive
    const json = JSON.stringify(adf);
    assert.ok(json.includes('Some content'), 'body content should remain');
  });

  it('keeps H1 when stripH1 is false', () => {
    const md = '# Page Title\n\nSome content.';
    const adf = toAdf(md, { stripH1: false });
    const headings = adf.content.filter(
      n => n.type === 'heading' && n.attrs?.level === 1
    );
    assert.equal(headings.length, 1, 'H1 should be preserved');
  });

  it('only strips the first H1, not subsequent ones', () => {
    const md = '# First Title\n\n## H2\n\n# Second H1\n\nText.';
    const adf = toAdf(md);
    const h1s = adf.content.filter(
      n => n.type === 'heading' && n.attrs?.level === 1
    );
    assert.equal(h1s.length, 1, 'only the first H1 should be stripped');
    const json = JSON.stringify(adf);
    assert.ok(json.includes('Second H1'), 'second H1 should remain');
  });

  it('handles document with no H1 gracefully', () => {
    const md = '## Only H2\n\nSome text.';
    const adf = toAdf(md);
    const json = JSON.stringify(adf);
    assert.ok(json.includes('Only H2'), 'H2 should remain');
  });

  it('upgrades Jira markdown link to inlineCard', () => {
    const md = 'See [FP-41844](https://fishingplanet.atlassian.net/browse/FP-41844) here.';
    const adf = toAdf(md);
    const json = JSON.stringify(adf);
    assert.ok(json.includes('"type":"inlineCard"'), 'should have inlineCard');
    assert.ok(json.includes('FP-41844'), 'should have issue key in URL');
  });

  it('upgrades bare Jira URL to inlineCard', () => {
    const md = 'Link: https://fishingplanet.atlassian.net/browse/FP-41844 done.';
    const adf = toAdf(md);
    const json = JSON.stringify(adf);
    assert.ok(json.includes('"type":"inlineCard"'), 'should have inlineCard');
  });

  it('keeps Jira link with custom text as regular link', () => {
    const md = 'See [the task](https://fishingplanet.atlassian.net/browse/FP-41844) here.';
    const adf = toAdf(md);
    const json = JSON.stringify(adf);
    assert.ok(!json.includes('"type":"inlineCard"'), 'should NOT have inlineCard');
    assert.ok(json.includes('the task'), 'custom text should remain');
  });
});
