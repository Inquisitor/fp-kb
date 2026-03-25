import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { toAdf } from '../lib/to-adf.js';
import { toMd } from '../lib/to-md.js';
import { readFileSync } from 'node:fs';

describe('roundtrip: MD → ADF → MD', () => {
  it('preserves inline math through roundtrip', () => {
    const original = 'The value $x + y$ is positive.';
    const adf = toAdf(original);
    const { md: restored } = toMd(adf);
    assert.ok(restored.includes('$x + y$'));
  });

  it('preserves block math through roundtrip', () => {
    const original = '$$\np(s) = (1-s)^\\alpha\n$$';
    const adf = toAdf(original);
    const { md: restored } = toMd(adf);
    assert.ok(restored.includes('p(s) = (1-s)^\\alpha'));
    assert.ok(restored.includes('$$'));
  });

  it('preserves TOC through roundtrip', () => {
    const original = '# Title\n\n<!-- {toc} -->\n\n## Section';
    const adf = toAdf(original);
    const { md: restored } = toMd(adf);
    assert.ok(restored.includes('<!-- {toc} -->'));
  });

  it('preserves status through roundtrip', () => {
    const original = '{status:PowerLaw|color:red}';
    const adf = toAdf(original);
    const { md: restored } = toMd(adf);
    assert.ok(restored.includes('{status:PowerLaw|color:red}'));
  });

  it('preserves panel through roundtrip', () => {
    const original = '~~~panel type=info\nContent here.\n~~~';
    const adf = toAdf(original);
    const { md: restored } = toMd(adf);
    assert.ok(restored.includes('panel'));
    assert.ok(restored.includes('info'));
    assert.ok(restored.includes('Content here.'));
  });

  it('roundtrips the full fixture file without CFMD_ leaks', () => {
    const original = readFileSync(new URL('./fixtures/math-and-panels.md', import.meta.url), 'utf8');
    const adf = toAdf(original);
    const { md: restored } = toMd(adf);
    assert.ok(!restored.includes('CFMD_'), 'no placeholder leaks');
    assert.ok(restored.includes('$'), 'should have inline math delimiters');
    assert.ok(restored.includes('$$'), 'should have block math delimiters');
    assert.ok(restored.includes('<!-- {toc} -->'), 'should have TOC');
  });
});
