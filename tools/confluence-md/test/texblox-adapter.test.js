import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { makeNode, isMatch, extract } from '../lib/adapters/texblox.js';

describe('texblox adapter — makeNode', () => {
  it('creates inline math node', () => {
    const node = makeNode('x + y', 'inline');
    assert.equal(node.type, 'inlineExtension');
    assert.ok(node.attrs.extensionKey.includes('texblox-macro'));
    assert.equal(node.attrs.parameters.guestParams.formula, 'x + y');
    assert.equal(node.attrs.parameters.guestParams.displayMode, 'inline');
  });

  it('creates block math node', () => {
    const node = makeNode('E = mc^2', 'block');
    assert.equal(node.attrs.parameters.guestParams.displayMode, 'block');
  });

  it('wraps single-char formula in braces', () => {
    const node = makeNode('x', 'inline');
    assert.equal(node.attrs.parameters.guestParams.formula, '{x}');
  });

  it('wraps single digit in braces', () => {
    const node = makeNode('0', 'inline');
    assert.equal(node.attrs.parameters.guestParams.formula, '{0}');
  });

  it('wraps purely numeric formula in braces', () => {
    const node = makeNode('0.95', 'inline');
    assert.equal(node.attrs.parameters.guestParams.formula, '{0.95}');
  });

  it('wraps integer-like numeric formula in braces', () => {
    const node = makeNode('1.0', 'inline');
    assert.equal(node.attrs.parameters.guestParams.formula, '{1.0}');
  });

  it('does not wrap formula with letters', () => {
    const node = makeNode('\\alpha', 'inline');
    assert.equal(node.attrs.parameters.guestParams.formula, '\\alpha');
  });

  it('does not wrap formula with operators and letters', () => {
    const node = makeNode('x + 1', 'inline');
    assert.equal(node.attrs.parameters.guestParams.formula, 'x + 1');
  });

  it('does not wrap formula with spaces around single char', () => {
    const node = makeNode(' x ', 'inline');
    assert.equal(node.attrs.parameters.guestParams.formula, '{x}',
      'should trim then wrap');
  });
});

describe('texblox adapter — isMatch', () => {
  it('recognizes texblox node', () => {
    const node = makeNode('x + y', 'inline');
    assert.ok(isMatch(node));
  });

  it('rejects non-texblox inlineExtension', () => {
    assert.ok(!isMatch({
      type: 'inlineExtension',
      attrs: { extensionKey: 'mathinline' },
    }));
  });

  it('rejects non-extension nodes', () => {
    assert.ok(!isMatch({ type: 'text', text: 'hello' }));
  });
});

describe('texblox adapter — extract', () => {
  it('extracts formula and displayMode', () => {
    const node = makeNode('\\frac{1}{2}', 'block');
    const { formula, displayMode } = extract(node);
    assert.equal(formula, '\\frac{1}{2}');
    assert.equal(displayMode, 'block');
  });

  it('reverses single-char brace workaround', () => {
    const node = makeNode('x', 'inline');
    // makeNode produces {x}, extract should reverse to x
    const { formula } = extract(node);
    assert.equal(formula, 'x');
  });

  it('reverses numeric brace workaround', () => {
    const node = makeNode('0.95', 'inline');
    // makeNode produces {0.95}, extract should reverse to 0.95
    const { formula } = extract(node);
    assert.equal(formula, '0.95');
  });

  it('does not strip braces from multi-char non-numeric content', () => {
    const node = makeNode('test', 'inline');
    node.attrs.parameters.guestParams.formula = '{abc}';
    const { formula } = extract(node);
    assert.equal(formula, '{abc}');
  });
});
