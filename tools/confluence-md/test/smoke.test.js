import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Parser } from 'extended-markdown-adf-parser';

describe('smoke tests', () => {
  const parser = new Parser();

  it('converts simple markdown to ADF', () => {
    const md = readFileSync(new URL('./fixtures/simple.md', import.meta.url), 'utf8');
    const adf = parser.markdownToAdf(md);

    assert.equal(adf.type, 'doc');
    assert.ok(adf.content.length > 0, 'ADF content should be non-empty');
    assert.equal(adf.version, 1);
  });

  it('converts ADF back to markdown', () => {
    const md = readFileSync(new URL('./fixtures/simple.md', import.meta.url), 'utf8');
    const adf = parser.markdownToAdf(md);
    const result = parser.adfToMarkdown(adf);

    assert.ok(result.includes('# Hello'), 'roundtrip should preserve heading');
    assert.ok(result.includes('**bold**'), 'roundtrip should preserve bold');
  });

  it('handles panel syntax', () => {
    const md = '~~~panel type=info\nContent\n~~~\n';
    const adf = parser.markdownToAdf(md);

    const panel = adf.content.find(n => n.type === 'panel');
    assert.ok(panel, 'ADF should contain a panel node');
    assert.equal(panel.attrs.panelType, 'info');
  });

  it('handles status syntax', () => {
    const md = '{status:Draft|color:yellow}\n';
    const adf = parser.markdownToAdf(md);

    // Status is inline, so it lives inside a paragraph
    const para = adf.content.find(n => n.type === 'paragraph');
    assert.ok(para, 'ADF should contain a paragraph');
    const status = para.content.find(n => n.type === 'status');
    assert.ok(status, 'paragraph should contain a status node');
    assert.equal(status.attrs.text, 'Draft');
    assert.equal(status.attrs.color, 'yellow');
  });
});
