import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { downgradeImages } from '../lib/image-downgrader.js';

describe('downgradeImages (ADF→MD)', () => {
  it('converts mediaSingle with known fileId to image markdown', () => {
    const doc = makeDocWithMedia('file-123', 'fig.svg', 'Figure 1');
    const nameMap = new Map([['file-123', 'fig.svg']]);
    const { doc: result, warnings } = downgradeImages(doc, nameMap);

    assert.equal(warnings.length, 0);
    const para = result.content[0];
    assert.equal(para.type, 'paragraph');
    assert.equal(para.content[0].text, '![Figure 1](fig.svg)');
  });

  it('uses alt attr as fallback filename when fileId not in map', () => {
    const doc = makeDocWithMedia('unknown-id', 'diagram.svg', 'My Diagram');
    const { doc: result, warnings } = downgradeImages(doc, new Map());

    assert.equal(warnings.length, 1);
    assert.ok(warnings[0].includes('unknown-id'));
    const para = result.content[0];
    assert.equal(para.content[0].text, '![My Diagram](diagram.svg)');
  });

  it('falls back to media:fileId when no alt and no map entry', () => {
    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'mediaSingle',
        attrs: { layout: 'center' },
        content: [{
          type: 'media',
          attrs: { id: 'abc-999', type: 'file', collection: 'contentId-123' },
        }],
      }],
    };
    const { doc: result } = downgradeImages(doc, new Map());
    assert.equal(result.content[0].content[0].text, '![](media:abc-999)');
  });

  it('uses caption text over media alt', () => {
    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'mediaSingle',
        attrs: { layout: 'center' },
        content: [
          { type: 'media', attrs: { id: 'f1', type: 'file', alt: 'raw-name.svg' } },
          { type: 'caption', content: [{ type: 'text', text: 'Figure 1: Nice caption' }] },
        ],
      }],
    };
    const nameMap = new Map([['f1', 'raw-name.svg']]);
    const { doc: result } = downgradeImages(doc, nameMap);
    assert.equal(result.content[0].content[0].text, '![Figure 1: Nice caption](raw-name.svg)');
  });

  it('handles nested mediaSingle (inside panel)', () => {
    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'panel', attrs: { panelType: 'info' },
        content: [{
          type: 'mediaSingle',
          attrs: { layout: 'center' },
          content: [
            { type: 'media', attrs: { id: 'f1', type: 'file', alt: 'fig.svg' } },
          ],
        }],
      }],
    };
    const nameMap = new Map([['f1', 'fig.svg']]);
    const { doc: result } = downgradeImages(doc, nameMap);
    assert.equal(result.content[0].content[0].type, 'paragraph');
    assert.ok(result.content[0].content[0].content[0].text.includes('!['));
  });

  it('does not mutate the original document', () => {
    const doc = makeDocWithMedia('f1', 'fig.svg', 'Fig');
    const original = JSON.stringify(doc);
    downgradeImages(doc, new Map([['f1', 'fig.svg']]));
    assert.equal(JSON.stringify(doc), original);
  });
});

function makeDocWithMedia(fileId, altFilename, captionText) {
  return {
    type: 'doc', version: 1,
    content: [{
      type: 'mediaSingle',
      attrs: { layout: 'center', width: 760, widthType: 'pixel' },
      content: [
        { type: 'media', attrs: { id: fileId, type: 'file', alt: altFilename, collection: 'contentId-999' } },
        ...(captionText ? [{ type: 'caption', content: [{ type: 'text', text: captionText }] }] : []),
      ],
    }],
  };
}
