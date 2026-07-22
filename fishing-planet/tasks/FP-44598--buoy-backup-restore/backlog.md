# FP-44598 Backlog

## Backup (`--export-buoys`) — DONE
- [x] Feature implemented + unit-tested; committed to MFT20260325 (r16349), with the `ProfileConverter` full-table-scan timeout fix (r16350)
- [x] Tolerant deserialization fallback (`TolerantProfileReader`) + `--users` targeted-recovery option — added after Steam surfaced profiles carrying an enum value undefined in this branch
- [x] Run on pre-release backups: **Steam, PS, Xbox** — zero buoys lost; per-pond set packed one `.7z` per platform on the dumps
- [ ] **Mobile, Nintendo** — run when those platforms ship (not yet released); same tool, one pass each

## Restore (`--import-buoys`) — deferred, lower priority
- [ ] Implement per-pond import (load-mutate-save; identity PondId+Position+Fish; preserve BuoyId best-effort)
- [ ] Recolor-counter restore policy — lean lenient (don't re-charge already-used free limits); edge-case analysis
- [ ] GC claw-back decision — analyze blast radius / fairness first (it's our error)

## Related
- ReleaseTool ergonomics: run conversions/exports by Code instead of numeric id -> FP-44393
- Born from FP-44389 (2026.4 FTUE release prep)
