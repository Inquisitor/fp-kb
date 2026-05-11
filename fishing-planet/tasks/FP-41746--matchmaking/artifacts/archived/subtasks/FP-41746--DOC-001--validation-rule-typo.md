### DOC-001. Typo in TDD validation rules — wrong array index

- **TDD:** In "Competetive Activity Breaks" validation section, the rating overlap check reads:
  `group[i-1].MaxRating == group[i-1].MinRating - 1`
  Should be:
  `group[i-1].MaxRating == group[i].MinRating - 1`
  (right-hand side must reference the **next** group's MinRating, not the same group)
- **Confluence page:** Same typo (page ID 4009033759, last modified 11 Jan 2026).

**Decision:** Fix in TDD on Confluence. May become moot if validation section is rewritten per CFG-007.

| Action                                                                                        | Status |
|-----------------------------------------------------------------------------------------------|--------|
| **GDD:** N/A                                                                                  | N/A    |
| **TDD:** Fix `group[i-1].MinRating` → `group[i].MinRating` in validation rules on Confluence. | DONE — new spec (page 5505613835), Section 7 |
| **Code:** N/A                                                                                 | N/A    |

**Priority:** Low (documentation typo; may be superseded by CFG-007)
