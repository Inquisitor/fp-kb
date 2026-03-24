import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { PlaceholderMap } from '../lib/placeholder.js';

describe('PlaceholderMap', () => {
  it('creates sequential inline math placeholders', () => {
    const map = new PlaceholderMap();
    const p1 = map.add('mathinl', 'x + y');
    const p2 = map.add('mathinl', 'a^2');
    assert.equal(p1, 'CFMD_MATHINL_0001');
    assert.equal(p2, 'CFMD_MATHINL_0002');
  });

  it('creates block math placeholders', () => {
    const map = new PlaceholderMap();
    const p = map.add('mathblk', 'p(s) = (1-s)^\\alpha');
    assert.equal(p, 'CFMD_MATHBLK_0001');
  });

  it('creates TOC placeholders', () => {
    const map = new PlaceholderMap();
    const p = map.add('toc', '');
    assert.equal(p, 'CFMD_TOC_0001');
  });

  it('retrieves stored content by placeholder ID', () => {
    const map = new PlaceholderMap();
    const p = map.add('mathinl', 'x + y');
    const entry = map.get(p);
    assert.deepEqual(entry, { type: 'mathinl', content: 'x + y' });
  });

  it('returns undefined for unknown placeholder', () => {
    const map = new PlaceholderMap();
    assert.equal(map.get('CFMD_MATHINL_9999'), undefined);
  });

  it('lists all entries', () => {
    const map = new PlaceholderMap();
    map.add('mathinl', 'a');
    map.add('mathblk', 'b');
    assert.equal(map.size, 2);
  });

  it('builds regex matching all placeholders of a given type', () => {
    const map = new PlaceholderMap();
    map.add('mathinl', 'x');
    map.add('mathinl', 'y');
    const re = map.regex('mathinl');
    assert.ok(re.test('CFMD_MATHINL_0001'));
    assert.ok(re.test('CFMD_MATHINL_0002'));
    assert.ok(!re.test('CFMD_MATHBLK_0001'));
  });
});
