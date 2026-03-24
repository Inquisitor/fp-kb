import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { MediaRegistry } from '../lib/media.js';

const SAMPLE_YAML = `
media:
  31938793-5f3b-4d4c-adb9-7b0eb6ba8a59:
    filename: fig1.svg
    page_id: 5450858521
    source: modules/fish-generator/fig1.svg
    uploaded: 2026-03-24
  aaaabbbb-cccc-dddd-eeee-ffffffffffff:
    filename: fig2.svg
    page_id: 5449973771
    source: modules/fish-generator/fig2.svg
    uploaded: 2026-03-24
`;

describe('MediaRegistry', () => {
  let registry;
  beforeEach(() => { registry = MediaRegistry.fromYaml(SAMPLE_YAML); });

  it('parses YAML and looks up by filename + page_id', () => {
    const entry = registry.findByFilename('fig1.svg', '5450858521');
    assert.equal(entry.id, '31938793-5f3b-4d4c-adb9-7b0eb6ba8a59');
  });

  it('returns null for unknown filename', () => {
    assert.equal(registry.findByFilename('unknown.svg', '5450858521'), null);
  });

  it('returns null for wrong page_id', () => {
    assert.equal(registry.findByFilename('fig1.svg', '9999999'), null);
  });

  it('looks up by media ID', () => {
    const entry = registry.findById('31938793-5f3b-4d4c-adb9-7b0eb6ba8a59');
    assert.equal(entry.filename, 'fig1.svg');
  });

  it('returns null for unknown ID', () => {
    assert.equal(registry.findById('nonexistent-uuid'), null);
  });

  it('adds a new entry', () => {
    registry.add('new-uuid', { filename: 'fig3.svg', page_id: '123', uploaded: '2026-03-25' });
    const entry = registry.findById('new-uuid');
    assert.equal(entry.filename, 'fig3.svg');
  });

  it('serializes back to YAML', () => {
    const yaml = registry.toYaml();
    assert.ok(yaml.includes('31938793'));
    assert.ok(yaml.includes('fig1.svg'));
    assert.ok(yaml.includes('media:'));
  });

  it('creates empty registry', () => {
    const empty = new MediaRegistry();
    assert.equal(empty.findById('anything'), null);
    const yaml = empty.toYaml();
    assert.ok(yaml.includes('media:'));
  });
});
