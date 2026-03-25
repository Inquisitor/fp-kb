import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { preprocessMd, preprocessAdf } from '../lib/preprocessor.js';

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

// ---------------------------------------------------------------------------
// preprocessAdf — ADF → placeholder direction
// ---------------------------------------------------------------------------

describe('preprocessAdf', () => {
  it('replaces inlineExtension[mathinline] with text placeholder', () => {
    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'paragraph',
        content: [
          { type: 'text', text: 'Value ' },
          { type: 'inlineExtension', attrs: {
            extensionType: 'com.atlassian.confluence.macro.core',
            extensionKey: 'mathinline',
            parameters: { body: 'x + y' }
          }},
          { type: 'text', text: ' is positive.' }
        ]
      }]
    };
    const { doc: result, map } = preprocessAdf(doc);
    const para = result.content[0];
    const texts = para.content.map(n => n.text || '').join('');
    assert.ok(texts.includes('CFMD_MATHINL_0001'));
    assert.equal(map.get('CFMD_MATHINL_0001').content, 'x + y');
  });

  it('replaces bodiedExtension[mathblock] with paragraph placeholder', () => {
    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'bodiedExtension', attrs: {
          extensionType: 'com.atlassian.confluence.macro.core',
          extensionKey: 'mathblock'
        },
        content: [{ type: 'paragraph', content: [
          { type: 'text', text: 'p(s) = (1-s)^\\alpha' }
        ]}]
      }]
    };
    const { doc: result, map } = preprocessAdf(doc);
    assert.equal(result.content[0].type, 'paragraph');
    assert.equal(map.get('CFMD_MATHBLK_0001').content, 'p(s) = (1-s)^\\alpha');
  });

  it('replaces extension[toc] with paragraph placeholder', () => {
    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'extension', attrs: {
          extensionType: 'com.atlassian.confluence.macro.core',
          extensionKey: 'toc', parameters: {}
        }
      }]
    };
    const { doc: result, map } = preprocessAdf(doc);
    assert.equal(map.get('CFMD_TOC_0001').type, 'toc');
  });

  it('extracts texblox inline math from ADF', () => {
    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'paragraph',
        content: [
          { type: 'text', text: 'Value ' },
          { type: 'inlineExtension', attrs: {
            extensionType: 'com.atlassian.ecosystem',
            extensionKey: '446c2bb7-9a68-48a6-83f6-38fc41031264/d02fb427-8edb-4057-9783-ef5e9d32b349/static/texblox-macro',
            text: 'LaTeX Formula',
            parameters: { guestParams: { formula: 'x^2', displayMode: 'inline' } }
          }},
          { type: 'text', text: ' end.' }
        ]
      }]
    };
    const { doc: result, map } = preprocessAdf(doc);
    const texts = result.content[0].content.map(n => n.text || '').join('');
    assert.ok(texts.includes('CFMD_MATHINL_0001'));
    assert.equal(map.get('CFMD_MATHINL_0001').content, 'x^2');
  });

  it('extracts texblox block math from ADF', () => {
    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'inlineExtension', attrs: {
          extensionType: 'com.atlassian.ecosystem',
          extensionKey: '446c2bb7-9a68-48a6-83f6-38fc41031264/d02fb427-8edb-4057-9783-ef5e9d32b349/static/texblox-macro',
          text: 'LaTeX Formula',
          parameters: { guestParams: { formula: 'E = mc^2', displayMode: 'block' } }
        }
      }]
    };
    const { doc: result, map } = preprocessAdf(doc);
    assert.equal(map.get('CFMD_MATHBLK_0001').content, 'E = mc^2');
    assert.equal(map.get('CFMD_MATHBLK_0001').type, 'mathblk');
  });

  it('passes through unrecognized extension nodes', () => {
    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'extension', attrs: {
          extensionType: 'com.atlassian.confluence.macro.core',
          extensionKey: 'jira', parameters: { key: 'FP-41845' }
        }
      }]
    };
    const { doc: result, map } = preprocessAdf(doc);
    assert.equal(result.content[0].type, 'extension');
    assert.equal(result.content[0].attrs.extensionKey, 'jira');
    assert.equal(map.size, 0);
  });
});
