// JIRA issue JSON → readable markdown briefing.
// Designed for getJiraIssue responses from Atlassian MCP plugin.

import { toMd } from './to-md.js';

/**
 * Format a JIRA issue JSON response into a readable markdown briefing.
 * @param {object} json - Full getJiraIssue response ({issues: {totalCount, nodes: [...]}})
 * @returns {string} Formatted markdown
 */
export function formatJiraIssue(json) {
  const issue = extractIssue(json);
  const fields = issue.fields;
  validateComments(fields);

  const parts = [];
  parts.push(formatHeader(issue));
  parts.push(formatDescription(fields));
  parts.push(formatTimeline(issue));
  parts.push(formatComments(fields));

  return parts.join('\n\n') + '\n';
}

// --- extraction & validation ---

function extractIssue(json) {
  // Format 1: MCP wrapped response — {issues: {nodes: [{...}]}}
  if (json?.issues?.nodes?.[0]) {
    return json.issues.nodes[0];
  }
  // Format 2: Content block wrapper — [{type: "text", text: "<json>"}]
  if (Array.isArray(json) && json[0]?.type === 'text' && json[0]?.text) {
    const inner = JSON.parse(json[0].text);
    return extractIssue(inner);
  }
  // Format 3: Raw JIRA REST response — {key, fields, changelog}
  if (json?.key && json?.fields) {
    return json;
  }
  throw new Error('No issue data found in JSON — unrecognized response format');
}

function validateComments(fields) {
  if (!fields.comment) {
    throw new Error('Comment field not found — check getJiraIssue fields parameter');
  }
  if (!Array.isArray(fields.comment.comments)) {
    throw new Error('Unexpected comment structure — API format may have changed');
  }
}

// --- formatters ---

function formatHeader(issue) {
  const f = issue.fields;
  const summary = f.summary || '[No summary]';
  const status = f.status?.name || 'Unknown';
  const category = f.status?.statusCategory?.name;
  const assignee = f.assignee?.displayName || 'Unassigned';
  const resolution = f.resolution?.name;
  const resDate = f.resolutiondate ? f.resolutiondate.slice(0, 10) : null;

  let line1 = `# ${issue.key}: ${summary}`;
  let line2 = `**Status:** ${status}`;
  if (category) line2 += ` (${category})`;
  line2 += ` | **Assignee:** ${assignee}`;

  if (resolution) {
    line2 += `\n**Resolution:** ${resolution}`;
    if (resDate) line2 += ` | **Resolved:** ${resDate}`;
  }

  return `${line1}\n${line2}`;
}

function formatDescription(fields) {
  if (!fields.description) {
    return '## Description\n[No description]';
  }
  if (typeof fields.description === 'string') {
    return `## Description\n${fields.description}`;
  }
  const { md } = convertAdf(fields.description);
  return `## Description\n${md}`;
}

function convertAdf(adf) {
  try {
    return toMd(adf);
  } catch (err) {
    return { md: `[ADF conversion error: ${err.message}]`, warnings: [] };
  }
}

function formatTimeline(issue) {
  const changelog = issue.changelog;
  if (!changelog) {
    return '## Timeline\n[Changelog not available — use expand=changelog]';
  }

  const events = [];
  for (const history of changelog.histories || []) {
    const author = history.author?.displayName || 'Unknown';
    for (const item of history.items || []) {
      if (item.field === 'status') {
        events.push({
          date: history.created,
          text: `→ ${item.toString} (${author})`
        });
      } else if (item.field === 'assignee') {
        events.push({
          date: history.created,
          text: `Assignee → ${item.toString || 'Unassigned'}`
        });
      }
    }
  }

  if (events.length === 0) {
    return '## Timeline\n(no status or assignee changes)';
  }

  events.sort((a, b) => new Date(a.date) - new Date(b.date));

  const rows = events.map(e => `| ${formatDateTime(e.date)} | ${e.text} |`);
  return `## Timeline\n| Date | Event |\n|------|-------|\n${rows.join('\n')}`;
}

function formatComments(fields) {
  const comments = fields.comment.comments;
  if (comments.length === 0) {
    return '## Comments (0)\n(none)';
  }

  const parts = [`## Comments (${comments.length})`];

  for (const c of comments) {
    const author = c.author?.displayName || 'Unknown';
    const created = formatDateTime(c.created);
    const id = c.id;
    let header = `### ${author} — ${created} [id:${id}]`;

    if (c.updated && c.updated !== c.created) {
      header += ` *(edited ${formatDateTime(c.updated)})*`;
    }

    const body = (c.body && typeof c.body === 'object') ? c.body : null;
    const { md } = body
      ? convertAdf(body)
      : { md: `[ADF conversion error: body is not an object]` };
    parts.push(`${header}\n${md}`);
  }

  return parts.join('\n\n');
}

/** "2026-03-01T10:00:00.000+0200" → "2026-03-01 10:00" */
function formatDateTime(iso) {
  const match = iso.match(/^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})/);
  return match ? `${match[1]} ${match[2]}` : iso;
}
