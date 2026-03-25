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

    const { md } = toMd(adf);
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
    const { md } = toMd(adf);
    assert.ok(md.includes('$x^2$'), 'inline math');
    assert.ok(md.includes('$$\nE = mc^2\n$$'), 'block math');
    assert.ok(!md.includes('CFMD_'));
  });

  it('converts Jira inlineCard to clean markdown link', () => {
    const adf = {
      type: 'doc', version: 1,
      content: [{
        type: 'paragraph',
        content: [
          { type: 'text', text: 'See ' },
          { type: 'inlineCard', attrs: { url: 'https://fishingplanet.atlassian.net/browse/FP-41844' } },
          { type: 'text', text: ' for details.' },
        ],
      }],
    };
    const { md } = toMd(adf);
    assert.ok(md.includes('[FP-41844]'), 'should have issue key as link text');
    assert.ok(md.includes('(https://fishingplanet.atlassian.net/browse/FP-41844)'), 'should have full URL');
    assert.ok(!md.includes('card:'), 'should NOT have card: prefix');
    assert.ok(!md.includes('adf://'), 'should NOT have adf:// prefix');
  });

  it('converts mediaSingle to markdown image with fileId lookup', () => {
    const adf = {
      type: 'doc', version: 1,
      content: [{
        type: 'mediaSingle',
        attrs: { layout: 'center' },
        content: [
          { type: 'media', attrs: { id: 'abc-123', type: 'file', alt: 'fig.svg', collection: 'contentId-999' } },
          { type: 'caption', content: [{ type: 'text', text: 'Figure 1' }] },
        ],
      }],
    };
    const nameMap = new Map([['abc-123', 'fig.svg']]);
    const { md, warnings } = toMd(adf, { fileIdToName: nameMap });
    assert.ok(md.includes('![Figure 1](fig.svg)'), 'should have markdown image');
    assert.equal(warnings.length, 0);
  });
});
