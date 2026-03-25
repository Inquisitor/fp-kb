import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { resolveImages } from '../lib/image-resolver.js';
import { PlaceholderMap } from '../lib/placeholder.js';

describe('resolveImages', () => {
  it('replaces image placeholder with mediaSingle when fileId available', () => {
    const map = new PlaceholderMap();
    const ph = map.add('image', { alt: 'Figure 1', path: 'images/fig1.svg' });
    const doc = makeDoc([{ type: 'text', text: ph }]);
    const fileIdMap = new Map([['fig1.svg', 'abc-123']]);

    const { doc: result, warnings } = resolveImages(doc, map, fileIdMap, '999');
    assert.equal(warnings.length, 0);
    const media = result.content[0];
    assert.equal(media.type, 'mediaSingle');
    assert.equal(media.attrs.layout, 'center');
    assert.equal(media.content[0].type, 'media');
    assert.equal(media.content[0].attrs.id, 'abc-123');
    assert.equal(media.content[0].attrs.collection, 'contentId-999');
    // Caption from alt
    assert.equal(media.content[1].type, 'caption');
    assert.equal(media.content[1].content[0].text, 'Figure 1');
  });

  it('produces warning paragraph when fileId not available', () => {
    const map = new PlaceholderMap();
    const ph = map.add('image', { alt: 'Fig', path: '../../modules/fig.svg' });
    const doc = makeDoc([{ type: 'text', text: ph }]);
    const fileIdMap = new Map(); // empty — no uploads

    const { doc: result, warnings } = resolveImages(doc, map, fileIdMap, '999');
    assert.equal(warnings.length, 1);
    assert.ok(warnings[0].includes('fig.svg'));
    const para = result.content[0];
    assert.equal(para.type, 'paragraph');
    assert.ok(para.content[0].text.includes('⚠'));
  });

  it('handles image with empty alt (no caption)', () => {
    const map = new PlaceholderMap();
    const ph = map.add('image', { alt: '', path: 'diagram.svg' });
    const doc = makeDoc([{ type: 'text', text: ph }]);
    const fileIdMap = new Map([['diagram.svg', 'def-456']]);

    const { doc: result } = resolveImages(doc, map, fileIdMap, '999');
    const media = result.content[0];
    assert.equal(media.type, 'mediaSingle');
    // No caption node
    assert.equal(media.content.length, 1);
  });

  it('resolves images in nested structures', () => {
    const map = new PlaceholderMap();
    const ph = map.add('image', { alt: 'Fig', path: 'fig.svg' });
    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'panel', attrs: { panelType: 'info' },
        content: [{ type: 'paragraph', content: [{ type: 'text', text: ph }] }],
      }],
    };
    const fileIdMap = new Map([['fig.svg', 'ghi-789']]);
    const { doc: result } = resolveImages(doc, map, fileIdMap, '999');
    assert.equal(result.content[0].content[0].type, 'mediaSingle');
  });

  it('resolves filename from relative path (uses last segment)', () => {
    const map = new PlaceholderMap();
    const ph = map.add('image', { alt: 'Fig', path: '../../server/modules/fish/deep-fig.svg' });
    const doc = makeDoc([{ type: 'text', text: ph }]);
    const fileIdMap = new Map([['deep-fig.svg', 'xyz-000']]);
    const { doc: result, warnings } = resolveImages(doc, map, fileIdMap, '999');
    assert.equal(warnings.length, 0);
    assert.equal(result.content[0].type, 'mediaSingle');
  });

  it('does not mutate the original document', () => {
    const map = new PlaceholderMap();
    const ph = map.add('image', { alt: 'Fig', path: 'fig.svg' });
    const doc = makeDoc([{ type: 'text', text: ph }]);
    const original = JSON.stringify(doc);
    resolveImages(doc, map, new Map([['fig.svg', 'id']]), '999');
    assert.equal(JSON.stringify(doc), original);
  });
});

function makeDoc(paragraphContent) {
  return {
    type: 'doc', version: 1,
    content: [{ type: 'paragraph', content: paragraphContent }],
  };
}
