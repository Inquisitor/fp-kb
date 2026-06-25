# FP-44478 — top dupers vetted against prod `Main.Profiles`

Point lookups (NOLOCK) on each platform's prod Main, 2026-06-24. Goal: are the dominant dupers real players
or abnormal/farming accounts? `CheatRating` / `HighestCheat` are anti-cheat scores; `AdminComment` is a
manual moderator note.

**Caveat — anti-cheat is NOT relied on here.** The FP anti-cheat is noisy (heavy false-positives, does not
reliably ban), so `CheatRating`/`HighestCheat` are shown for reference only and are not load-bearing. The
"farming account" characterisation rests on **re-delivery behaviour** (one donation re-delivered hundreds of
times over a few days — see `SUMMARY.md`) and the known case of one account farming 230k+ club tokens via
this exploit.

## Steam (top-5 by surplus)

| UserId   | Lvl | CheatRating | HiCheat | ClubTokens | SilverCoins | CompBan  | AdminComment                 |
|----------|----:|------------:|--------:|-----------:|------------:|----------|------------------------------|
| 0c6d0cec | 109 |     604,847 |     100 |     97,483 |  82,978,031 | —        | —                            |
| f139316b | 110 |     447,100 |     100 |     21,581 |  18,355,735 | **true** | "Reduce rating" + Slack link |
| 3b2ea48c |  96 |     259,562 |     100 |      1,856 |     958,832 | —        | —                            |
| 370f7923 |  91 |      87,114 |     100 |      1,903 |  28,670,687 | —        | —                            |
| ef3352b6 |  45 |      10,526 |      40 |          0 |     319,327 | —        | —                            |

`f139316b` (#1 overall; 8,342 CT surplus) is competition-banned with a manual "Reduce rating" admin note.
`3b2ea48c` (#2; 7,744 CT surplus) — CheatRating 259k, HighestCheat 100. The two accounts behind ~94% of all
token surplus are both heavily cheat-flagged.

## PS (top-5)

| UserId   | Lvl | CheatRating | HiCheat | ClubTokens | SilverCoins |
|----------|----:|------------:|--------:|-----------:|------------:|
| 18760ea0 | 110 |     870,473 |     100 |      1,022 |  54,070,664 |
| 6abf11d2 |  43 |     455,127 |     100 |          6 |      72,255 |
| 9cf7a7a9 |  65 |      31,899 |      40 |         90 |     463,759 |
| 9c1ad9fe |  58 |      14,424 |     100 |          6 |   1,027,933 |
| a51fd3c5 |  18 |      14,221 |      40 |        422 |       1,064 |

PS token duper `18760ea0` — CheatRating 870k, 54M SC: bot/farm.

## Mobile (top-5)

| UserId   | Lvl | CheatRating | HiCheat | SilverCoins |
|----------|----:|------------:|--------:|------------:|
| 8a825c0a |  36 |       2,503 |      40 |      28,916 |
| 376f9dcf |  46 |      18,543 |      40 |     799,341 |
| 41f19a7a |  28 |       9,165 |     100 |      10,346 |
| 3030ee8d |  45 |       2,139 |     100 |     147,784 |
| acffe20e |  67 |      20,337 |     100 |   2,969,496 |

Mobile dupers are lower-magnitude (bait only, max 911 surplus) and less extreme on CheatRating — a likelier
mix of light bots and possibly some real accounts, but small economic weight.

## Conclusion

The headline surplus is concentrated in a few **relogin-loop / farming accounts**, not legitimate players —
and the basis is **behaviour, not anti-cheat**. The dominant accounts each received 80-110 distinct donations
re-delivered ~120x over a few days (top single donation: 327 deliveries in 6 days), and at least one is known
to have farmed 230k+ club tokens via this exploit. The `CheatRating`/`HighestCheat` values in the tables are
shown for reference only (the FP anti-cheat is noisy and does not reliably ban), not as the basis. Real
economic damage to the legitimate economy is far below the raw 60-day surplus — the legit-player tail got only
single-digit extra baits — but the true token scale needs the SQL `Stmt` reconstruction.
