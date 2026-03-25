// Jira issue link ↔ inlineCard conversion.
//
// upgradeJiraLinks(doc)   — MD→ADF: link marks → inlineCard nodes
// downgradeJiraLinks(doc) — ADF→MD: inlineCard nodes → link marks

// Matches any Atlassian Jira browse URL, captures the issue key.
const JIRA_URL_RE = /^https?:\/\/[^/]+\.atlassian\.net\/browse\/([A-Z][A-Z0-9]+-\d+)\/?$/;

/**
 * Extract issue key from a Jira browse URL, or null.
 */
function extractIssueKey(url) {
  const m = url.match(JIRA_URL_RE);
  return m ? m[1] : null;
}

// ---------------------------------------------------------------------------
// MD → ADF: upgrade text+link → inlineCard
// ---------------------------------------------------------------------------

/**
 * Finds text nodes with Jira link marks and replaces them with inlineCard
 * nodes — but only when the text matches the issue key or the full URL
 * (i.e. the author didn't use custom anchor text).
 *
 * Returns a new document; does not mutate the input.
 */
export function upgradeJiraLinks(doc) {
  const result = JSON.parse(JSON.stringify(doc));
  walkUpgrade(result);
  return result;
}

function walkUpgrade(node) {
  if (!node.content) return;

  for (let i = 0; i < node.content.length; i++) {
    const child = node.content[i];

    if (child.type === 'text' && child.marks) {
      const linkMark = child.marks.find(m => m.type === 'link');
      if (linkMark) {
        const href = linkMark.attrs?.href ?? '';
        const key = extractIssueKey(href);
        if (key && (child.text === key || child.text === href)) {
          node.content[i] = {
            type: 'inlineCard',
            attrs: { url: href },
          };
          continue;
        }
      }
    }

    walkUpgrade(child);
  }
}

// ---------------------------------------------------------------------------
// ADF → MD: downgrade inlineCard → text+link
// ---------------------------------------------------------------------------

/**
 * Finds inlineCard nodes with Jira URLs and replaces them with regular
 * text nodes carrying a link mark — so the package emits clean
 * [KEY](url) markdown instead of adf://card/ garbage.
 *
 * Non-Jira inlineCards are left as-is.
 * Returns a new document; does not mutate the input.
 */
export function downgradeJiraLinks(doc) {
  const result = JSON.parse(JSON.stringify(doc));
  walkDowngrade(result);
  return result;
}

function walkDowngrade(node) {
  if (!node.content) return;

  for (let i = 0; i < node.content.length; i++) {
    const child = node.content[i];

    if (child.type === 'inlineCard') {
      const url = child.attrs?.url ?? '';
      const key = extractIssueKey(url);
      if (key) {
        node.content[i] = {
          type: 'text',
          text: key,
          marks: [{ type: 'link', attrs: { href: url } }],
        };
        continue;
      }
    }

    walkDowngrade(child);
  }
}
