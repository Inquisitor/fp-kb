---
module: tournaments
---

# Tournament content calendar

> How the tournament game designer actually lays out a year. Not derivable from code or schema:
> nothing enforces any of it. It bounds how likely a scheduling edge case is to ever be reached.

## Annual shape

One sport tournament serie per calendar month, carrying a stable name year to year — Winter Pike
Tour in January, Christmas Giant's Tour in December, Gars & Glory Cup in October, and so on.

Each serie runs Welcome Start -> Registration -> three Qualifiers -> Semi Final -> Final, spread
over one to two weeks and always inside a single calendar month. Holiday periods between series
are filled with Events, which are a separate content type and not serie stages.

## The year boundary is deliberately kept clear

Across the 2024, 2025 and 2026 calendars the designer closes the December serie before Christmas
and opens the January serie after the New Year holidays:

| Year | Christmas Giant's Tour final | Winter Pike Tour registration |
|------|------------------------------|-------------------------------|
| 2024 | 21-22 December               | 15 January                    |
| 2025 | 20-21 December               | 13 January                    |
| 2026 | 19-20 December               | 12 January                    |

The roughly three-week gap brackets Christmas and New Year, and carries Events instead of stages.

**Engineering consequence:** no serie spans the year edge, so scheduling code that resolves stage
order within one calendar year is not reached by real content. This bounds severity — it does not
make such code correct. Nothing in the schema or the admin UI prevents authoring a year-edge serie;
see [backlog](backlog.md).

## Two kinds of competitive activity, two generators

The `TournamentKinds` split is a content distinction first:

- **Sport (`KindId = 1`) — tournaments.** Major events, one serie a month, multi-stage
  (Qualifiers -> Semi Final -> Final). 87 templates, 60 active, every one of them `ScheduleType = "Y"`.
- **Competition (`KindId = 3`) — competitions.** Small and constant: a continuous chain of two-hour
  slots, twelve a day. 132 templates, 103 active. **They have no stages and are not expected to get
  any** — they never carry a `SerieId`.

Each kind has its own generator, and they do not share the schedule-expansion code:

| Job                        | Time  | Calls                    | Uses `GenerateStartDays`? |
|----------------------------|-------|--------------------------|---------------------------|
| `TournamentSchedulingJob`  | 00:01 | `ScheduleTournements`    | yes — Sport templates     |
| `CompetitionSchedulingJob` | 00:02 | `RandomizeCompetitions`  | **no**                    |

`RandomizeCompetitions` walks a continuous two-hour-slot timeline from the last scheduled end date
over a 14-day horizon, picking a random allowed template per slot and skipping the Wednesday 04:00
farm-reboot slot. It ignores the template's own `ScheduleType` and `StartHour` entirely — which is
why all 103 active competition templates carry the same placeholder `StartHour = 12` and a two-hour
slot length.

## Which `GenerateStartDays` branches are actually reached

| Branch        | Reached by                                                        | Templates |
|---------------|-------------------------------------------------------------------|-----------|
| `"Y"` yearly  | `ScheduleTournements`, nightly — **the only automatic path**       | 87        |
| `"D"` daily   | `ScheduleCompetitions` only, which hangs off one manual WebAdmin button ("Regenerate Competitions **Scheduled**") | 132 |
| `"W"` weekly  | nothing                                                           | 0         |
| `"M"` monthly | nothing                                                           | 0         |

The other two competition buttons and the nightly job all take the random path, so `"D"` is a manual
alternative mode rather than the live one. User-generated templates (`KindId = 4`) carry a blank or
`"-"` schedule type, fall through the switch, and are not scheduled by this path at all.

Weekly and monthly tournaments are not planned, so those two branches are dead code in practice.
Defects confined to them are latent by content design, not by accident — but they remain live code
that a template edit could reach, since nothing validates `ScheduleType` against this list.

Competitions never belong to a serie, so serie-stage ordering only ever sees `"Y"` stages.

## Operational controls

Two human controls sit around the content, and they are what bounds the severity of scheduling
defects that clean data currently avoids:

- Every yearly template is re-validated once a year, when the designer lays out the next calendar.
- A dedicated game designer watches generation, so a serie that fails to appear is noticed rather
  than discovered months later.

Neither is enforced by code. Note for anyone relying on the second one: a template that throws
during generation aborts only the *remainder* of that night's run, so the visible symptom is "some
tournaments are missing", not "generation stopped" — a partial failure is harder to spot than a
total one. See [backlog](backlog.md).

## Provenance

Source: the tournament designer's annual calendars for 2024, 2025 and 2026, supplied 2026-09-10.
Cross-checked against `TournamentTemplates` on a dev copy of `Main`: the 2026 calendar matches the
stored templates to the day (December stages 15-17 and 19-20; January stages 13-15 and 17-18), so
the stored content is that calendar.

Recorded during the FP-46040 review — see
[review](../../../review/FP-46040--tournament-qualifier-start-order/review.md).
