### TST-004. Recalculate expected test outputs for MaxGroupCount / MaxGroupSize

- **Context:** After CFG-005/CFG-006 implementation, existing test case tables needed new columns with expected
  outputs when `MaxGroupCount` or `MaxGroupSize` parameters are active. Calculations were done in a Google Docs
  spreadsheet per GD request, then exported to TSV.
- **Artifact:** `TST-004-output-fixes.tsv`

**Decision:** Add expected output columns for new parameters to every existing test case.

| Action                                                                                            | Status |
|---------------------------------------------------------------------------------------------------|--------|
| **Tests:** Recalculate expected outputs for all test cases with MaxGroupCount / MaxGroupSize set. | DONE   |

**Priority:** High (blocks Phase 6 test coverage)
