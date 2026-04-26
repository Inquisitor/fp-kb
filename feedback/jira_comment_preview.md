---
name: JIRA comment preview before posting
description: Always show JIRA comment text for user review before calling the Atlassian MCP tool to post it
type: feedback
---

Always show the JIRA comment as a text preview and ask for approval BEFORE calling `addCommentToJiraIssue`.

**Why:** User wants to review and potentially edit the comment before it's posted. Once posted, it's visible to the team and harder to fix.

**How to apply:**
1. Before draft: show JIRA issue link — `Issue: https://fishingplanet.atlassian.net/browse/FP-XXXXX`
2. Show formatted draft text, ask "Постить?"
3. Only call MCP tool after explicit approval
4. After posting: show direct comment permalink — `Posted: https://fishingplanet.atlassian.net/browse/FP-XXXXX?focusedId=NNNNN&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-NNNNN` (comment ID from API response)
