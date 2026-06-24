# 2026.4.1.1 FTUE Server Hotfix — patch-prep recon

Post-2026.4-FTUE-release server patch off the MFT (Content) branch. Method and version semantics:
[`reference/release_versions_and_process.md`](../../../../reference/release_versions_and_process.md).

## Boundary
Last minor-protocol increment: **MFT r16171** (2026-06-11) — "Increment minor protocol version after
the 2026.4 FTUE (Steam) release: 1125.0 -> 1125.1". Post-release server code = **r16172..HEAD**.
(`SharedConsts.MinorProtocolVersion`; reports stamp `1125.1`.)

## New version
`2026.4.1.1 FTUE Server Hotfix` (id **16439**, release-date 2026-06-30). Server-only, **async** (no
client coupling except FP-43192). Name/semver may change. Created by owner.

## Assembled into 16439 (13 tasks, applied + verified)

TRANSFER (post-incr only -> moved entirely to 16439):
- FP-44411, FP-44470, FP-44481 (shop tackle compatibility), FP-44459 (clip logging),
  FP-44465 (item currency/rarity), FP-44460 (Frankenfish mount), FP-44478 (club item double-delivery;
  dropped Next Hotfix + 2026.4.1), FP-44564 (weather seed window; dropped Next Hotfix),
  FP-44331 (PedalKayak description).

ADD (pre-incr commit existed -> kept prior version + added 16439):
- FP-43469 (PlayerDailyActivity backfill fix) + 2026.4; FP-43816 (TournamentParticipants index) + 2026.4;
  FP-42918 (buoy conversion finalizer/deadlocks) + 2026.4; FP-43815 (matchmaking admin visibility) + 2026.4
  (per owner: keep 2026.4 + new, "по-честному").

SKIP: FP-43192 (UWP /Stats/Payments recompute) — stays `2026.4.2 FTUE Consoles Release`; the only
client-coupled task (client commits in both MainClient and CodeBranch), On Hold for consoles.

## 5 server tasks in 2026.4.1 with no post-incr MFT commit — re-tagged by owner (no patch action)
- FP-44447 -> Internal/Async (analytics SQL + report only, no code)
- FP-44341 -> 2026.4 (server fix r16165, pre-boundary -> shipped in 2026.4)
- FP-44184 -> 2026.4 (fix r16139)
- FP-41507 -> 2026.4 (re-fix r16141)
- FP-42647 -> 2026.3 Leaderboards (fix arrived via linked FP-41460, whose fixVersion is 2026.3)

## Client coupling (MainClient + CodeBranch, since 2026-01-01)
Only **FP-43192** has client commits. All other post-release server tasks are client-decoupled ->
async-safe.

## Open: groom Next Server Hotfix
Members not in MFT (merge/triage candidates): FP-41067, FP-41407, FP-41455, FP-41468, FP-41498,
FP-41532, FP-41958, FP-41962, FP-42033, FP-44395, FP-44464. WebAdmin tasks (41067/41455/41468/41532)
deploy separately. NEXT STEP: locate each one's commits across branches + status, decide which belong
in 16439 and whether they need merging into MFT (merge direction allows only LBM/below -> Content).

## Pending
- Refine the 16439 name/topic (currently generic).
- Investigate the 11 Next-Hotfix-not-in-MFT.
