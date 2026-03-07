### TST-003. Stale test `CreateGroups_LowRatingProtectionIsOn_AddsMinimalPossiblePlayers`

- **Code:** Tests a removed flag `IsLowRatingGroupProtectionOn`. Test was `CreateSubgroups_...`, renamed to
  `CreateGroups_...` in TRM-002. Related to CFG-004.

**Decision:** Review the test — if logic is still meaningful, rename; if not, delete.

**Resolution:** Test logic is meaningful — it verifies that Phase A of `BalanceBuckets` pulls participants only up to
`MinSize`, not `TargetSize`. The behavior was previously controlled by the flag but is now always-on. Renamed to
`CreateGroups_BucketBelowMinSize_PullsOnlyUpToMinSize`. Also removed stale commented-out
`//groupingRule.IsLowRatingGroupProtectionOn = false;` from the Demo test.

| Action                                                                                                           | Status |
|------------------------------------------------------------------------------------------------------------------|--------|
| **Code:** Review test logic. If meaningful — rename, remove reference to deleted flag. If not — delete the test. | DONE   |

**Priority:** Medium
