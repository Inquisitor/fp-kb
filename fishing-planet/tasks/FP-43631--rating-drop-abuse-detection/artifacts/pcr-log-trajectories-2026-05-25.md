# FP-43631 — PCR trajectories from Mongo Tournament log (5 prize-zone players)

Pulled 2026-05-25 from per-platform Mongo `tournamentLog` collection, schema `main2` (the
active one; `main` is stale historical data). Filter: `Message: /CompetitionRating/`,
sorted by `Timestamp`. UserIds are lowercased (the log stores them lowercased).

## What the Tournament log is

`DalFactory.GetLogger().Tournament.Log(userId, message)` writes the entire competition
result/reward pipeline to Mongo. The rating-change line has the shape:

```
Tournament reward Competition #<id> '<name>' added CompetitionRating <delta> (<before> -> <after>)
```

`<before> -> <after>` is the **actual applied PCR transition** (post-clamp), so the log is a
literal PCR ledger — no reconstruction needed.

### Key structural findings

1. **The ledger is continuous.** Across all 57 of Holekko's entries, every `<after>` equals
   the next `<before>` — zero gaps. So the log captures *every* PCR-affecting event, not just
   played tournaments.
2. **No-shows are therefore in this log.** A no-show applies `NoShowRatingPenalty` to PCR;
   since the chain has no gaps, those penalties must appear here too — mixed into the negative
   entries. The message text does *not* mark them as no-shows (it says "reward" for everyone,
   because `result.Rating` is written for every participant regardless of `IsStarted` — see
   journal "Key Findings"). Magnitude doesn't isolate them either: the observed floor is `-20`,
   same as the worst placed-out-of-money finish.
3. **Batch flush on login.** Clusters with identical timestamps (e.g. 5 of Holekko's entries at
   `2026-05-24 03:06:01`) are the result window the player sees on login — all competitions that
   ended while they were offline get flushed at once. This is exactly why the *last* planned-but-
   not-logged-in skip series is invisible: it hasn't been flushed yet.
4. **The log self-contains a no-show detector.** `tournamentLog` also stores gameplay events:
   `Player registered for Competition #X`, `Player started scoring time for Competition #X`,
   `Fish caught…`. A competition with an `added CompetitionRating` entry but **no**
   `started scoring time` entry = a no-show. (Cross-referencing `TournamentParticipants.IsStarted`
   in SQL gives the same answer.)

## Behavioral read of the 5 prize-zone players

> **Correction.** A first pass over the raw ledger (continuous oscillation in a 0–240 band)
> read these as "high-volume grinders, not abusers". Labelling each entry as no-show vs. played
> (via the `started scoring time` cross-check) **reversed that** — most of their negative entries
> are no-shows, not bad finishes.

No-show labelling (whole logged window; `ratingSum` is the raw penalty/reward delta — slightly
overcounts the actual PCR move because PCR is clamped at 0):

| Player         | Platform | Played | Rating (played) | No-shows | Rating (no-show) | No-show % |
|----------------|----------|-------:|----------------:|---------:|-----------------:|----------:|
| Holekko        | Steam    |     23 |            +480 |       34 |             −482 |       60% |
| VITAO4460      | Xbox     |     33 |            +583 |       34 |             −459 |       51% |
| profpaulo18    | Xbox     |     21 |            +474 |       20 |             −315 |       49% |
| IIGot-_-Smoked | PS       |      6 |            +178 |       12 |             −155 |       67% |
| Djarumsuper16  | Steam    |     14 |            +192 |        9 |             −120 |       39% |

**The "played gain ≈ no-show loss" balance is the rating-drop abuse signature.** When these players
actually show up they post a strong positive (+192…+583) — they are TOPS-caliber. Yet each
no-shows 39–67% of registrations, bleeding off almost exactly what they earn, which pins PCR in
the NOOBS/low-MIDDLES band. A skilled player can only sit at low PCR by deflating it via
no-shows; the prizes are then won in the easy bracket they parked themselves in. All five fit
this. Cleanest case is **Djarumsuper16** (lowest no-show share, net climbing) — borderline.
Worst are **Holekko / VITAO4460 / IIGot-_-Smoked** (51–67% no-show with strong play).

The `started scoring time` cross-check is self-contained in `tournamentLog`; it agrees with
`TournamentParticipants.IsStarted` in SQL and needs no second data source.

| Player         | Platform | UserId                                 | Entries | PCR span (visible) | Notable                                                                          |
|----------------|----------|----------------------------------------|--------:|--------------------|----------------------------------------------------------------------------------|
| Holekko        | Steam    | `5e3f0096-55ed-4715-ba43-4a7f377507a4` |      57 | 98 → 49 (peak 200) | Highest-context volume; ends low — net rating *loss* over window                 |
| Djarumsuper16  | Steam    | `f1291aed-38ff-4f3b-ae5d-cfceb69b6f86` |      23 | 167 → 211          | Short window (from 05-19); net climbing; lowest no-show share (39%) — borderline |
| IIGot-_-Smoked | PS       | `8f36f30f-ade0-4d9a-bc88-765ae61e5384` |      18 | 0 → 23             | Ledger stops 05-21 — quit or hasn't logged in since (pending results unflushed)  |
| VITAO4460      | Xbox     | `5cec46b5-e4ca-43bd-9bd1-3bb493460a4e` |      66 | 6 → 101            | Highest raw volume; constant oscillation 6–200                                   |
| profpaulo18    | Xbox     | `4bf7e769-1526-47a4-9795-5a7b3fdf1d3c` |      41 | 0 → 130 (peak 237) | New to competitions ~05-16; climbed then settled                                 |

> VITAO4460 and profpaulo18 share the same Xbox/Brazilian competition pool (overlapping
> `#153xxx` IDs), so their ledgers reference many of the same events.

---

## Full ledgers

### Holekko — Steam — `5e3f0096-55ed-4715-ba43-4a7f377507a4` (57)

```
2026-05-12 16:33:58  #320482 'Cętkowane Szczęście'           +22 (98 -> 120)
2026-05-13 17:18:31  #320643 'Bassowe Wyzwanie'              -10 (120 -> 110)
2026-05-13 17:18:31  #320644 'Wielki Brat'                   -20 (110 -> 90)
2026-05-13 17:18:31  #320642 'Pojedynek z Jesiotrem!'        -10 (90 -> 80)
2026-05-13 17:18:31  #320646 'Jedna za Drugą'                -10 (80 -> 70)
2026-05-13 17:18:31  #320645 'Niech to karp trafi!'          -15 (70 -> 55)
2026-05-13 18:00:07  #320647 'Długa Azja'                    -13 (55 -> 42)
2026-05-13 20:00:16  #320648 'Cesarz Nilu'                   +55 (42 -> 97)
2026-05-14 18:00:14  #320760 'Przeciąganie liny z marlinem!' +55 (97 -> 152)
2026-05-14 20:00:13  #320761 'Ściśnij Lin!'                  +30 (152 -> 182)
2026-05-15 18:00:06  #320867 'Pełny pakiet: Wielki połów!'   -20 (182 -> 162)
2026-05-16 07:52:42  #320868 'Zmagania w labiryncie'         -7  (162 -> 155)
2026-05-17 08:00:07  #321115 'Nie zrobię ci krzywdy, Rekinu!' +45 (155 -> 200)
2026-05-20 20:00:07  #321457 'Polowanie na szybkość Bassów'  -8  (200 -> 192)
2026-05-20 22:00:14  #321458 'Zmagania w labiryncie'         -1  (192 -> 191)
2026-05-21 05:27:52  #321459 'Maskinongi na górze'           -3  (191 -> 188)
2026-05-21 18:13:40  #321545 'Bassowe Wyzwanie'              -3  (188 -> 185)
2026-05-21 18:13:40  #321549 'Bliźniaki labeo'               -15 (185 -> 170)
2026-05-21 18:13:41  #321546 'Czarno na białym'              -11 (170 -> 159)
2026-05-21 18:13:41  #321548 'Szczęśliwe polowanie na duchy' -15 (159 -> 144)
2026-05-21 18:13:41  #321547 'Bitwa nad rzeką Kaniq'         -13 (144 -> 131)
2026-05-21 20:00:17  #321550 'Zakręć Pstrąg!'                +6  (131 -> 137)
2026-05-22 05:08:56  #321552 'Krwawe Zagrożenie'             -15 (137 -> 122)
2026-05-22 05:08:56  #321654 'Maleństwa Neherrin'            -10 (122 -> 112)
2026-05-22 05:08:56  #321553 'Ooh, Barrakuda'                -20 (112 -> 92)
2026-05-22 06:00:05  #321655 'Bass szkolny'                  -10 (92 -> 82)
2026-05-22 08:00:07  #321656 'Wyjątkowe maluchy Norwegii!'   -2  (82 -> 80)
2026-05-22 10:00:07  #321657 'Długa Azja'                    +40 (80 -> 120)
2026-05-22 12:00:08  #321658 'Rozmiar Ma Znaczenie'          +30 (120 -> 150)
2026-05-22 14:00:04  #321659 'Leniwy Jaź'                    -13 (150 -> 137)
2026-05-22 16:00:04  #321660 'Czerwony i błyszczący'         -15 (137 -> 122)
2026-05-22 18:44:28  #321661 'Łowca Drapieżników Emerald'    -10 (122 -> 112)
2026-05-22 20:00:06  #321662 'Pospolity…Karp!'               -11 (112 -> 101)
2026-05-22 22:00:06  #321663 'Bitwa Czerwonych Tytanów'      -13 (101 -> 88)
2026-05-23 03:57:46  #321665 'Nocna Rubinowa Zdobyczy!'      -20 (88 -> 68)
2026-05-23 03:57:46  #321664 'Pojedynek z dwoma boleniami'   +17 (68 -> 85)
2026-05-23 05:07:01  #321759 'Walc ze Szczupakiem'           -11 (85 -> 74)
2026-05-23 06:00:12  #321760 'Precyzja idealna'              +30 (74 -> 104)
2026-05-23 12:55:06  #321761 'Duża Czerwona Ryba!'           -11 (104 -> 93)
2026-05-23 12:55:06  #321762 'Pojedynek z Jesiotrem!'        -20 (93 -> 73)
2026-05-23 12:55:07  #321763 'Spławik i Miętus'              -13 (73 -> 60)
2026-05-23 14:00:19  #321764 'Wymarzone polowanie na leszcza' -5 (60 -> 55)
2026-05-23 16:00:08  #321765 'Polowanie na mięsożerców o trofeum!' +55 (55 -> 110)
2026-05-24 03:06:01  #321766 'Punkt za punktem'              -20 (110 -> 90)
2026-05-24 03:06:01  #321767 'Uderzenie! I uderz ponownie!'  -13 (90 -> 77)
2026-05-24 03:06:01  #321768 'Okoniowa gorączka złota'       -10 (77 -> 67)
2026-05-24 03:06:01  #321769 'Zakręć Pstrąg!'                -10 (67 -> 57)
2026-05-24 03:06:01  #321770 'Ooh, Barrakuda'                -20 (57 -> 37)
2026-05-24 04:13:32  #321862 'Bez linijki nie ma zabawy'     -20 (37 -> 17)
2026-05-24 06:09:03  #321863 'Pierwszorzędny Sum'            -10 (17 -> 7)
2026-05-24 09:51:59  #321864 'Bitwa nad rzeką Kaniq'         +40 (7 -> 47)
2026-05-24 10:00:05  #321865 'Wielkie zgromadzenie Halibutów!' -20 (47 -> 27)
2026-05-24 13:36:43  #321866 'Mięsożercy z Maku-Maku'        -8  (27 -> 19)
2026-05-24 14:00:07  #321867 'Długość ma znaczenie'          -10 (19 -> 9)
2026-05-24 16:00:15  #321868 'Rzeka cranków'                 +20 (9 -> 29)
2026-05-24 18:00:08  #321869 'Wielka Trójca'                 -15 (29 -> 14)
2026-05-24 20:00:15  #321870 'Cętkowane Szczęście'           +35 (14 -> 49)
```

### Djarumsuper16 — Steam — `f1291aed-38ff-4f3b-ae5d-cfceb69b6f86` (23)

```
2026-05-19 10:54:24  #321370 'Falcon Trout Chase'           -10 (167 -> 157)
2026-05-20 09:47:40  #321377 'Kaniq Topwater Rodeo'         -13 (157 -> 144)
2026-05-21 01:04:37  #321457 'Bass Speed Hunt'              -15 (144 -> 129)
2026-05-21 01:04:37  #321458 'Blaze the Maze'               -20 (129 -> 109)
2026-05-21 01:04:37  #321459 'Muskie Topping'               -11 (109 -> 98)
2026-05-21 02:00:16  #321460 'One by One'                   +5  (98 -> 103)
2026-05-21 06:53:29  #321542 'Marron River Diversity'       +47 (103 -> 150)
2026-05-21 11:00:03  #321544 'Crank the river'              -5  (150 -> 145)
2026-05-21 11:00:03  #321545 'Bass Challenge'               -10 (145 -> 135)
2026-05-21 12:22:04  #321546 'Sturgeon in the Dark'         -11 (135 -> 124)
2026-05-22 09:22:10  #321550 'Spin The Trout'               -3  (124 -> 121)
2026-05-22 09:22:10  #321552 'Bloody Threat'                -15 (121 -> 106)
2026-05-22 12:45:53  #321658 'The Size Matters'             +7  (106 -> 113)
2026-05-22 17:01:19  #321660 'Red and Shiny'                -15 (113 -> 98)
2026-05-23 00:47:17  #321661 'Emerald Predator Hunt'        -3  (98 -> 95)
2026-05-23 04:17:14  #321759 'Dancing with Pike'            +35 (95 -> 130)
2026-05-23 09:16:11  #321761 'Big Red Fish'                 +35 (130 -> 165)
2026-05-23 12:16:20  #321763 'Bobber Burbot'                +30 (165 -> 195)
2026-05-23 18:00:12  #321766 'Point by Point'               +25 (195 -> 220)
2026-05-24 03:34:01  #321767 'Strike! And another strike!'  -5  (220 -> 215)
2026-05-24 12:00:19  #321866 'Maku-Maku Carnivores'         -6  (215 -> 209)
2026-05-24 16:59:33  #321868 'Crank the river'              +8  (209 -> 217)
2026-05-24 19:55:48  #321869 'Mighty Three'                 -6  (217 -> 211)
```

### IIGot-_-Smoked — PS — `8f36f30f-ade0-4d9a-bc88-765ae61e5384` (18)

Ledger stops 2026-05-21 — either quit or has not logged in since (later results unflushed).

```
2026-05-16 12:07:42  #366661 'Zander Zeek Differences'      +11 ( -> 11)   [first competition]
2026-05-16 16:00:10  #366675 'Big Red Fish'                 -11 (11 -> 0)
2026-05-18 02:00:27  #366692 'A Truly Unique Race!'         +35 (0 -> 35)
2026-05-18 04:00:05  #366693 'Marron River Diversity'       -15 (35 -> 20)
2026-05-18 12:01:14  #366697 'I will not bully you, Shark!'  -20 (20 -> 0)
2026-05-19 02:00:15  #366704 'Idle Ide'                     +40 (0 -> 40)
2026-05-19 04:00:16  #366758 'Bass Challenge'               +27 (40 -> 67)
2026-05-19 17:40:19  #366760 'The Battle of Kaniq'          -13 (67 -> 54)
2026-05-19 17:40:19  #366759 'Lucky Ghost Hunt'             -15 (54 -> 39)
2026-05-19 17:40:19  #366762 'Best Five Bass'               -10 (39 -> 29)
2026-05-19 17:40:19  #366764 'Spin The Trout'               -10 (29 -> 19)
2026-05-19 22:00:09  #366767 'One by One'                   -10 (19 -> 9)
2026-05-20 02:00:15  #366769 'Teenies in the Night'         +40 (9 -> 49)
2026-05-20 04:03:33  #366849 'Catch em' All'                +25 (49 -> 74)
2026-05-20 19:28:36  #366851 'Lucky Spot'                   -11 (74 -> 63)
2026-05-20 19:28:36  #366853 'Bloody Threat'                -15 (63 -> 48)
2026-05-20 19:28:36  #366855 'Ideal Accuracy'               -10 (48 -> 38)
2026-05-21 00:12:30  #366857 'Lucky 50'                     -15 (38 -> 23)
```

### VITAO4460 — Xbox — `5cec46b5-e4ca-43bd-9bd1-3bb493460a4e` (66)

```
2026-05-15 16:00:10  #153115 'Manhas da Sorte'              +19 (6 -> 25)
2026-05-15 21:50:55  #153117 'Carpas grandes e pequenas'    +22 (25 -> 47)
2026-05-16 01:48:04  #153119 'O Salmão chega à meia-noite'  +30 (47 -> 77)
2026-05-16 20:00:10  #153129 'Um de nós, Dois de Áspio'     +30 (77 -> 107)
2026-05-17 00:00:14  #153131 'Os 50 da sorte'               +6  (107 -> 113)
2026-05-17 02:00:12  #153132 'Flutuador e Lota-do-Rio'      -2  (113 -> 111)
2026-05-17 04:00:06  #153133 'Escalo-prateado Preguiçoso'   +35 (111 -> 146)
2026-05-17 20:00:09  #153141 'Labeo Gémeos'                 -6  (146 -> 140)
2026-05-17 22:00:13  #153142 'Vitória superfície'           -7  (140 -> 133)
2026-05-18 00:25:13  #153143 'O Tamanho Importa!'           -3  (133 -> 130)
2026-05-18 02:00:18  #153144 'Valsa com Esox'               +13 (130 -> 143)
2026-05-18 04:00:06  #153145 'Lucky Ghost Hunt'             +27 (143 -> 170)
2026-05-18 10:37:52  #153146 'Ameaça Sangrenta'             -2  (170 -> 168)
2026-05-18 22:00:10  #153154 'Aperto de Tenca!'             -2  (168 -> 166)
2026-05-19 21:52:03  #153156 'Ferva o labirinto!'           -6  (166 -> 160)
2026-05-19 21:52:03  #153162 'Longa Ásia'                   -13 (160 -> 147)
2026-05-19 21:52:04  #153158 'Carpas grandes e pequenas'    -11 (147 -> 136)
2026-05-19 21:52:04  #153161 'Batalha do Rio Kaniq'         -13 (136 -> 123)
2026-05-19 21:52:04  #153159 'O Melhor Picão de Todos'      -11 (123 -> 112)
2026-05-19 21:52:05  #153160 'Pegou Um, Pegue Mais'         -10 (112 -> 102)
2026-05-19 21:52:05  #153157 'Manhas da Sorte'              -11 (102 -> 91)
2026-05-20 00:01:22  #153167 'Perigo no capim'              +40 (91 -> 131)
2026-05-20 02:00:10  #153168 'Três Poderosos'               +47 (131 -> 178)
2026-05-20 21:13:16  #153195 'Caça ao Peixe de Ouro'        -10 (178 -> 168)
2026-05-20 21:13:16  #153197 'O Salmão chega à meia-noite'  -13 (168 -> 155)
2026-05-20 21:13:16  #153169 'Caçada ao Barbo com Cavalheiros' -10 (155 -> 145)
2026-05-20 21:13:17  #153198 'Precisão Ideal'               -10 (145 -> 135)
2026-05-21 00:00:14  #153203 'Captura de Monstro do Lameiro' -2 (135 -> 133)
2026-05-21 02:00:07  #153204 'Reunião da família Marlim!'   +25 (133 -> 158)
2026-05-21 21:19:41  #153237 'Sorria, hora de Jacundá!'     -15 (158 -> 143)
2026-05-21 21:19:41  #153238 'Apanha-os Todos'              -10 (143 -> 133)
2026-05-21 21:19:41  #153205 'Big Headhunters'              -2  (133 -> 131)
2026-05-21 21:19:42  #153236 'Truta Tripla!'                -11 (131 -> 120)
2026-05-21 21:19:42  #153241 'Escalo-prateado Preguiçoso'   -13 (120 -> 107)
2026-05-21 21:19:42  #153239 'O Tamanho Importa!'           -11 (107 -> 96)
2026-05-22 00:00:12  #153245 'Perseguindo Trutas no Falcon' +30 (96 -> 126)
2026-05-22 02:00:08  #153246 'Flutuador e Lota-do-Rio'      +40 (126 -> 166)
2026-05-22 20:48:38  #153287 'Mais afiado que uma espada!'  -20 (166 -> 146)
2026-05-22 20:48:38  #153288 'Vermelho e brilhante'         -15 (146 -> 131)
2026-05-22 20:48:38  #153247 'Banzai de Atum!'              -3  (131 -> 128)
2026-05-22 20:48:38  #153286 'Manhas da Sorte'              -11 (128 -> 117)
2026-05-22 20:48:38  #153290 'Lucioperca Zeek Diferenças'   -10 (117 -> 107)
2026-05-22 20:48:38  #153289 'Rodeio no topo da água'       -13 (107 -> 94)
2026-05-22 20:48:38  #153291 'Fóssil Vivo'                  -20 (94 -> 74)
2026-05-23 00:00:03  #153295 'Minis extraordinários da Noruega!' -20 (74 -> 54)
2026-05-23 02:00:12  #153296 'Gigantes Vermelhos'           +25 (54 -> 79)
2026-05-23 04:00:07  #153297 'Três Poderosos'               +32 (79 -> 111)
2026-05-23 06:00:07  #153325 'Ataque à Cornish Jack'        +45 (111 -> 156)
2026-05-23 11:34:05  #153326 'Caça aos Carnívoros Troféu!'  +45 (156 -> 201)
2026-05-23 11:34:06  #153327 'Bass Escolar'                 -10 (201 -> 191)
2026-05-23 15:16:57  #153329 'Woohoo Cavala-Wahoo!'         -20 (191 -> 171)
2026-05-23 15:16:57  #153328 'San Joaquin sem Fronteiras!'  -11 (171 -> 160)
2026-05-23 16:00:03  #153330 'Competição do Velho Buck'     -10 (160 -> 150)
2026-05-23 18:00:09  #153331 'Grass Сutter Range'           +27 (150 -> 177)
2026-05-23 20:00:04  #153332 'Corrida verdadeiramente única!' -11 (177 -> 166)
2026-05-23 22:00:08  #153333 'Sonhe Brema Caçar'            +30 (166 -> 196)
2026-05-24 10:59:58  #153335 'Titãs Vermelhos'              -5  (196 -> 191)
2026-05-24 10:59:59  #153358 'Imperador do Nilo'            -20 (191 -> 171)
2026-05-24 10:59:59  #153336 'Ameaça Sangrenta'             -15 (171 -> 156)
2026-05-24 10:59:59  #153357 'Os 50 da sorte'               -15 (156 -> 141)
2026-05-24 10:59:59  #153356 'Aperto de Tenca!'             -13 (141 -> 128)
2026-05-24 12:00:04  #153359 'Carpas grandes e pequenas'    -6  (128 -> 122)
2026-05-24 14:00:03  #153360 'Cã Siberiano'                 -13 (122 -> 109)
2026-05-24 16:00:36  #153361 'Desafio de Bass'              -3  (109 -> 106)
2026-05-24 19:19:28  #153362 'Sem medo de tubarões!'        +15 (106 -> 121)
2026-05-24 20:16:43  #153363 'Mais afiado que uma espada!'  -20 (121 -> 101)
```

### profpaulo18 — Xbox — `4bf7e769-1526-47a4-9795-5a7b3fdf1d3c` (41)

```
2026-05-16 02:38:38  #153119 'O Salmão chega à meia-noite'  +14 (0 -> 14)   [first competition]
2026-05-17 00:00:14  #153131 'Os 50 da sorte'               +15 (14 -> 29)
2026-05-17 02:00:09  #153132 'Flutuador e Lota-do-Rio'      +40 (29 -> 69)
2026-05-17 04:00:07  #153133 'Escalo-prateado Preguiçoso'   -1  (69 -> 68)
2026-05-17 09:57:19  #153134 'Batalha de Cabeças de aço'    +25 (68 -> 93)
2026-05-17 20:00:05  #153141 'Labeo Gémeos'                 +47 (93 -> 140)
2026-05-17 23:25:07  #153142 'Vitória superfície'           +55 (140 -> 195)
2026-05-18 09:05:23  #153144 'Valsa com Esox'               +7  (195 -> 202)
2026-05-21 02:00:07  #153204 'Reunião da família Marlim!'   +35 (202 -> 237)
2026-05-21 09:03:47  #153205 'Big Headhunters'              -13 (237 -> 224)
2026-05-21 22:00:05  #153244 'Caça veloz ao Robalo'         -8  (224 -> 216)
2026-05-22 00:00:16  #153245 'Perseguindo Trutas no Falcon' -3  (216 -> 213)
2026-05-22 02:00:10  #153246 'Flutuador e Lota-do-Rio'      -3  (213 -> 210)
2026-05-22 10:17:28  #153286 'Manhas da Sorte'              -11 (210 -> 199)
2026-05-22 10:17:29  #153288 'Vermelho e brilhante'         -15 (199 -> 184)
2026-05-22 10:17:29  #153287 'Mais afiado que uma espada!'  -20 (184 -> 164)
2026-05-22 10:17:29  #153247 'Banzai de Atum!'              -20 (164 -> 144)
2026-05-22 13:14:31  #153289 'Rodeio no topo da água'       -13 (144 -> 131)
2026-05-22 14:00:04  #153290 'Lucioperca Zeek Diferenças'   -10 (131 -> 121)
2026-05-22 20:00:11  #153293 'Amigo da Árvore'              -3  (121 -> 118)
2026-05-22 22:00:04  #153294 'Origens da Carpa'             -13 (118 -> 105)
2026-05-23 00:00:03  #153295 'Minis extraordinários da Noruega!' -20 (105 -> 85)
2026-05-23 02:00:16  #153296 'Gigantes Vermelhos'           -4  (85 -> 81)
2026-05-23 09:56:20  #153325 'Ataque à Cornish Jack'        -20 (81 -> 61)
2026-05-23 09:56:20  #153326 'Caça aos Carnívoros Troféu!'  -20 (61 -> 41)
2026-05-23 09:56:20  #153297 'Três Poderosos'               +42 (41 -> 83)
2026-05-23 10:00:04  #153327 'Bass Escolar'                 -10 (83 -> 73)
2026-05-23 12:00:03  #153328 'San Joaquin sem Fronteiras!'  -11 (73 -> 62)
2026-05-23 14:00:03  #153329 'Woohoo Cavala-Wahoo!'         -20 (62 -> 42)
2026-05-24 00:00:10  #153334 'Gar lunar'                    +25 (42 -> 67)
2026-05-24 02:00:12  #153335 'Titãs Vermelhos'              +40 (67 -> 107)
2026-05-24 04:00:07  #153336 'Ameaça Sangrenta'             +47 (107 -> 154)
2026-05-24 06:00:05  #153356 'Aperto de Tenca!'             -13 (154 -> 141)
2026-05-24 12:37:29  #153357 'Os 50 da sorte'               -15 (141 -> 126)
2026-05-24 12:37:29  #153358 'Imperador do Nilo'            -20 (126 -> 106)
2026-05-24 12:37:30  #153359 'Carpas grandes e pequenas'    -11 (106 -> 95)
2026-05-24 14:00:04  #153360 'Cã Siberiano'                 -7  (95 -> 88)
2026-05-24 16:00:12  #153361 'Desafio de Bass'              +27 (88 -> 115)
2026-05-24 18:00:06  #153362 'Sem medo de tubarões!'        +55 (115 -> 170)
2026-05-24 20:00:04  #153363 'Mais afiado que uma espada!'  -20 (170 -> 150)
2026-05-24 22:00:03  #153364 'Grande encontro do Alabote!'  -20 (150 -> 130)
```

## Mongo query used

```js
// per platform connection, schema main2; UserId lowercased
db.tournamentLog.aggregate([
  { $match: { UserId: "<guid-lower>", Message: /CompetitionRating/ } },
  { $sort:  { Timestamp: 1 } },
  { $project: { _id: 0, line: { $concat: [
      { $dateToString: { date: "$Timestamp", format: "%Y-%m-%d %H:%M:%S" } }, "  ", "$Message" ] } } },
  // group+reduce into one cell to bypass the ~20-row display cap of the MCP runner
  { $group:   { _id: null, lines: { $push: "$line" } } },
  { $project: { _id: 0, all: { $reduce: {
      input: "$lines", initialValue: "", in: { $concat: [ "$$value", "\n", "$$this" ] } } } } }
]).toArray()
```
