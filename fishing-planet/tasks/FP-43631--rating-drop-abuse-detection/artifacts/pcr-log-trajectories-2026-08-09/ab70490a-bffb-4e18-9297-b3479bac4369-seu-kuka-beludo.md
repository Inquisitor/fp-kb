---
date: 2026-08-09
player: Seu_Kuka_Beludo
platform: PlayStation
profile_id: ab70490a-bffb-4e18-9297-b3479bac4369
artifact: PCR trajectory card -- parsed from the Mongo Tournament-log dump
source_dump: ab70490a-bffb-4e18-9297-b3479bac4369-seu-kuka-beludo.tsv
log_window: 2026-07-26T13:43:05Z .. 2026-08-09T12:00:20Z (14 days)
ledger_entries: 91 (played 63 / no-show 28)
pcr: { start: 117, end: 132, min: 78, max: 201 }
sql_ground_truth: { pcr: 132, reg: 51, started: 33, zero_score: 5, no_shows: 18, no_show_pct: 35.3, absence: -278, play: 271, net: -7, prizes: "7 = 5N/2M/0T", played_split: "7N/25M/1T", lifetime_prizes: "7/3/3" }
---

# Seu_Kuka_Beludo (PS) -- PCR trajectory, 2026-07-26 .. 2026-08-09

## Read of the trajectory

Sawtooth around the NOOBS/MIDDLES boundary (PCR 100), repeated six times in fourteen days.
The ledger never approaches the floor (min **78**), so nothing here is clamped: the printed delta
equals `after - before` on **all 91** entries, and every `before` matches the previous `after`
(zero continuity breaks). The trajectory below is therefore complete for the dumped window -- there
are no invisible at-zero penalties hiding in it.

| metric | value |
|---|---|
| PCR at first ledger entry | 117 |
| PCR at last ledger entry | 132 (matches SQL PCR 132) |
| PCR min / max | 78 / 201 |
| Ledger entries | 91 |
| PLAYED (has `started scoring time`) | 63, sum +423 |
| NO-SHOW (reward entry, no scoring start) | 28, sum -408 |
| Net over the dump window | +15 |
| Registrations / unregistrations | 112 / 12 |
| `FAILED: Register in competition` | 0 |
| CHEAT triggers | 840 |
| Batched flush groups (>1 entry within 60 s) | 6 |
| Crossings of PCR 100 | 12 (6 down / 6 up) |
| Crossings of PCR 1000 | 0 (ceiling 201, TOPS never reached) |

No-show penalties are quantised: 9 x -20, 5 x -15, 3 x -13, 4 x -11, 7 x -10.

## Ledger

`delta` is computed from the before->after pair, not from the printed value (they agree everywhere here).
`bracket` is the bracket after the entry; a crossing is written as `X -> Y`.

| Timestamp (UTC) | Comp ID | Comp name | Status | delta | PCR before->after | bracket |
|---|---|---|---|---|---|---|
| 2026-07-26T13:43:06Z | 374028 | Cã Siberiano | NO-SHOW | -13 | 117 -> 104 | MIDDLES |
| 2026-07-26T14:00:31Z | 374032 | Caça veloz ao Bass | PLAYED | -8 | 104 -> 96 | **MIDDLES -> NOOBS** |
| 2026-07-26T20:00:33Z | 374035 | Truta Tripla! | PLAYED | -1 | 96 -> 95 | NOOBS |
| 2026-07-27T09:57:09Z | 374037 | Desafio de Bagre | PLAYED | +15 | 95 -> 110 | **NOOBS -> MIDDLES** |
| 2026-07-27T12:00:17Z | 374113 | Fóssil Vivo | PLAYED | -7 | 110 -> 103 | MIDDLES |
| 2026-07-27T14:00:20Z | 374114 | Rodada da Garoupa-Gigante! | PLAYED | +30 | 103 -> 133 | MIDDLES |
| 2026-07-27T16:00:36Z | 374115 | Três Poderosos | PLAYED | -6 | 133 -> 127 | MIDDLES |
| 2026-07-27T19:18:07Z | 374116 | O Tamanho Importa! | PLAYED | -4 | 127 -> 123 | MIDDLES |
| 2026-07-27T20:00:30Z | 374117 | Ferva o labirinto! | PLAYED | -7 | 123 -> 116 | MIDDLES |
| 2026-07-27T22:43:44Z | 374118 | Caça ao Peixe de Ouro | PLAYED | -5 | 116 -> 111 | MIDDLES |
| 2026-07-28T00:00:47Z | 374119 | Competição do Velho Buck | PLAYED | -3 | 111 -> 108 | MIDDLES |
| 2026-07-28T02:00:37Z | 374120 | Batalha de Cabeças de Aço | PLAYED | -4 | 108 -> 104 | MIDDLES |
| 2026-07-28T11:04:25Z | 374201 | Lucky Ghost Hunt | NO-SHOW | -15 | 104 -> 89 | **MIDDLES -> NOOBS** |
| 2026-07-28T11:04:25Z | 374202 | Valsa com Lúcio | NO-SHOW | -11 | 89 -> 78 | NOOBS |
| 2026-07-28T14:00:12Z | 374206 | Cabo-de-Guerra com Espadim! | PLAYED | +55 | 78 -> 133 | **NOOBS -> MIDDLES** |
| 2026-07-29T09:19:12Z | 374311 | Jovial Carpa! | PLAYED | -6 | 133 -> 127 | MIDDLES |
| 2026-07-29T10:00:11Z | 374313 | Gar lunar | PLAYED | -6 | 127 -> 121 | MIDDLES |
| 2026-07-29T12:42:10Z | 374314 | Apanha-os Todos | PLAYED | -2 | 121 -> 119 | MIDDLES |
| 2026-07-29T14:00:45Z | 374315 | Cinco por Um | PLAYED | -3 | 119 -> 116 | MIDDLES |
| 2026-07-29T16:00:18Z | 374316 | Banzai de Atum! | PLAYED | +40 | 116 -> 156 | MIDDLES |
| 2026-07-29T20:00:28Z | 374318 | Ferva o labirinto! | PLAYED | -7 | 156 -> 149 | MIDDLES |
| 2026-07-29T23:32:56Z | 374319 | Rodeio no topo da água | PLAYED | -7 | 149 -> 142 | MIDDLES |
| 2026-07-30T00:00:15Z | 374320 | Grande encontro do Alabote! | PLAYED | -1 | 142 -> 141 | MIDDLES |
| 2026-07-30T17:46:49Z | 374412 | Questões de tamanho | NO-SHOW | -10 | 141 -> 131 | MIDDLES |
| 2026-07-31T01:19:56Z | 374420 | Pegou Um, Pegue Mais | NO-SHOW | -10 | 131 -> 121 | MIDDLES |
| 2026-08-01T16:00:12Z | 374523 | Frenesi do mármore no Tibre | PLAYED | -5 | 121 -> 116 | MIDDLES |
| 2026-08-01T16:00:21Z | 374631 | Longa Ásia | PLAYED | -5 | 116 -> 111 | MIDDLES |
| 2026-08-01T16:01:14Z | 374526 | Rodada da Garoupa-Gigante! | PLAYED | +35 | 111 -> 146 | MIDDLES |
| 2026-08-01T16:01:14Z | 374520 | Imperador do Nilo | PLAYED | +55 | 146 -> 201 | MIDDLES |
| 2026-08-01T16:01:43Z | 374527 | Perfeccionismo de Truta | NO-SHOW | -10 | 201 -> 191 | MIDDLES |
| 2026-08-01T16:01:44Z | 374625 | Desafio de Bagre | NO-SHOW | -11 | 191 -> 180 | MIDDLES |
| 2026-08-01T16:02:14Z | 374525 | O Tamanho Importa! | PLAYED | -6 | 180 -> 174 | MIDDLES |
| 2026-08-01T16:02:44Z | 374627 | Amigo da Árvore | NO-SHOW | -10 | 174 -> 164 | MIDDLES |
| 2026-08-01T16:03:14Z | 374626 | San Joaquin sem Fronteiras! | NO-SHOW | -11 | 164 -> 153 | MIDDLES |
| 2026-08-01T18:00:12Z | 374632 | Grande Irmão | NO-SHOW | -20 | 153 -> 133 | MIDDLES |
| 2026-08-01T20:00:25Z | 374633 | Rodeio no topo da água | PLAYED | +20 | 133 -> 153 | MIDDLES |
| 2026-08-02T00:00:23Z | 374635 | Caça aos Carnívoros Troféu! | PLAYED | -2 | 153 -> 151 | MIDDLES |
| 2026-08-02T02:00:22Z | 374636 | Mais afiado que uma espada! | PLAYED | -7 | 151 -> 144 | MIDDLES |
| 2026-08-02T08:58:07Z | 374731 | Três Poderosos | PLAYED | -6 | 144 -> 138 | MIDDLES |
| 2026-08-02T10:00:24Z | 374734 | Perigo no capim | PLAYED | -7 | 138 -> 131 | MIDDLES |
| 2026-08-02T14:01:43Z | 374736 | Minis extraordinários da Noruega! | NO-SHOW | -20 | 131 -> 111 | MIDDLES |
| 2026-08-02T14:01:43Z | 374735 | Carpas grandes e pequenas | PLAYED | -4 | 111 -> 107 | MIDDLES |
| 2026-08-02T16:00:20Z | 374737 | Precisão Ideal | PLAYED | +23 | 107 -> 130 | MIDDLES |
| 2026-08-02T18:00:36Z | 374738 | O Melhor Picão de Todos | PLAYED | -4 | 130 -> 126 | MIDDLES |
| 2026-08-02T20:01:01Z | 374739 | Cã Siberiano | PLAYED | -5 | 126 -> 121 | MIDDLES |
| 2026-08-03T02:00:40Z | 374742 | O Salmão chega à meia-noite | PLAYED | -5 | 121 -> 116 | MIDDLES |
| 2026-08-03T05:00:31Z | 374835 | Pintas ou pinima? | NO-SHOW | -15 | 116 -> 101 | MIDDLES |
| 2026-08-03T06:00:08Z | 374836 | Lucky Ghost Hunt | NO-SHOW | -15 | 101 -> 86 | **MIDDLES -> NOOBS** |
| 2026-08-03T14:00:18Z | 374840 | Sem Régua - Sem Festa | PLAYED | +40 | 86 -> 126 | **NOOBS -> MIDDLES** |
| 2026-08-03T16:00:34Z | 374841 | Batalha de Cabeças de Aço | PLAYED | +30 | 126 -> 156 | MIDDLES |
| 2026-08-03T23:25:24Z | 374843 | Rodada da Garoupa-Gigante! | NO-SHOW | -20 | 156 -> 136 | MIDDLES |
| 2026-08-03T23:25:24Z | 374844 | Gar lunar | NO-SHOW | -11 | 136 -> 125 | MIDDLES |
| 2026-08-04T00:00:29Z | 374845 | Lucioperca Zeek Diferenças | PLAYED | +6 | 125 -> 131 | MIDDLES |
| 2026-08-04T02:00:23Z | 374846 | Carnívoros Maku-Maku | PLAYED | +37 | 131 -> 168 | MIDDLES |
| 2026-08-04T04:00:17Z | 374919 | Cã Siberiano | PLAYED | -3 | 168 -> 165 | MIDDLES |
| 2026-08-04T09:25:01Z | 374920 | Grass Сutter Range | NO-SHOW | -15 | 165 -> 150 | MIDDLES |
| 2026-08-04T09:25:01Z | 374921 | Ponto por ponto | NO-SHOW | -20 | 150 -> 130 | MIDDLES |
| 2026-08-04T10:00:16Z | 374922 | Lúcios cinco estrelas! | PLAYED | -1 | 130 -> 129 | MIDDLES |
| 2026-08-04T12:00:21Z | 374923 | Sável imparável | PLAYED | -2 | 129 -> 127 | MIDDLES |
| 2026-08-04T18:00:21Z | 374926 | Trilho dos Tigres | PLAYED | -2 | 127 -> 125 | MIDDLES |
| 2026-08-05T00:40:01Z | 374929 | O Salmão chega à meia-noite | PLAYED | -5 | 125 -> 120 | MIDDLES |
| 2026-08-05T02:00:15Z | 374930 | Sorria, hora de Jacundá! | PLAYED | -8 | 120 -> 112 | MIDDLES |
| 2026-08-05T04:00:06Z | 375033 | Não vou te machucar, Tubarão! | NO-SHOW | -20 | 112 -> 92 | **MIDDLES -> NOOBS** |
| 2026-08-05T10:00:29Z | 376070 | Truta Tripla! | PLAYED | +30 | 92 -> 122 | **NOOBS -> MIDDLES** |
| 2026-08-05T15:11:39Z | 376072 | Cabo-de-Guerra com Espadim! | PLAYED | -2 | 122 -> 120 | MIDDLES |
| 2026-08-05T16:00:13Z | 376073 | Gar lunar | PLAYED | -6 | 120 -> 114 | MIDDLES |
| 2026-08-05T21:40:19Z | 376075 | Todos os Peixes, Tudo Incluído! | NO-SHOW | -20 | 114 -> 94 | **MIDDLES -> NOOBS** |
| 2026-08-05T22:00:44Z | 376076 | Caça aos Predadores do Emerald | PLAYED | -3 | 94 -> 91 | NOOBS |
| 2026-08-06T00:00:23Z | 376077 | Um Curto e Outro Comprido | PLAYED | +20 | 91 -> 111 | **NOOBS -> MIDDLES** |
| 2026-08-06T02:00:24Z | 376078 | Vermelho e brilhante | PLAYED | +47 | 111 -> 158 | MIDDLES |
| 2026-08-06T09:02:02Z | 376081 | Origens da Carpa | NO-SHOW | -13 | 158 -> 145 | MIDDLES |
| 2026-08-06T09:02:03Z | 376079 | Questões de tamanho | NO-SHOW | -10 | 145 -> 135 | MIDDLES |
| 2026-08-06T09:02:03Z | 376080 | Captura Pequena do Neherrin | NO-SHOW | -10 | 135 -> 125 | MIDDLES |
| 2026-08-06T10:00:15Z | 376082 | Titãs Vermelhos | PLAYED | -5 | 125 -> 120 | MIDDLES |
| 2026-08-06T14:00:37Z | 376084 | O rio das cranks | PLAYED | -5 | 120 -> 115 | MIDDLES |
| 2026-08-06T18:00:12Z | 376086 | Minis extraordinários da Noruega! | NO-SHOW | -20 | 115 -> 95 | **MIDDLES -> NOOBS** |
| 2026-08-06T20:00:21Z | 376087 | Gar-magedom na lama | NO-SHOW | -10 | 95 -> 85 | NOOBS |
| 2026-08-06T22:30:23Z | 376088 | Gigantes Vermelhos | PLAYED | +25 | 85 -> 110 | **NOOBS -> MIDDLES** |
| 2026-08-07T00:00:19Z | 376089 | Rodada da Garoupa-Gigante! | PLAYED | +55 | 110 -> 165 | MIDDLES |
| 2026-08-07T02:00:22Z | 376090 | Diversidade do Rio Marron | PLAYED | +15 | 165 -> 180 | MIDDLES |
| 2026-08-07T11:58:24Z | 376091 | Sem medo de tubarões! | NO-SHOW | -20 | 180 -> 160 | MIDDLES |
| 2026-08-07T16:00:36Z | 376097 | Perfeccionismo de Truta | PLAYED | -3 | 160 -> 157 | MIDDLES |
| 2026-08-07T20:00:18Z | 376099 | Corrida verdadeiramente única! | PLAYED | -6 | 157 -> 151 | MIDDLES |
| 2026-08-07T22:00:31Z | 376100 | Amigo da Árvore | PLAYED | -3 | 151 -> 148 | MIDDLES |
| 2026-08-08T02:00:16Z | 376102 | Flutuador e Lota-do-Rio | NO-SHOW | -13 | 148 -> 135 | MIDDLES |
| 2026-08-08T14:56:29Z | 376107 | O Caçador de Bagres Insuperável | PLAYED | -5 | 135 -> 130 | MIDDLES |
| 2026-08-08T16:00:11Z | 376109 | Ameaça Sangrenta | NO-SHOW | -15 | 130 -> 115 | MIDDLES |
| 2026-08-08T20:02:55Z | 376111 | Caça veloz ao Bass | PLAYED | -8 | 115 -> 107 | MIDDLES |
| 2026-08-09T02:00:21Z | 376114 | Os 50 da sorte | PLAYED | +47 | 107 -> 154 | MIDDLES |
| 2026-08-09T04:00:06Z | 376115 | Woohoo Cavala-Wahoo! | NO-SHOW | -20 | 154 -> 134 | MIDDLES |
| 2026-08-09T12:00:20Z | 376119 | Cã Siberiano | PLAYED | -2 | 134 -> 132 | MIDDLES |

## Bracket crossings

| Timestamp (UTC) | Comp ID | Direction | Status | PCR |
|---|---|---|---|---|
| 2026-07-26T14:00:31Z | 374032 | down | PLAYED | 104 -> 96 |
| 2026-07-27T09:57:09Z | 374037 | up | PLAYED | 95 -> 110 |
| 2026-07-28T11:04:25Z | 374201 | down | NO-SHOW | 104 -> 89 |
| 2026-07-28T14:00:12Z | 374206 | up | PLAYED | 78 -> 133 |
| 2026-08-03T06:00:08Z | 374836 | down | NO-SHOW | 101 -> 86 |
| 2026-08-03T14:00:18Z | 374840 | up | PLAYED | 86 -> 126 |
| 2026-08-05T04:00:06Z | 375033 | down | NO-SHOW | 112 -> 92 |
| 2026-08-05T10:00:29Z | 376070 | up | PLAYED | 92 -> 122 |
| 2026-08-05T21:40:19Z | 376075 | down | NO-SHOW | 114 -> 94 |
| 2026-08-06T00:00:23Z | 376077 | up | PLAYED | 91 -> 111 |
| 2026-08-06T18:00:12Z | 376086 | down | NO-SHOW | 115 -> 95 |
| 2026-08-06T22:30:23Z | 376088 | up | PLAYED | 85 -> 110 |

All 6 upward crossings are PLAYED results. 5 of the 6 downward crossings are NO-SHOWs; the single
played down-crossing is the first entry in the dump (#374032, -8) -- an ordinary weak result, not a drop.

## Harvest cycles (down-cross -> next positive result)

| Down-cross | Comp | Status | PCR | Next gain | Comp | Place | PCR | Gap |
|---|---|---|---|---|---|---|---|---|
| 2026-07-26T14:00:31Z | #374032 | PLAYED | 104 -> 96 | 2026-07-27T09:57:09Z | #374037 | 6 | 95 -> 110 (+15) | 19.9 h |
| 2026-07-28T11:04:25Z | #374201 | NO-SHOW | 104 -> 89 | 2026-07-28T14:00:12Z | #374206 | 1 | 78 -> 133 (+55) | 2.9 h |
| 2026-08-03T06:00:08Z | #374836 | NO-SHOW | 101 -> 86 | 2026-08-03T14:00:18Z | #374840 | 4 | 86 -> 126 (+40) | 8.0 h |
| 2026-08-05T04:00:06Z | #375033 | NO-SHOW | 112 -> 92 | 2026-08-05T10:00:29Z | #376070 | 2 | 92 -> 122 (+30) | 6.0 h |
| 2026-08-05T21:40:19Z | #376075 | NO-SHOW | 114 -> 94 | 2026-08-06T00:00:23Z | #376077 | 8 | 91 -> 111 (+20) | 2.3 h |
| 2026-08-06T18:00:12Z | #376086 | NO-SHOW | 115 -> 95 | 2026-08-06T22:30:23Z | #376088 | 3 | 85 -> 110 (+25) | 4.5 h |

## Placement by bracket at result time

Places are read off the `About to process tournament ... Place: N` markers; they are context only,
not part of the ledger spine.

- Scored while **NOOBS** (PCR before the result <= 100): n=8, places 1, 2, 3, 4, 6, 8, 14, 21 -- median 6
- Scored while **MIDDLES** (PCR before the result 101-1000): n=43, places 1, 1, 1, 1, 2, 3, 3, 4, 5, 5, 6, 8, 9, 14, 14, 15, 15, 15, 16, 17, 18, 19, 19, 21, 22, 22, 23, 23, 23, 25, 26, 26, 26, 26, 28, 32, 33, 34, 34, 39, 42, 51, 60 -- median 19

Same player, same fortnight: top-8 in 6 of the 8 competitions scored from NOOBS, median place around
19 once the rating is back in MIDDLES.

## Batched flush groups

- **2026-07-28T11:04:25Z .. 2026-07-28T11:04:25Z** -- 2 entries, 104 -> 78: #374201 -15 N, #374202 -11 N
- **2026-08-01T16:00:12Z .. 2026-08-01T16:03:14Z** -- 9 entries, 121 -> 153: #374523 -5 P, #374631 -5 P, #374526 +35 P, #374520 +55 P, #374527 -10 N, #374625 -11 N, #374525 -6 P, #374627 -10 N, #374626 -11 N
- **2026-08-02T14:01:43Z .. 2026-08-02T14:01:43Z** -- 2 entries, 131 -> 107: #374736 -20 N, #374735 -4 P
- **2026-08-03T23:25:24Z .. 2026-08-03T23:25:24Z** -- 2 entries, 156 -> 125: #374843 -20 N, #374844 -11 N
- **2026-08-04T09:25:01Z .. 2026-08-04T09:25:01Z** -- 2 entries, 165 -> 130: #374920 -15 N, #374921 -20 N
- **2026-08-06T09:02:02Z .. 2026-08-06T09:02:03Z** -- 3 entries, 158 -> 125: #376081 -13 N, #376079 -10 N, #376080 -10 N

## Cross-check against SQL

SQL (authoritative for volume): PCR 132, Reg 51, started 33, zero-score 5, no-shows 18 (35.3%),
absence -278, play +271, net -7, prizes 7 = 5N/2M/0T, played 7N/25M/1T, lifetime prizes 7/3/3.

- **Agrees** -- end state. Ledger ends at 132, SQL reports PCR 132.
- **Agrees** -- shape. SQL play/absence split (+271 vs -278, net -7) is the same near-cancelling
  sawtooth the ledger shows (+423 vs -408, net +15 across the dump window).
- **Agrees** -- prize placement. SQL puts 5 of 7 window prizes in NOOBS; the ledger shows the large
  gains being taken right after a no-show has pushed PCR back under 100.
- **Differs in volume**. The dump holds 91 reward entries and 112 registrations against SQL 51
  registrations / 33 starts, so the SQL window is narrower than this 14-day dump. Quote SQL, not this
  card, for counts.
- The dump has no prize-award lines at all. Prize counts are SQL-only and are not re-derived here.

## Unmatched / partial data

- 8 competitions carry a `started scoring time` line but no reward entry in the dump
  (#374212, #374411, #374522, #374741, #374925, #376074, #376098, #376120) -- processed outside the dump window, or scored zero.
- No `Registration for tournament Competition #` and no `FAILED: Register in competition` lines occur
  in this dump; registration appears only as `Player registered for Competition #` (112) and
  `Player unregistered from Competition #` (12).
- CHEAT triggers, counted only: **840**. Most frequent: Line has high extension too often x247; Fish catch distance is VERY long x140; Friction force is too high x129; Undriven boat moves TOO fast x75; Attack time is short x56.
- All 28 no-show entries have an empty `Place:` marker, consistent with no scored result.
