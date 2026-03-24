import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { toMd } from '../lib/to-md.js';

describe('toMd pipeline', () => {
  it('converts ADF with math extensions to markdown with $...$', () => {
    const adf = {
      type: 'doc', version: 1,
      content: [
        { type: 'heading', attrs: { level: 1 }, content: [{ type: 'text', text: 'Title' }] },
        { type: 'paragraph', content: [
          { type: 'text', text: 'The value ' },
          { type: 'inlineExtension', attrs: {
            extensionType: 'com.atlassian.confluence.macro.core',
            extensionKey: 'mathinline',
            parameters: { body: 'x + y' }
          }},
          { type: 'text', text: ' is positive.' }
        ]},
        { type: 'bodiedExtension', attrs: {
          extensionType: 'com.atlassian.confluence.macro.core',
          extensionKey: 'mathblock'
        }, content: [{ type: 'paragraph', content: [
          { type: 'text', text: 'c = \\frac{1}{T}' }
        ]}]},
        { type: 'extension', attrs: {
          extensionType: 'com.atlassian.confluence.macro.core',
          extensionKey: 'toc', parameters: {}
        }}
      ]
    };

    const md = toMd(adf);
    assert.ok(md.includes('# Title'));
    assert.ok(md.includes('$x + y$'));
    assert.ok(md.includes('$$\nc = \\frac{1}{T}\n$$'));
    assert.ok(md.includes('<!-- {toc} -->'));
    assert.ok(!md.includes('CFMD_'));
  });
});
