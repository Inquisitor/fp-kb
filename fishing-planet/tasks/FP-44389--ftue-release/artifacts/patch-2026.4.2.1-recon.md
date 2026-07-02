# 2026.4.2.1 FTUE Server Hotfix — patch-prep recon

Post-2026.4-FTUE-release server patch off the MFT (Content) branch. Method and version semantics:
[`reference/release_versions_and_process.md`](../../../../reference/release_versions_and_process.md).

## Boundary
Last minor-protocol increment: **MFT r16171** (2026-06-11) — "Increment minor protocol version after
the 2026.4 FTUE (Steam) release: 1125.0 -> 1125.1". Post-release server code = **r16172..HEAD**.
HEAD still **r16232** as of 2026-06-30; `MinorProtocolVersion` still 1, so no new boundary — the set
below is stable. (`SharedConsts.MinorProtocolVersion`; reports stamp `1125.1`.)

## New version
`2026.4.2.1 FTUE Server Hotfix` (id **16439**) — renamed 2026-07-01 from `2026.4.1.1` because the
2026.4.2 console release ships first, so the hotfix follows it (id unchanged). Server-only. Originally
planned to release async; **bundled into the 2026.4.2 console release** (see "Console bundle") since
that ships from the same MFT HEAD.

## Post-boundary MFT set (r16172..HEAD = 16 tasks)
TRANSFER (post-incr only -> entirely on 16439):
- FP-44411, FP-44470, FP-44481 (shop tackle compatibility), FP-44459 (clip logging),
  FP-44465 (item currency/rarity), FP-44460 (Frankenfish mount), FP-44478 (club item double-delivery),
  FP-44564 (weather seed window), FP-44331 (PedalKayak description),
  FP-44396 (competitive LB batch-abort; back-port MFT r16228 <- NPN r16179, landed after first recon).

ADD (pre-incr commit existed -> kept 2026.4 + added 16439):
- FP-43469 (PlayerDailyActivity backfill), FP-43816 (TournamentParticipants index),
  FP-43815 (matchmaking admin visibility), FP-43185 (WebAdmin give-product price; back-port
  MFT r16232 <- NPN r16183, post-incr follow-up to pre-incr r16048).

SKIP: FP-43192 (UWP currency parsing) — `2026.4.2 Consoles` only; the one client-coupled task
(client commits in both MainClient and CodeBranch).

OFF-PATCH: FP-42918 (buoy conversion) — re-tagged `2026.4 + Internal/Async`, **not** on 16439. Its
only post-boundary commit (r16172) touches **ReleaseTool only**
(`Photon/tools/ReleaseTool/.../ProfileConversionFinalizer.cs`), not the server binary, so there is no
binary hotfix to ship. The online (login-time) conversion shipped pre-boundary (r15956, in 2026.4);
the upfront/offline ReleaseTool conversion is the unfinished part (review found problems) and stays
Internal/Async until fixed. **Operational: do NOT run the upfront ProfileConversion via ReleaseTool
for the console release — the login path converts console players.**

## Console bundle (2026.4.2 FTUE Consoles Release, id 16240) — applied 2026-06-30
All 16 post-boundary MFT tasks now carry 16240 (verified). The 13 patch tasks above each got +16240;
FP-44396 and FP-43192 already had it; FP-42918 got +16240 (-> `2026.4 + Internal/Async + 2026.4.2`).
The console build = MFT HEAD r16232, so the version tags now match what physically ships. The four
ADD tasks carry three versions (`2026.4 + 2026.4.2.1 + 2026.4.2`) by the "honest" rule — they shipped
on Steam too.

## Next Server Hotfix grooming + reconciliation (done 2026-06-30 / 2026-07-01)
Reviewed all members. Net effect on the patch: only FP-44396 was a genuine new addition (handled
above); the rest were already shipped or have no code — **no merges into MFT** needed.

**Reconciliation (2026-07-01):** the already-shipped members carried a stale `Next Server Hotfix` (NSH)
tag, and some had no real release version at all. Set their **honest** platform release versions and
dropped NSH. Platform model: Steam/PS/Xbox got Norway (2026.2) + Leaderboards (2026.3, = the LBM
branch); Mobile/Nintendo are behind (on the Maldives branch) and catch up via **FTUE** — a single
`2026 FTUE Mobile + Nintendo` (16241) carries all of Norway+Leaderboards+FTUE, since no separate
Norway/Leaderboards M/N release was ever cut (server releases are more flexible than client ones).
- WebAdmin Dec'25 (FP-41067/41455/41468/41498/41532) -> `2026.3 Leaderboards` (14190) + `FTUE M/N` (16241).
- line/torch Feb'26 (FP-41958/41962/42033) -> kept `2026.2 Norway Consoles` (15412) + `2026.3 Leaderboards`
  (14190) + `FTUE M/N` (16241).
- FP-43750, FP-43817 (FTUE-branch) -> `2026.4 FTUE Steam/EGS` (15543) + `2026.4.2 Consoles` (16240) +
  `FTUE M/N` (16241).
- FP-43756 -> merged/closed and versioned by owner (reviewed separately); out of this pass.
- No code, stay in NSH incubator: FP-41407 (event, not server), FP-44395, FP-44464, FP-44701.

## 5 server tasks in 2026.4.1 with no post-incr MFT commit — re-tagged by owner (no patch action)
- FP-44447 -> Internal/Async (analytics SQL + report only, no code)
- FP-44341 -> 2026.4 (server fix r16165, pre-boundary -> shipped in 2026.4)
- FP-44184 -> 2026.4 (fix r16139)
- FP-41507 -> 2026.4 (re-fix r16141)
- FP-42647 -> 2026.3 Leaderboards (fix arrived via linked FP-41460, whose fixVersion is 2026.3)

## Pending
- Optional: the FTUE-branch patch tasks (16439 + the console-bundle set) will also reach M/N via
  `2026 FTUE Mobile + Nintendo` (16241); tag them if/when desired (separate pass).
