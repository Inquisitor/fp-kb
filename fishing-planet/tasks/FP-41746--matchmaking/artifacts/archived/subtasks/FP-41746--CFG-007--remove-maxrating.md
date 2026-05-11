### CFG-007. `MaxRating` — TDD says explicitly per-bracket, code auto-calculates

- **TDD:** `MaxRating` is explicitly specified per bracket in JSON config. Validation checks that brackets are
  continuous (group[i-1].MaxRating == group[i].MinRating - 1).
- **GDD:** Only `MinRating` shown in JSON examples. `MaxRating` is implied ("MinRating of group 2 is effectively
  MaxRating of group 1 plus 1 point").
- **Code:** `MaxRating` exists in `TournamentBracket` (was `TournamentGroupSettings`) but `InitializeGrouping()`
  auto-fills it from `MinRating` values. Works with `MaxRating = 0` or absent.

**Decision:** Remove `MaxRating` from spec. Rework code: eliminate `InitializeGrouping()` call, compute bracket
boundaries on the fly from `MinRating` values. `MaxRating` should not be a persisted/configured field.

| Action                                                                                                                                                                                                   | Status |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------|
| **GDD:** Already consistent (only shows MinRating). No changes.                                                                                                                                          | N/A    |
| **TDD:** Remove `MaxRating` from parameter spec. Describe that brackets are defined by `MinRating` only; upper bound is derived on the fly (next bracket's MinRating - 1).                               | Moved to [FP-43717](https://fishingplanet.atlassian.net/browse/FP-43717) |
| **Code:** Remove `InitializeGrouping()`. Compute bracket boundaries on the fly from sorted `MinRating` values. Remove or deprecate `MaxRating` from `TournamentBracket` (was `TournamentGroupSettings`). | Moved to [FP-43717](https://fishingplanet.atlassian.net/browse/FP-43717) |

**Priority:** Medium (code refactoring)

---

**Status update:** Moved to [FP-43717](https://fishingplanet.atlassian.net/browse/FP-43717) — Eliminate dependency on persisted `MaxRating` in bracket config. Motivated by FP-43553 (Steam prod incident, 2026-04-29) where the implicit `MaxRating` auto-fill contract broke at a non-template load path and broke matchmaking for 3 competitions. New ticket consolidates the scope and offers two implementation paths (Option A: remove field entirely; Option B: enforce init at matchmaking entry).
