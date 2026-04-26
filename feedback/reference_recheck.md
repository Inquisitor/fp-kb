---
name: Re-read reference file before drafting
description: Reference files carrying format/convention must be re-read at draft-time, not relied on from session-start prefetch — read-time loading does not guarantee write-time application
type: feedback
---
When drafting any artifact whose format is defined in a file under `<kb>/reference/` (JIRA comment format, JIRA merge comment format, commit message conventions, etc.), Read the reference file again immediately before producing the draft. Do not rely on having loaded it earlier in the session.

**Why:** Loading a reference file earlier in the session does not guarantee its format is applied at draft-time. Free-form prose drafts slip in even when the canonical format was previously read.

**How to apply:** Before producing a draft of anything that has a reference-defined shape — JIRA comment, JIRA merge comment, commit message, ADF structure — Read the relevant `<kb>/reference/<name>.md` first. Treat the reference as a write-time checklist, not as background knowledge that "should already be applied".

The broader principle: file entries are not self-activating. For format/convention rules, the only reliable activation is fresh re-read at the moment of use.
