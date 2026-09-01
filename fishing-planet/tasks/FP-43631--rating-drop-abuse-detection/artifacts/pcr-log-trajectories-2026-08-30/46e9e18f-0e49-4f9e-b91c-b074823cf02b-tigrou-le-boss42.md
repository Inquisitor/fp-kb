# PCR trajectory - tigrou_le_boss42 (PlayStation)

Player id `46e9e18f-0e49-4f9e-b91c-b074823cf02b`. Source: `46e9e18f-0e49-4f9e-b91c-b074823cf02b-tigrou-le-boss42.tsv`.
Window nominally 2026-08-10 .. 2026-08-30; **the log carries no event before 2026-08-16T05:51:41Z**, so the first
six days of the three-week span are absent from the dump. Last line 2026-08-30T18:52:03Z.
Sweep week = 2026-08-24 .. 2026-08-30.

This player never approaches the PCR floor - the minimum over the whole logged stretch is 85 - so the
"penalty at PCR 0 leaves no ledger line" artifact does not apply here. The ledger chains without a
single gap from `99` to `136`, and every printed delta agrees with its before->after pair.

## Headline

| | |
|---|---|
| PCR at start / end | 99 -> 136 |
| PCR min / max | 85 (2026-08-21T05:53:26Z) / 182 (2026-08-28T14:00:31Z) |
| Bracket range | oscillates across the NOOBS/MIDDLES boundary (100). The 1000 boundary is never approached. |
| Ledger lines | 87 (44 pre-sweep, 43 sweep week) |
| Registrations (logged) | 92 lines / 91 distinct competitions (one re-registration after an unregister) |
| Starts (logged) | 61 (30 pre-sweep, 31 sweep week) |
| No-shows (logged) | 29 (15 pre-sweep, 14 sweep week) |
| Zero-score finishes (logged) | 11 of 61 starts (7 pre-sweep, 4 sweep week) |
| Prizes = top-3 finishes (logged) | 15 (8 pre-sweep, 7 sweep week by settlement date / 6 by play date) |
| CHEAT triggers | 358 (201 pre-sweep, 157 sweep week) |
| Batched flush groups | 4 pairs of settlements landing in the same second or one second apart |
| Terminal state | still registering at the cut-off (#377334 at 2026-08-30T18:52:03Z); no ban line in the log |

## Reconciliation with SQL

The sweep week reconciles on every count the ledger can reproduce, once one boundary competition is
attributed to the week it was *played* in rather than the week it *settled* in.

| SQL (sweep week) | Ledger | |
|---|---|---|
| Reg 45 | 46 distinct | the extra is #377334, registered 2026-08-30T18:52:03Z, never started or settled in-window |
| Started 31 | 28 with a reward line, plus #376873 and #376936 (settled at place 13, no reward line) and #377333 (unsettled at the cut-off) = 31 | exact |
| Zero-score 4 | 4 | exact |
| No-shows 14 (31.1%) | 14 | exact |
| Absence -230 | -230 | exact |
| Prizes 6 | 6 | exact once #376726 (played 2026-08-23T20:10:27Z, settled 2026-08-24T05:30:14Z, +55) is booked to the pre-sweep week |
| Play +219 | +225 on the same play-date bucketing | residual +6 unexplained; the only candidates the log offers are the two settled-but-unlogged place-13 results |
| PCR 136 | 136 | exact |

The N/M/T splits in the SQL (prizes 6N/0M/0T, played 6N/23M/2T) are **competition tiers**, not the
player's own bracket. They are not derivable from this log - the dump carries no tier field - so the
`bracket` column below is strictly the PCR-derived bracket (NOOBS <= 100, MIDDLES 101-1000, TOPS >= 1001).
The two readings are not in conflict: the player's own PCR sits in MIDDLES most of the time, while the
SQL says the prizes are all taken in NOOBS-tier competitions.

## Ledger

Bracket read at the *after* value. A bold `X -> Y` marks a 100-boundary crossing on that line.
`PCR before->after` is the authoritative pair.

### Pre-sweep (2026-08-16 .. 2026-08-23)

| Timestamp | Comp ID | Comp name | Status | delta | PCR before->after | bracket |
|---|---|---|---|---|---|---|
| 2026-08-16T08:00:11Z | 376200 | La rivière des cranks | PLAYED, place 3 (prize) | +30 | **99 -> 129** | MIDDLES |
| 2026-08-16T12:00:10Z | 376202 | Bataille des têtes d’acier | NO-SHOW | -11 | 129 -> 118 | MIDDLES |
| 2026-08-16T14:00:31Z | 376203 | Petite pêche sur le Neyerrin | PLAYED, place 42 (defeat) | -3 | 118 -> 115 | MIDDLES |
| 2026-08-16T16:00:13Z | 376204 | Fossile Vivant | NO-SHOW | -20 | **115 -> 95** | NOOBS |
| 2026-08-17T00:21:49Z | 376207 | Ni poisson, ni oiseau | PLAYED, place 2 (prize) | +27 | **95 -> 122** | MIDDLES |
| 2026-08-17T08:00:06Z | 376251 | Ide mélanote paresseuse | PLAYED, zero-score | -7 | 122 -> 115 | MIDDLES |
| 2026-08-17T20:00:27Z | 376257 | Précision idéale | PLAYED, place 8 | +10 | 115 -> 125 | MIDDLES |
| 2026-08-18T07:11:48Z | 376259 | Grand rassemblement du Flétan ! | NO-SHOW | -20 | 125 -> 105 | MIDDLES |
| 2026-08-18T10:00:09Z | 376317 | Chasse au Bar effrénée | PLAYED, zero-score | -8 | **105 -> 97** | NOOBS |
| 2026-08-18T12:05:51Z | 376318 | À la poursuite de la Truite sur Falcon | PLAYED, zero-score | -5 | 97 -> 92 | NOOBS |
| 2026-08-18T16:00:20Z | 376320 | Les attraper tous | PLAYED, place 1 (prize) | +25 | **92 -> 117** | MIDDLES |
| 2026-08-18T18:39:13Z | 376321 | Des Brochets cinq étoiles ! | PLAYED, place 3 (prize) | +30 | 117 -> 147 | MIDDLES |
| 2026-08-18T20:00:14Z | 376322 | Réunion de famille des Marlins! | NO-SHOW | -20 | 147 -> 127 | MIDDLES |
| 2026-08-19T08:00:11Z | 376394 | Attaque du Cornish Jack | PLAYED, place 33 (defeat) | -7 | 127 -> 120 | MIDDLES |
| 2026-08-19T10:01:54Z | 376395 | Victoire Surface | NO-SHOW | -20 | **120 -> 100** | NOOBS |
| 2026-08-19T14:00:15Z | 376397 | Khan de Sibérie | PLAYED, place 1 (prize) | +40 | **100 -> 140** | MIDDLES |
| 2026-08-19T20:00:41Z | 376400 | Teenies Dans La Nuit | PLAYED, place 5 | +20 | 140 -> 160 | MIDDLES |
| 2026-08-20T05:26:10Z | 376402 | Ooh, Barracuda | NO-SHOW | -20 | 160 -> 140 | MIDDLES |
| 2026-08-20T05:26:10Z | 376401 | Chasse aux barbeaux | PLAYED, place 17 (defeat) | -2 | 140 -> 138 | MIDDLES |
| 2026-08-20T08:00:11Z | 376461 | Nourriture charnue | PLAYED, place 23 (defeat) | -7 | 138 -> 131 | MIDDLES |
| 2026-08-20T16:17:58Z | 376462 | Grand Frère | NO-SHOW | -20 | 131 -> 111 | MIDDLES |
| 2026-08-20T20:00:23Z | 376467 | Chasse aux brèmes de rêve | PLAYED, place 18 (defeat) | -3 | 111 -> 108 | MIDDLES |
| 2026-08-21T05:53:25Z | 376468 | L'un de nous, deux Aspes | PLAYED, place 19 (defeat) | -3 | 108 -> 105 | MIDDLES |
| 2026-08-21T05:53:26Z | 376470 | Tout compris: Tous les poissons! | NO-SHOW | -20 | **105 -> 85** | NOOBS |
| 2026-08-21T12:00:10Z | 376552 | Faites bouillir le dédale ! | PLAYED, place 1 (prize) | +55 | **85 -> 140** | MIDDLES |
| 2026-08-21T14:00:07Z | 376553 | Jumeaux labéo | NO-SHOW | -15 | 140 -> 125 | MIDDLES |
| 2026-08-21T16:00:43Z | 376554 | Combattant de Bass | PLAYED, place 56 (defeat) | -3 | 125 -> 122 | MIDDLES |
| 2026-08-21T18:06:16Z | 376555 | Duel avec l’Esturgeon ! | NO-SHOW | -20 | 122 -> 102 | MIDDLES |
| 2026-08-21T20:00:20Z | 376556 | Lépisocalypse : bataille de boue ! | PLAYED, zero-score | -5 | **102 -> 97** | NOOBS |
| 2026-08-22T05:15:54Z | 376557 | La rivière des cranks | PLAYED, place 31 (defeat) | -5 | 97 -> 92 | NOOBS |
| 2026-08-22T08:00:12Z | 376638 | Géants d’eau salée | PLAYED, place 2 (prize) | +42 | **92 -> 134** | MIDDLES |
| 2026-08-22T13:23:00Z | 376640 | Chasse aux barbeaux | PLAYED, place 15 (defeat) | -1 | 134 -> 133 | MIDDLES |
| 2026-08-22T14:00:13Z | 376641 | Esturgeon dans le noir | NO-SHOW | -11 | 133 -> 122 | MIDDLES |
| 2026-08-22T16:00:28Z | 376642 | Ne me malmène pas, Requin ! | PLAYED, place 22 (defeat) | -7 | 122 -> 115 | MIDDLES |
| 2026-08-22T18:00:26Z | 376643 | Brochet Lunaire | NO-SHOW | -11 | 115 -> 104 | MIDDLES |
| 2026-08-22T20:00:17Z | 376644 | Pêche nocturne aux Poisson-chat | PLAYED, zero-score | -6 | **104 -> 98** | NOOBS |
| 2026-08-23T05:28:59Z | 376645 | À la poursuite de la Truite sur Falcon | PLAYED, zero-score | -5 | 98 -> 93 | NOOBS |
| 2026-08-23T08:00:08Z | 376719 | Grand rassemblement du Flétan ! | PLAYED, place 2 (prize) | +50 | **93 -> 143** | MIDDLES |
| 2026-08-23T10:09:14Z | 376720 | Souris, c'est l'heure du Jacunda ! | NO-SHOW | -15 | 143 -> 128 | MIDDLES |
| 2026-08-23T12:42:04Z | 376721 | Chasse au Poisson d'or | PLAYED, place 23 (defeat) | -3 | 128 -> 125 | MIDDLES |
| 2026-08-23T14:00:12Z | 376722 | Chasse au Bar effrénée | NO-SHOW | -15 | 125 -> 110 | MIDDLES |
| 2026-08-23T16:00:11Z | 376723 | L'un de nous, deux Aspes | PLAYED, zero-score | -5 | 110 -> 105 | MIDDLES |
| 2026-08-23T18:00:15Z | 376724 | Pirañas géants | NO-SHOW | -15 | **105 -> 90** | NOOBS |
| 2026-08-23T20:00:57Z | 376725 | Géants Rouges | PLAYED, place 50 (defeat) | -4 | 90 -> 86 | NOOBS |

### Sweep week (2026-08-24 .. 2026-08-30)

| Timestamp | Comp ID | Comp name | Status | delta | PCR before->after | bracket |
|---|---|---|---|---|---|---|
| 2026-08-24T05:30:14Z | 376726 | Chasse au Rubis Nocturne! | PLAYED, place 1 (prize) | +55 | **86 -> 141** | MIDDLES |
| 2026-08-24T08:00:04Z | 376785 | Je ne te ferai pas de mal, Requin! | NO-SHOW | -20 | 141 -> 121 | MIDDLES |
| 2026-08-24T12:00:16Z | 376787 | Ide mélanote paresseuse | PLAYED, place 18 (defeat) | -3 | 121 -> 118 | MIDDLES |
| 2026-08-24T14:00:10Z | 376788 | Une course vraiment unique ! | PLAYED, zero-score | -6 | 118 -> 112 | MIDDLES |
| 2026-08-24T16:00:28Z | 376789 | Rodéo sur l’eau | PLAYED, place 48 (defeat) | -5 | 112 -> 107 | MIDDLES |
| 2026-08-24T18:00:12Z | 376790 | Raid au mérou géante! | NO-SHOW | -20 | **107 -> 87** | NOOBS |
| 2026-08-25T12:00:20Z | 376869 | Khan de Sibérie | PLAYED, place 1 (prize) | +40 | **87 -> 127** | MIDDLES |
| 2026-08-25T18:00:24Z | 376872 | Des Brochets cinq étoiles ! | PLAYED, place 28 (defeat) | -5 | 127 -> 122 | MIDDLES |
| 2026-08-26T05:50:56Z | 376874 | Le bonheur tacheté | NO-SHOW | -11 | 122 -> 111 | MIDDLES |
| 2026-08-26T08:00:11Z | 376934 | Empereur du Nil | PLAYED, place 7 | +25 | 111 -> 136 | MIDDLES |
| 2026-08-26T10:00:12Z | 376935 | Diversité de la rivière Marron | PLAYED, place 32 (defeat) | -6 | 136 -> 130 | MIDDLES |
| 2026-08-26T14:00:13Z | 376937 | Gamme de capture d’Amour | NO-SHOW | -15 | 130 -> 115 | MIDDLES |
| 2026-08-26T16:00:11Z | 376938 | Chasse aux carnivores trophées ! | NO-SHOW | -20 | **115 -> 95** | NOOBS |
| 2026-08-26T18:00:24Z | 376939 | Fais tourner le Truite! | PLAYED, place 16 (defeat) | -1 | 95 -> 94 | NOOBS |
| 2026-08-26T20:00:20Z | 376940 | Géants d’eau salée | PLAYED, place 3 (prize) | +37 | **94 -> 131** | MIDDLES |
| 2026-08-27T05:39:12Z | 376941 | Brochet Lunaire | PLAYED, place 2 (prize) | +30 | 131 -> 161 | MIDDLES |
| 2026-08-27T08:00:11Z | 377019 | Victoire Surface | PLAYED, place 28 (defeat) | -7 | 161 -> 154 | MIDDLES |
| 2026-08-27T10:30:33Z | 377020 | Pêche nocturne aux Poisson-chat | NO-SHOW | -11 | 154 -> 143 | MIDDLES |
| 2026-08-27T14:00:16Z | 377022 | Woohoo Thazard noir! | PLAYED, place 15 (defeat) | -2 | 143 -> 141 | MIDDLES |
| 2026-08-27T16:00:31Z | 377023 | Combattant de Bass | PLAYED, place 16 (defeat) | -1 | 141 -> 140 | MIDDLES |
| 2026-08-27T18:27:45Z | 377024 | Frénésie marbrée sur le Tibre | PLAYED, zero-score | -5 | 140 -> 135 | MIDDLES |
| 2026-08-27T20:00:11Z | 377025 | Grand rassemblement du Flétan ! | NO-SHOW | -20 | 135 -> 115 | MIDDLES |
| 2026-08-28T06:51:46Z | 377026 | San Joaquin sans frontières! | PLAYED, place 10 | +3 | 115 -> 118 | MIDDLES |
| 2026-08-28T06:51:46Z | 377027 | Menace Sanglante | NO-SHOW | -15 | 118 -> 103 | MIDDLES |
| 2026-08-28T10:00:39Z | 377130 | Compétition du vieux Buck | PLAYED, place 31 (defeat) | -3 | **103 -> 100** | NOOBS |
| 2026-08-28T12:00:13Z | 377131 | Pirañas géants | PLAYED, place 4 | +32 | **100 -> 132** | MIDDLES |
| 2026-08-28T14:00:31Z | 377132 | Chasse au Rubis Nocturne! | PLAYED, place 2 (prize) | +50 | 132 -> 182 | MIDDLES |
| 2026-08-28T16:00:10Z | 377133 | Un petit et un grand | NO-SHOW | -20 | 182 -> 162 | MIDDLES |
| 2026-08-28T18:00:34Z | 377134 | Petite pêche sur le Neyerrin | PLAYED, place 34 (defeat) | -3 | 162 -> 159 | MIDDLES |
| 2026-08-28T20:00:16Z | 377135 | Ne me malmène pas, Requin ! | NO-SHOW | -20 | 159 -> 139 | MIDDLES |
| 2026-08-29T07:40:26Z | 377136 | Gamme de capture d’Amour | PLAYED, zero-score | -8 | 139 -> 131 | MIDDLES |
| 2026-08-29T07:40:27Z | 377137 | Le Saumon vient à minuit | NO-SHOW | -13 | 131 -> 118 | MIDDLES |
| 2026-08-29T10:04:06Z | 377252 | Fossile Vivant | PLAYED, place 14 (defeat) | -1 | 118 -> 117 | MIDDLES |
| 2026-08-29T12:10:39Z | 377253 | Les attraper tous | PLAYED, place 16 (defeat) | -1 | 117 -> 116 | MIDDLES |
| 2026-08-29T16:00:10Z | 377255 | Jumeaux labéo | NO-SHOW | -15 | 116 -> 101 | MIDDLES |
| 2026-08-29T18:00:19Z | 377256 | Précision idéale | PLAYED, zero-score | -5 | **101 -> 96** | NOOBS |
| 2026-08-29T20:00:27Z | 377257 | Faites bouillir le dédale ! | PLAYED, place 19 (defeat) | -6 | 96 -> 90 | NOOBS |
| 2026-08-30T08:00:10Z | 377327 | Géants Rouges | PLAYED, place 1 (prize) | +35 | **90 -> 125** | MIDDLES |
| 2026-08-30T10:00:13Z | 377328 | A la recherche de l’Alose savoureuse parfaite | PLAYED, place 1 (prize) | +25 | 125 -> 150 | MIDDLES |
| 2026-08-30T12:00:11Z | 377329 | Thon Banzai ! | NO-SHOW | -20 | 150 -> 130 | MIDDLES |
| 2026-08-30T15:40:38Z | 377330 | Ide mélanote paresseuse | PLAYED, place 5 | +20 | 130 -> 150 | MIDDLES |
| 2026-08-30T16:00:21Z | 377331 | Capture d’un Monstre de boue | NO-SHOW | -10 | 150 -> 140 | MIDDLES |
| 2026-08-30T18:00:44Z | 377332 | Le bonheur tacheté | PLAYED, place 52 (defeat) | -4 | 140 -> 136 | MIDDLES |

Settlements arriving in the same flush (same second, or one second apart):
2026-08-20T05:26:10Z (#376402, #376401), 2026-08-21T05:53:25-26Z (#376468, #376470),
2026-08-28T06:51:46Z (#377026, #377027), 2026-08-29T07:40:26-27Z (#377136, #377137).
All four are pairs; there is no large batched dump of withheld settlements anywhere in this log.

## Settled with no ledger line

Three starts produce no reward line. None of them is a floor artifact - the player is well above 0 at
every one of these points.

| Timestamp | Comp ID | Comp name | Status | why no line |
|---|---|---|---|---|
| 2026-08-25T20:00:26Z | 376873 | Ni poisson, ni oiseau | PLAYED, place 13 | no rating line emitted; PCR was 122 at the time |
| 2026-08-26T13:08:23Z | 376936 | Capture d’un Monstre de boue | PLAYED, place 13 | no rating line emitted; PCR was 130 at the time |
| (unsettled) | 377333 | Lucky 50 | PLAYED, started 2026-08-30T18:00:39Z | competition still running at the cut-off |

One registration is withdrawn and immediately re-entered: #377130 registered 2026-08-28T06:55:33Z,
unregistered 06:56:41Z, re-registered 07:36:15Z, started 08:00:34Z.

## The 100-boundary cycle

23 crossings of the 100 boundary in 15 days - 12 upward, 11 downward. There are no 1000-boundary
crossings; the maximum PCR ever reached is 182.

**Every upward crossing is a top-4 finish, and 11 of the 12 are a top-3 prize.** Every downward
crossing is an absence or a non-scoring finish: 6 no-shows, 4 zero-score finishes, 1 near-last place.

| # | Down into NOOBS | Back up into MIDDLES | dwell below 100 |
|---|---|---|---|
| 1 | 2026-08-16T16:00:13Z NO-SHOW 115 -> 95 | 2026-08-17T00:21:49Z place 2 95 -> 122 | 8h 21m |
| 2 | 2026-08-18T10:00:09Z zero-score 105 -> 97 | 2026-08-18T16:00:20Z place 1 92 -> 117 | 6h 00m |
| 3 | 2026-08-19T10:01:54Z NO-SHOW 120 -> 100 | 2026-08-19T14:00:15Z place 1 100 -> 140 | 3h 58m |
| 4 | 2026-08-21T05:53:26Z NO-SHOW 105 -> 85 | 2026-08-21T12:00:10Z place 1 85 -> 140 | 6h 06m |
| 5 | 2026-08-21T20:00:20Z zero-score 102 -> 97 | 2026-08-22T08:00:12Z place 2 92 -> 134 | 11h 59m |
| 6 | 2026-08-22T20:00:17Z zero-score 104 -> 98 | 2026-08-23T08:00:08Z place 2 93 -> 143 | 11h 59m |
| 7 | 2026-08-23T18:00:15Z NO-SHOW 105 -> 90 | 2026-08-24T05:30:14Z place 1 86 -> 141 | 11h 29m |
| 8 | 2026-08-24T18:00:12Z NO-SHOW 107 -> 87 | 2026-08-25T12:00:20Z place 1 87 -> 127 | 18h 00m |
| 9 | 2026-08-26T16:00:11Z NO-SHOW 115 -> 95 | 2026-08-26T20:00:20Z place 3 94 -> 131 | 4h 00m |
| 10 | 2026-08-28T10:00:39Z place 31 103 -> 100 | 2026-08-28T12:00:13Z place 4 100 -> 132 | 1h 59m |
| 11 | 2026-08-29T18:00:19Z zero-score 101 -> 96 | 2026-08-30T08:00:10Z place 1 90 -> 125 | 13h 59m |

Eleven complete down-and-harvest cycles in fifteen days, six of them opened by a plain no-show. The
first line of the log is already the top of an earlier cycle (2026-08-16T08:00:11Z, place 3, 99 -> 129),
so the pattern is running before the dump starts.

## Drain route

Over the logged stretch the rating gained and the rating shed almost cancel - +681 against -644, net
+37 - and the two flows are carried by different kinds of event.

| Flow | Entries | Rating | Share |
|---|---|---|---|
| No-shows | 29 | -483 | 75.0% of the drain |
| Zero-score finishes | 11 | -65 | 10.1% of the drain |
| Genuine defeats (played, placed, negative delta) | 26 | -96 | 14.9% of the drain |
| **Total drain** | **66** | **-644** | |
| Top-3 prizes | 15 | +571 | 83.8% of the gain |
| Other positive finishes (places 4-10) | 6 | +110 | 16.2% of the gain |
| **Total gain** | **21** | **+681** | |

Sweep week alone: no-shows 14 / -230 (76.2% of the drain), zero-score 4 / -24 (7.9%), defeats 14 / -48
(15.9%); gain +352 over 11 positive finishes.

All of the lift comes from 21 positive finishes, of which 15 prizes carry +571 on their own. Every
other event class - absence, zero-score, ordinary placed finishes - is a net drain, and non-prize
played results net -51 across the whole log.
