# Decision Log — Matchmaking

## 2026-03-09
- DB rename approach: full `sp_rename` + ConfigJson `REPLACE` instead of DAL mapper abstraction. Simpler, no runtime overhead, atomic with downtime
- ConfigJson dead param removal: `REPLACE` (preserves formatting) over `JSON_MODIFY` (reformats entire JSON). Game designers rely on specific indentation/line breaks
- Patch idempotency: `IF EXISTS` for DDL, `REPLACE` with `WHERE LIKE` for data ops — safe for re-execution after version bump
- Lesson: handle both CRLF and LF in ConfigJson REPLACE patterns (LF fallback pass)

## 2026-02-18
- Terminology rename: Groups→Buckets, GroupSettings→Brackets, SubGroups→Groups. Adopted GDD terminology as canonical
- Lesson: search by **type consumers**, not property names; search ALL solutions (WebAdmin missed initially, caught by CI)
