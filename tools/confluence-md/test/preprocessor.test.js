import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { preprocessMd } from '../lib/preprocessor.js';

describe('preprocessMd — inline math', () => {
  it('extracts single inline math', () => {
    const { text, map } = preprocessMd('The value $x + y$ is positive.');
    assert.ok(!text.includes('$x + y$'));
    assert.ok(text.includes('CFMD_MATHINL_0001'));
    assert.equal(map.get('CFMD_MATHINL_0001').content, 'x + y');
  });

  it('extracts multiple inline math', () => {
    const { text, map } = preprocessMd('Given $a$ and $b$, compute $a + b$.');
    assert.equal(map.size, 3);
  });

  it('ignores $ inside inline code', () => {
    const { text, map } = preprocessMd('Use `$variable` in code.');
    assert.equal(map.size, 0);
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
