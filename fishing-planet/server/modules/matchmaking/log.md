# Decision Log — Matchmaking

## 2026-04-15
- New matchmaking tech spec replaces obsolete TDD matchmaking section. Decision: write from-code spec instead of patching old TDD. Rationale: old TDD was a planning doc covering 4 areas (Rating, Leaderboards, Matchmaking, Scheduling) — patching one section leaves the rest inconsistent. Fresh spec from code audit is authoritative
- Confluence Business Logic reorganized: Competitive as system landing page, Matchmaking + Leaderboards as child pages. Mirrors KB `_systems/` concept
- FFS naming clarified: "Free-Fill-Swap" (origin: algorithm phases), "Fair Fill Strategy" (backronym for GDD/player-facing context)

## 2026-03-09
- DB rename approach: full `sp_rename` + ConfigJson `REPLACE` instead of DAL mapper abstraction. Simpler, no runtime overhead, atomic with downtime
- ConfigJson dead param removal: `REPLACE` (preserves formatting) over `JSON_MODIFY` (reformats entire JSON). Game designers rely on specific indentation/line breaks
- Patch idempotency: `IF EXISTS` for DDL, `REPLACE` with `WHERE LIKE` for data ops — safe for re-execution after version bump
- Lesson: handle both CRLF and LF in ConfigJson REPLACE patterns (LF fallback pass)

## 2026-03-05
- `GroupName` on DTO/model classes (P6-P14) stores the **group name** (final competition unit), NOT the bracket name. Do NOT rename to `BracketName` — it is already correct in unified terminology
- DAL reflection mapper constraints affected rename approach — see [DAL log](../dal/log.md)
- Test case description convention for matchmaking tests: `"<who> pulls <N> from <source> (reaches <result>)[; <next action>][; <Phase B: ...>]"`. Trivial cases stay simple: `"Only third group has players, it is complete"`

## 2026-02-18
- Terminology rename: Groups→Buckets, GroupSettings→Brackets, SubGroups→Groups. Adopted GDD terminology as canonical
- Lesson: search by **type consumers**, not property names; search ALL solutions (WebAdmin missed initially, caught by CI)
