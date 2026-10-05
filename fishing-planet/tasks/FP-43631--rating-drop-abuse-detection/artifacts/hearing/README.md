# Hearing of a cohort — prosecution, defence, judge

Every candidate of the week is heard by 3 agents before the operator reads the cards: a prosecution
and a defence argue from the same manual and the same case file, and a judge decides BAN, WATCH or
CLEAR with a confidence of 1 to 10 and the facts that decided it. The manual is a page on the
setting (`manual-setting.md`) followed by `reading-guide.md` as it stands, joined at build time, so
the judges always see the current hints; it is given as a description of behaviour, and the agents
are told it is not a checklist. The guide carries no player names, so a returning player never
finds his own earlier reading in it. The case file is everything the operator
has: the card, a case sheet, the full list of game sessions, the raw columns of odd rows.

The hearing exists to convict the plain cases and to tell the operator which ones are not plain.
A BAN at high confidence on a plain case is confirmed from the judge's decisive facts and the card;
a WATCH below confidence 8, and every borderline case, is read by hand. Afterwards the judges'
reasoning is read for behaviour the manual does not describe; a new pattern goes into
`reading-guide.md`. While the manual works, it is left alone.

## Steps

1. Build the cards as usual (`pcr-log-trajectories-<date>/_build_cards.py`).
2. Write `cases.json` in the scratchpad: one object per candidate with `uid`, `name`, `platform`
   (`steam` / `ps` / `xb`), `board` (place and wins on the weekly board when the week closed, in
   words) and `history` (ban history and earlier reviews, in words; the facts, not the verdicts of
   this cycle).
3. `python build_bundle.py --date <date> --cases <scratchpad>/cases.json --out <scratchpad>/tribunal`
   — one manual and one case file per candidate, outside the KB, plus `args.json` for the workflow.
4. Launch `hearing-workflow.js` through the Workflow tool with the `args.json` content as `args`.
   Each agent reads exactly its 2 files. 19 cases take about 25 minutes; 3 agents per case.
5. `python collect_results.py <transcript dir> <scratchpad>/out` — one file per case with both
   briefs and the decision, `results.tsv`, and the judges' readings printed.
6. The operator reads `results.tsv` first, then the decisions: plain BAN at high confidence is
   confirmed from the decisive facts; the rest is read by hand from the cards, as before.
7. After the bans: read the judges' reasoning for new behaviour; add it to `reading-guide.md` if
   it is real, described as behaviour and without the player's name; the case it came from goes
   into `journal.md`. A borderline verdict at confidence 6 can go either way on the same inputs; give such
   a case 2 or 3 judges before relying on it.

## Timing on a Sunday

The final detection run is after 22:00Z and the pack must be committed before 00:07Z. A hearing of
the 21:40Z cohort can start as soon as those cards exist and ends about 25 minutes later; the
candidates the 22:00Z run adds get a second, small hearing. The hearing's outputs are working files
and are not committed.
