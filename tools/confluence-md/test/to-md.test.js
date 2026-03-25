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

  it('converts ADF with texblox-macro nodes to markdown with $...$', () => {
    const texbloxKey = '446c2bb7-9a68-48a6-83f6-38fc41031264/d02fb427-8edb-4057-9783-ef5e9d32b349/static/texblox-macro';
    const adf = {
      type: 'doc', version: 1,
      content: [
        { type: 'paragraph', content: [
          { type: 'text', text: 'Value ' },
          { type: 'inlineExtension', attrs: {
            extensionType: 'com.atlassian.ecosystem',
            extensionKey: texbloxKey,
            text: 'LaTeX Formula',
            parameters: { guestParams: { formula: 'x^2', displayMode: 'inline' } }
          }},
          { type: 'text', text: ' end.' }
        ]},
        { type: 'inlineExtension', attrs: {
          extensionType: 'com.atlassian.ecosystem',
          extensionKey: texbloxKey,
          text: 'LaTeX Formula',
          parameters: { guestParams: { formula: 'E = mc^2', displayMode: 'block' } }
        }}
      ]
    };
    const md = toMd(adf);
    assert.ok(md.includes('$x^2$'), 'inline math');
    assert.ok(md.includes('$$\nE = mc^2\n$$'), 'block math');
    assert.ok(!md.includes('CFMD_'));
  });
});
