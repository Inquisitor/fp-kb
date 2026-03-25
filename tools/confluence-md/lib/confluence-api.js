// confluence-api.js — Confluence REST API client (v2)
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const CREDENTIALS_PATH = join(homedir(), '.config', 'confluence', 'credentials');

export function loadCredentials() {
  let text;
  try {
    text = readFileSync(CREDENTIALS_PATH, 'utf8');
  } catch (err) {
    throw new Error(
      `Cannot read credentials from ${CREDENTIALS_PATH}\n` +
      `Create this file with:\n  site=your-site.atlassian.net\n  email=your@email.com\n  token=your-api-token\n`
    );
  }
  const creds = {};
  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq > 0) {
      creds[trimmed.slice(0, eq).trim()] = trimmed.slice(eq + 1).trim();
    }
  }
  if (!creds.site || !creds.email || !creds.token) {
    throw new Error(`Credentials file must contain site, email, and token fields`);
  }
  return creds;
}

function authHeader(creds) {
  const encoded = Buffer.from(`${creds.email}:${creds.token}`).toString('base64');
  return `Basic ${encoded}`;
}

/**
 * Get a Confluence page (ADF body + version info).
 * @param {string} pageId
 * @param {object} creds - from loadCredentials()
 * @returns {Promise<{title: string, version: number, adf: object}>}
 */
export async function getPage(pageId, creds) {
  const url = `https://${creds.site}/wiki/api/v2/pages/${pageId}?body-format=atlas_doc_format`;
  const res = await fetch(url, {
    headers: {
      'Authorization': authHeader(creds),
      'Accept': 'application/json',
    },
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`GET page ${pageId} failed (${res.status}): ${body}`);
  }
  const data = await res.json();
  return {
    title: data.title,
    version: data.version.number,
    adf: JSON.parse(data.body.atlas_doc_format.value),
  };
}

/**
 * Update a Confluence page with new ADF content.
 * Automatically fetches current version and increments.
 * @param {string} pageId
 * @param {object} adf - ADF document object
 * @param {object} creds - from loadCredentials()
 * @param {string} [versionMessage] - optional version comment
 * @returns {Promise<{version: number, title: string}>}
 */
export async function updatePage(pageId, adf, creds, versionMessage) {
  // Get current version
  const current = await getPage(pageId, creds);

  const url = `https://${creds.site}/wiki/api/v2/pages/${pageId}`;
  const body = {
    id: pageId,
    status: 'current',
    title: current.title,
    body: {
      representation: 'atlas_doc_format',
      value: JSON.stringify(adf),
    },
    version: {
      number: current.version + 1,
      message: versionMessage || 'Updated via confluence-md',
    },
  };

  const res = await fetch(url, {
    method: 'PUT',
    headers: {
      'Authorization': authHeader(creds),
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const respBody = await res.text();
    throw new Error(`PUT page ${pageId} failed (${res.status}): ${respBody}`);
  }
  const data = await res.json();
  return { version: data.version.number, title: data.title };
}
