# FP-44598 Backlog

## Backup (`--export-buoys`) — finish
- [ ] Lint/format + UTF-8 BOM pass on the new BuoyBackup files (`dotnet format --verify-no-changes`)
- [ ] Final whole-feature code review
- [ ] Manual smoke on a dev/QA Main DB (point `App.config` `sql` connection), verify 3 per-pond sets
- [ ] Single atomic `svn commit` of the feature under FP-44598 (run by user)

## Restore (`--import-buoys`) — deferred, lower priority
- [ ] Implement per-pond import (load-mutate-save; identity PondId+Position+Fish; preserve BuoyId best-effort)
- [ ] Recolor-counter restore policy — lean lenient (don't re-charge already-used free limits); edge-case analysis
- [ ] GC claw-back decision — analyze blast radius / fairness first (it's our error)

## Related
- ReleaseTool ergonomics: run conversions/exports by Code instead of numeric id -> FP-44393
- Born from FP-44389 (2026.4 FTUE release prep)
