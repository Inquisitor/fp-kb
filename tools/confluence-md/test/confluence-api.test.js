import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

describe('confluence-api', () => {
  it('module loads without error', async () => {
    // Verify the module can be imported and exports expected functions
    const mod = await import('../lib/confluence-api.js');
    assert.ok(typeof mod.loadCredentials === 'function');
    assert.ok(typeof mod.getPage === 'function');
    assert.ok(typeof mod.updatePage === 'function');
  });
});
