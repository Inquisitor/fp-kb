---
name: JIRA required fields on issue create
description: FP project requires the Scrum Team field on create; customfield_11001 option ids + create cheat-sheet
type: reference
---
Creating an issue in the **FP** project via the JIRA API fails with `"The Scrum Team field must be set"` unless **Scrum Team** is supplied. It is a single-select custom field, separate from any agile board team.

- **Scrum Team:** `customfield_11001` — pass `{"customfield_11001": {"id": "<optionId>"}}` in the create fields.
  - Option ids: Other=`10203`, LiveOps=`10384`, Community&Support=`10301`, Leaderboards=`10637`, FTUE=`10636`, Tournaments&Events=`10200`, UI/UX=`10204`, Norway=`10427`, General Activity=`10703`, Tech Debt=`10783`, Fathers Day=`10816`.
- **Components** are a fixed select (valid names incl. Server, Web, Photon, WebAdmin, Infrastructure, QA, Client, Game Design, Localization, ...).
- **Priority** uses standard names (Highest / High / Medium / Low / Lowest).
- **Platform:** `customfield_11143` — **multi-select**, **not required**. Leave it unset for tasks that are not tied to a specific platform (cross-platform / server-wide work); only set it when the issue is genuinely platform-scoped. When set, the value MUST be an **array** even for a single platform: `{"customfield_11143": [{"id": "<optionId>"}]}`. Passing a bare object fails with `"Specify the value for Platform in an array"`. Option ids: Steam=`10304`, EGS=`10328`, PS4=`10307`, Xbox=`10308`, IOS=`10310`, Android=`10311`, Nintendo=`10460`, UWP=`10309`, All=`10303`.
- **Single-select vs multi-select gotcha:** single-select custom fields (e.g. Scrum Team) take an object `{"id": ...}`; multi-select custom fields (e.g. Platform) take an array of objects `[{"id": ...}]`. Mixing the two shapes is the common create-time error — the API message names the offending field.
- **Issue types:** FP has **no "Task" type** (passing it → `"Specify a valid issue type"`). Standard (hierarchyLevel 0) types: `Story`, `Bug`, `Proposal`, `Activity`; plus `Epic` (level 1). Use **Story** as the Task equivalent.
- **Epic ← Story** linkage: set the story's `parent` field to the epic key (`editJiraIssue` with `{"parent": {"key": "FP-XXXXX"}}`). Blocks/Relates between issues use issue links (`Blocks` / `Relates`), not the parent field.
- fishingplanet **cloudId:** `21c52b88-9777-4cde-bbe9-78e4dde647ab`.

**Related custom fields:** Executor `customfield_11224` (see [JIRA Executor field](jira_executor_field.md)); Server Release Checklist Steps `customfield_11323` (see [release checklist field](release_checklist_field.md)).

**How to discover:** `getJiraIssueTypeMetaWithFields(project, issueTypeId)` lists required fields and their `allowedValues`; the create error message names the missing field.
