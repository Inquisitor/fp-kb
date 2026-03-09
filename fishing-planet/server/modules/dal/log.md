# Decision Log — DAL

## 2026-03-09
- Finding (unverified, agent research): write-path mappers (`ExtractParamsFromDto`, `ExtractParamsFromObject`) and asymmetric failure modes discovered — see card Entry Points and backlog for verification

## 2026-03-05
- `RestoreObjectFromReader` maps DB columns to C# properties by exact name match — no `[Column]`, `[JsonProperty]`, or any attribute support
- `MakeCloneOf`/`MakeEqualTo` uses same exact-name reflection for property copy between objects
- Implication: when renaming DB columns, DTO properties AND model properties must all rename synchronously. Cannot rename one side without the other
- Discovered during FP-41746 TRM-002/TRM-003 (matchmaking terminology rename)
