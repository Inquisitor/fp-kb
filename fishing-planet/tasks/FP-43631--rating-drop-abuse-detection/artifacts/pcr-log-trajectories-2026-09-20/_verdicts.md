---
cycle: week-20
date: 2026-09-20
run: the deadline subset only -- the 6 candidates who could still reach the paying board
result: 3 BAN / 3 acquitted, of which 2 were overridden to BAN by the operator before the payout
note: |
  Reconstructed from `bans-2026-09-20.md` on 2026-09-27, not from the workflow output. The step-5
  requirement to persist verdicts was written in week-19 and was not followed here: the judges'
  reasoning was not saved and is gone, so this file carries the outcomes and nothing more.
  `HalfSand_`'s verdict label and confidence were never recorded anywhere and cannot be recovered.
  The remaining 10 candidates were not tried -- they were read from the trajectory directly, and
  their outcomes are in the cycle record's remainder table.
---

# Week-20 trial verdicts

What the trial decided on the deadline subset. Unlike week-19 there are no per-case sections: the
arguments and the judges' reasoning were not persisted and only the outcomes survive.

| Candidate | Platform | Board rank | Verdict | Duration | Confidence |
|---|---|---:|---|---|---:|
| LEK_TARNO | Steam | 1 | BAN | 4W-NEW | 8 |
| CrazyGepard | PlayStation | 3 | WATCH -> BAN (override) | 4W-NEW | 9 |
| Rapidstrapon | XBox | 5 | BAN | 4W-NEW | 8 |
| HavocHHH | Steam | 7 | WATCH -> BAN (override) | 4W-NEW | 9 |
| HalfSand_ | PlayStation | 8 | acquitted | n/a | not recorded |
| Gentleman83190 | PlayStation | 12 | BAN | 4W-NEW | 9 |

## The two overrides

`CrazyGepard` and `HavocHHH` were both released at confidence 9 and both overridden on the same
ground: rule 5's operative test counts downward crossings of a bracket line, and neither of them
crosses. `CrazyGepard` tops out at exactly 100, the highest rating still inside NOOBS; `HavocHHH`
peaks at 988, 13 points short of the TOPS floor. Every counter the trial had available reads zero on
a player who stops there. The reasoning is in `bans-2026-09-20.md` and in the ban script.

Unlike the week-18 overrides, these contradict verdicts that were sound on the rules as written
rather than filling a gap left by a defective brief. That is what put the operative test into rule 5
and the formal statement of the offence into the backlog.

## `HalfSand_`

Acquitted, and paid: place 8 with 3 wins and a reward of 75073. Recorded deliberately as the price
of an acquittal rather than a defect in one. He was re-examined after the payout on the rebuilt
ledger and the acquittal held; he stays on the watchlist as a returning account whose earlier ban
lapsed 2026-09-07.

## Re-hearing

`LEK_TARNO`, `Gentleman83190` and `Rapidstrapon` were re-heard on 2026-09-27 against the rebuilt
ledger -- which carries the competition's start time, the rating and clock time at registration and
the place, none of which the trial had -- together with online presence from
`Stats.dbo.GameSessions`. All 3 convictions upheld. Details in `bans-2026-09-20.md`.
