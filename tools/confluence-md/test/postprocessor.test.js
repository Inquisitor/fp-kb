import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { postprocessAdf, postprocessMd } from '../lib/postprocessor.js';
import { PlaceholderMap } from '../lib/placeholder.js';

describe('postprocessAdf — inline math', () => {
  it('replaces inline placeholder in text node with inlineExtension', () => {
    const map = new PlaceholderMap();
    const ph = map.add('mathinl', 'x + y');

    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'paragraph',
        content: [{ type: 'text', text: `The value ${ph} is positive.` }]
      }]
    };

    const result = postprocessAdf(doc, map);
    const para = result.content[0];
    const ext = para.content.find(n => n.type === 'inlineExtension');
    assert.ok(ext, 'should contain inlineExtension');
    assert.ok(ext.attrs.extensionKey.includes('texblox-macro'));
    assert.equal(ext.attrs.parameters.guestParams.formula, 'x + y');
    assert.equal(ext.attrs.parameters.guestParams.displayMode, 'inline');
    // Should also have text nodes around it
    assert.ok(para.content.length >= 3, 'should split: text + ext + text');
  });

  it('handles multiple inline placeholders in one text node', () => {
    const map = new PlaceholderMap();
    const ph1 = map.add('mathinl', 'a');
    const ph2 = map.add('mathinl', 'b');

    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'paragraph',
        content: [{ type: 'text', text: `${ph1} and ${ph2}` }]
      }]
    };

    const result = postprocessAdf(doc, map);
    const para = result.content[0];
    const exts = para.content.filter(n => n.type === 'inlineExtension');
    assert.equal(exts.length, 2);
  });

  it('handles placeholder at start of text', () => {
    const map = new PlaceholderMap();
    const ph = map.add('mathinl', 'x');

    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'paragraph',
        content: [{ type: 'text', text: `${ph} is a variable` }]
      }]
    };

    const result = postprocessAdf(doc, map);
    const para = result.content[0];
    assert.equal(para.content[0].type, 'inlineExtension');
  });
});

describe('postprocessAdf — block math', () => {
  it('replaces paragraph containing only block placeholder with texblox inlineExtension', () => {
    const map = new PlaceholderMap();
    const ph = map.add('mathblk', 'p(s) = (1-s)^\\alpha');

    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'paragraph',
        content: [{ type: 'text', text: ph }]
      }]
    };

    const result = postprocessAdf(doc, map);
    const node = result.content[0];
    assert.equal(node.type, 'inlineExtension');
    assert.ok(node.attrs.extensionKey.includes('texblox-macro'));
    assert.equal(node.attrs.parameters.guestParams.formula, 'p(s) = (1-s)^\\alpha');
    assert.equal(node.attrs.parameters.guestParams.displayMode, 'block');
  });
});

describe('postprocessAdf — TOC', () => {
  it('replaces paragraph containing only TOC placeholder with extension', () => {
    const map = new PlaceholderMap();
    const ph = map.add('toc', '');

    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'paragraph',
        content: [{ type: 'text', text: ph }]
      }]
    };

    const result = postprocessAdf(doc, map);
    const node = result.content[0];
    assert.equal(node.type, 'extension');
    assert.equal(node.attrs.extensionKey, 'toc');
    assert.deepEqual(node.attrs.parameters, {});
  });
});

describe('postprocessAdf — no mutation', () => {
  it('does not mutate the original doc', () => {
    const map = new PlaceholderMap();
    const ph = map.add('mathblk', 'x');
    const doc = {
      type: 'doc', version: 1,
      content: [{ type: 'paragraph', content: [{ type: 'text', text: ph }] }]
    };
    const original = JSON.stringify(doc);
    postprocessAdf(doc, map);
    assert.equal(JSON.stringify(doc), original);
  });
});

// ---------------------------------------------------------------------------
// postprocessMd — placeholder → Markdown syntax direction
// ---------------------------------------------------------------------------

describe('postprocessMd', () => {
  it('restores inline math', () => {
    const map = new PlaceholderMap();
    const ph = map.add('mathinl', 'x + y');
    const result = postprocessMd(`The value ${ph} is positive.`, map);
    assert.equal(result, 'The value $x + y$ is positive.');
  });

  it('restores block math', () => {
    const map = new PlaceholderMap();
    const ph = map.add('mathblk', 'p(s) = (1-s)^\\alpha');
    const result = postprocessMd(`Before.\n\n${ph}\n\nAfter.`, map);
    assert.ok(result.includes('$$\np(s) = (1-s)^\\alpha\n$$'));
  });

  it('restores TOC', () => {
    const map = new PlaceholderMap();
    const ph = map.add('toc', '');
    const result = postprocessMd(`# Title\n\n${ph}\n\n## Section`, map);
    assert.ok(result.includes('<!-- {toc} -->'));
  });
});
