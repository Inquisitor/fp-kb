---
module: balance
status: stub
---

# Balance

Currency balance mutation + ledger logging primitive. Wraps every Silver/Gold/ClubTokens
change so the mutation and its statement/movement audit rows are written together.

## Entry Points

- `BalanceHelper` (`Shared/SharedLib/Balance/BalanceHelper.cs`) — `IncrementBalance` /
  `IncrementBalanceAsync` (mutate + log), `LogBalanceIncrement` (log only), core
  `IncrementBalanceEx` / `LogBalanceIncrementEx`.
- `Profile.GetBalance(currency)` / `IncrementBalance(currency, value)` — raw balance access.

## Key Types

- `BalanceMovementType` (enum) — purpose of a movement (e.g. `ProductRefundPenalty`).
- `BalanceDto` — one balance-movement audit row (UserId, MoveTypeId, Move, ResultingBalance, Currency, Level).
- Currency ids: `Inventory.SC` / `GC` / `CT` (Silver / Gold / ClubTokens).

## Dependencies

- → DAL statement + balance-movement tables (sync or async write)
- ← `rewards`, monetization delivery, ReleaseTool conversions (`~` currency ops)

## Deep Dives

- (none yet)

## Related Tasks

- FP-44943 review — surfaced the `preventNegativeBalance` contract-clarity item (see backlog).
