# Balance — Backlog

- [ ] Clarify the `preventNegativeBalance` contract so it reads unambiguously as "no downward
      zero-crossing" (a `>= 0` balance may not be pushed below 0 by this operation), NOT
      "prevent negative balance". It intentionally does NOT repair an already-negative balance:
      a negative balance is a legitimate state from sanctions or real-money-item refunds, and
      auto-clamping it back to 0 would erase a legitimate penalty and gift currency. Scope: rename
      / re-comment the flag and its `IncrementBalanceEx` clamp (`Shared/SharedLib/Balance/BalanceHelper.cs`);
      no behavior change. Surfaced by the FP-44943 review (Codex flagged the already-negative case as
      a defect; rejected as by-design, contract wording is the only real gap).
