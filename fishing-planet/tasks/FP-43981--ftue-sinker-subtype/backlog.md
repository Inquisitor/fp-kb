# Backlog — FP-43981 investigation

## Decisions (2026-06-02)

- Acceptance on server story stays as drafted (end-to-end check after GD revert). Sequence is `server+client done → handoff to GD → GD reverts mission → QA on live mission`. The journal records the gated sequence so it's not lost.
- Link types finalised:
  - Server ↔ FP-43981 — `Relates`
  - Client ↔ FP-43981 — `Relates`
  - Client `is blocked by` Server (audit needs the new enum literal mirrored into the client repo by the server story)
  - GD ↔ FP-43981 — `Relates`
  - GD `is blocked by` Server (mission condition can only target a category that exists)
- Posting order: all three at once.

## Posting checklist

- [x] Post server story to FP-32325 — [FP-44228](https://fishingplanet.atlassian.net/browse/FP-44228)
- [x] Post client story to FP-32325 — [FP-44229](https://fishingplanet.atlassian.net/browse/FP-44229)
- [x] Post GD follow-up story to FP-32325 — [FP-44230](https://fishingplanet.atlassian.net/browse/FP-44230)
- [x] Apply links per Decisions above (5 links: Relates × 3 to FP-43981, Blocks × 2 from FP-44228)
- [x] Record new JIRA IDs in `journal.md` frontmatter `related:`
- [x] Bubble investigation findings (numeric-collision pattern, OR-merge matcher behavior) into module `equipment-rules/log.md` as a `Finding:` entry (recorded 2026-06-03, ahead of close while context is fresh)

## Deferred / candidate epics

- [ ] Broad audit of `IT.X == IST.X` numeric collisions across the enum (`Hook = 6`, `Bobber = 7`, `Bait = 10`, `Lure = 11`, `Leader = 66`, etc.) — each pair carries the same hint-disambiguation risk uncovered here. Candidate for a separate epic
- [ ] Decision on whether to obsolete `ItemSubTypes.Sinker = 8` outright once enough subtype-class-aware code is migrated (currently keeping for backward compat)
