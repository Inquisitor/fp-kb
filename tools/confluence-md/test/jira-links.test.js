import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { upgradeJiraLinks, downgradeJiraLinks } from '../lib/jira-links.js';

// ---------------------------------------------------------------------------
// MD → ADF: upgrade link marks → inlineCard
// ---------------------------------------------------------------------------

describe('upgradeJiraLinks (MD→ADF)', () => {
  it('upgrades markdown link where text = issue key', () => {
    const doc = makeDoc([
      textNode('See '),
      linkedText('FP-41844', 'https://fishingplanet.atlassian.net/browse/FP-41844'),
      textNode(' for details.'),
    ]);
    const result = upgradeJiraLinks(doc);
    const para = result.content[0];
    assert.equal(para.content.length, 3);
    assert.deepEqual(para.content[1], {
      type: 'inlineCard',
      attrs: { url: 'https://fishingplanet.atlassian.net/browse/FP-41844' },
    });
  });

  it('upgrades bare URL (text = full URL)', () => {
    const url = 'https://fishingplanet.atlassian.net/browse/FP-41844';
    const doc = makeDoc([linkedText(url, url)]);
    const result = upgradeJiraLinks(doc);
    assert.equal(result.content[0].content[0].type, 'inlineCard');
  });

  it('does NOT upgrade when text differs from issue key', () => {
    const doc = makeDoc([
      linkedText('implementation task', 'https://fishingplanet.atlassian.net/browse/FP-41844'),
    ]);
    const result = upgradeJiraLinks(doc);
    const node = result.content[0].content[0];
    assert.equal(node.type, 'text');
    assert.equal(node.text, 'implementation task');
  });

  it('does NOT upgrade non-Jira links', () => {
    const doc = makeDoc([
      linkedText('Google', 'https://google.com'),
    ]);
    const result = upgradeJiraLinks(doc);
    assert.equal(result.content[0].content[0].type, 'text');
  });

  it('upgrades multiple Jira links in one paragraph', () => {
    const doc = makeDoc([
      linkedText('FP-41844', 'https://fishingplanet.atlassian.net/browse/FP-41844'),
      textNode(' and '),
      linkedText('FP-41845', 'https://fishingplanet.atlassian.net/browse/FP-41845'),
    ]);
    const result = upgradeJiraLinks(doc);
    const para = result.content[0];
    assert.equal(para.content[0].type, 'inlineCard');
    assert.equal(para.content[2].type, 'inlineCard');
  });

  it('handles different Atlassian domains', () => {
    const doc = makeDoc([
      linkedText('PROJ-123', 'https://mycompany.atlassian.net/browse/PROJ-123'),
    ]);
    const result = upgradeJiraLinks(doc);
    assert.equal(result.content[0].content[0].type, 'inlineCard');
  });

  it('upgrades links inside nested structures (blockquote, table)', () => {
    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'blockquote',
        content: [{
          type: 'paragraph',
          content: [
            linkedText('FP-41844', 'https://fishingplanet.atlassian.net/browse/FP-41844'),
          ],
        }],
      }],
    };
    const result = upgradeJiraLinks(doc);
    const innerPara = result.content[0].content[0];
    assert.equal(innerPara.content[0].type, 'inlineCard');
  });

  it('does not mutate the original document', () => {
    const doc = makeDoc([
      linkedText('FP-41844', 'https://fishingplanet.atlassian.net/browse/FP-41844'),
    ]);
    const original = JSON.stringify(doc);
    upgradeJiraLinks(doc);
    assert.equal(JSON.stringify(doc), original);
  });
});

// ---------------------------------------------------------------------------
// ADF → MD: downgrade inlineCard → link mark
// ---------------------------------------------------------------------------

describe('downgradeJiraLinks (ADF→MD)', () => {
  it('converts inlineCard to text node with link mark', () => {
    const doc = makeDoc([
      textNode('See '),
      { type: 'inlineCard', attrs: { url: 'https://fishingplanet.atlassian.net/browse/FP-41844' } },
      textNode(' for details.'),
    ]);
    const result = downgradeJiraLinks(doc);
    const node = result.content[0].content[1];
    assert.equal(node.type, 'text');
    assert.equal(node.text, 'FP-41844');
    assert.equal(node.marks[0].type, 'link');
    assert.equal(node.marks[0].attrs.href, 'https://fishingplanet.atlassian.net/browse/FP-41844');
  });

  it('preserves non-Jira inlineCard as-is', () => {
    const doc = makeDoc([
      { type: 'inlineCard', attrs: { url: 'https://example.com/page' } },
    ]);
    const result = downgradeJiraLinks(doc);
    assert.equal(result.content[0].content[0].type, 'inlineCard');
  });

  it('handles inlineCard inside nested structures', () => {
    const doc = {
      type: 'doc', version: 1,
      content: [{
        type: 'blockquote',
        content: [{
          type: 'paragraph',
          content: [
            { type: 'inlineCard', attrs: { url: 'https://fishingplanet.atlassian.net/browse/FP-41845' } },
          ],
        }],
      }],
    };
    const result = downgradeJiraLinks(doc);
    const node = result.content[0].content[0].content[0];
    assert.equal(node.type, 'text');
    assert.equal(node.text, 'FP-41845');
  });

  it('does not mutate the original document', () => {
    const doc = makeDoc([
      { type: 'inlineCard', attrs: { url: 'https://fishingplanet.atlassian.net/browse/FP-41844' } },
    ]);
    const original = JSON.stringify(doc);
    downgradeJiraLinks(doc);
    assert.equal(JSON.stringify(doc), original);
  });
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeDoc(paragraphContent) {
  return {
    type: 'doc', version: 1,
    content: [{ type: 'paragraph', content: paragraphContent }],
  };
}

function textNode(text) {
  return { type: 'text', text };
}

function linkedText(text, href) {
  return {
    type: 'text',
    text,
    marks: [{ type: 'link', attrs: { href } }],
  };
}
