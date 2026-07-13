---
jira: FP-33074
title: 'Incident chronology - chat messages disappear'
type: artifact
sources:
  - Slack #bugs thread (Jun 2024 - Jun 2025), screenshots provided 2026-06-25
  - JIRA FP-33074 description + comments (2024-08 - 2026-06)
---

# FP-33074 - Incident chronology

Consolidated fact log for reconstructing the history. Every entry is tagged by
source: **[S]** = Slack #bugs thread, **[J]** = JIRA FP-33074. Player quotes are
kept verbatim (English / Ukrainian / Russian) for fidelity. Conclusions are
deliberately deferred - this file is raw material.

Symptom variants used as tags below:
- **(A) delivery stops** - new messages (chat + service: catches, online/offline) stop appearing for one peer; older may also vanish. Dominant variant.
- **(B) cross-room leak** - messages from a *different* room/channel appear where they should not ("delivered to the wrong channel").
- **(C) delayed burst** - delivery pauses, then the backlog suddenly floods in ("drops off, then catches up"). Possibly the same as A seen from the moment it recovers.

## Player roster

WebAdmin host per platform: `xb-webadmin` = Xbox, `steam-webadmin` = Steam,
`test.fishingplanet.com` = QA.

| First seen | Player (gamertag)                   | UserId                                   | Platform      | Club / room                   | Variant | Notes / cross-ref                                                              |
|------------|-------------------------------------|------------------------------------------|---------------|-------------------------------|---------|--------------------------------------------------------------------------------|
| 2024-06-26 | BG x DareDeviL                      | -                                        | Xbox          | (club room)                   | A       | Original report subject; friend of visser099                                   |
| 2024-06-26 | visser099 (*80)                     | -                                        | Xbox          | "H.C. De kromme toppen"       | A       | Catches show on his own screen, not for BG x DareDeviL                         |
| 2024-06-26 | Kristof Boes                        | -                                        | Xbox (FB)     | -                             | A       | FB post author; "more then a year if it isn't two years"; also Sep-12 report   |
| 2024-06-26 | Pete Whear                          | -                                        | Xbox (FB)     | -                             | A       | "happening for a long time on x box"; now fishes private room                  |
| 2024-06-26 | Recon870 (Recon/Superb Mood)        | -                                        | Xbox          | Kaiji no ri / Congo private   | A,B,C   | Detailed: "drops off" then "catches up"; also in private room; "quiet" ~15 min |
| 2024-08-19 | Justin W. Rhoades                   | -                                        | Xbox (FB)     | -                             | A       | "yall ever gonna fix the chat system on XBOX?"                                 |
| 2024-08-19 | Gary Brown                          | -                                        | Xbox (FB)     | game room                     | A       | New account; "chat does not work on Xbox... nothing filtered off"              |
| 2024-08-19 | Simon Maitland                      | -                                        | Xbox (FB)     | -                             | A       | "Chat constantly fails on xbox. Just sometimes you get lucky"                  |
| 2024-10-23 | **Gonzo1964 (*79)**                 | **38aeb767-64db-4a52-ab7b-bc25fdecbfe8** | Xbox          | "Reelin' in the Years" (2024) | A       | **CROSS-REF: same account is club-6777 president in the 2026 report**          |
| 2024-11-22 | Sunshine0369564                     | 20384df7-c1d5-4570-ac65-8fb3d377a545     | Xbox          | -                             | A       | "happens every time after the Thanksgiving update"                             |
| 2024-11-22 | (gamertag in image)                 | 81658bbf-695f-4e40-a5af-e16b072b395c     | Xbox          | -                             | A       | "can't see what I catch or what others catch"                                  |
| 2025-01-08 | GarHunter17                         | 5ca4833d-4655-4e43-8773-815c3af59f0d     | Xbox Series S | -                             | A       | Issue date 2024-12-19; "can't see chat log at all"                             |
| 2025-01-08 | FPOLGA                              | -                                        | Xbox          | Congo -> base -> Selenge      | B       | Messages from different rooms accumulated; see Surin/Kurylovych investigation  |
| 2025-01-08 | KingShaen (*79)                     | -                                        | Xbox          | "Flipping Boostbobo" (Congo)  | B       | His Unique Nile Perch (168.33kg) catch leaked into a Mongolia room             |
| 2025-01-08 | PingKai7670 (*47), Cankcwgsfd (*47) | -                                        | Xbox          | XBOXCHANNEL                   | B       | join/left lines leaked into another room's chat                                |
| 2025-01-09 | kogs1 (*79)                         | -                                        | Xbox          | Dnipro                        | B       | "caught Trophy Nile Perch" + "joined" leaked cross-room                        |
| 2025-03-31 | R0yalm0nk3y (carlos valdez)         | 30e6c754-b79f-49cb-8712-ba624217dbb6     | Xbox          | rooms + friends               | A       | [J only] "chat does not work at all"                                           |
| 2025-05-13 | PiotruIRybki (*27) reporter         | 4f5cac4b-8042-4499-b7fd-c36bc01938db     | Xbox (PL)     | "No kiLL"                     | A       | Sees only own messages in global; no others' catch messages; video provided    |
| 2025-05-15 | (reopen host)                       | 5de9ddb7-eced-4224-a9db-8f829ab60983     | Steam QA      | same club, FT                 | A       | [J only] Reopen repro; host messages do not appear, guest's do                 |
| 2025-06-28 | RodL2025 (*90)                      | 9295144d-e5ff-48a5-a732-45c7a09f5414     | Xbox          | -                             | A       | "messages don't arrive in chat"; video (English UI)                            |
| 2026-06-25 | **Waz 10000**                       | **a0fe2188-4eb0-46f3-94e0-1e96a1afa45b** | Xbox / UWP    | **club 6777**                 | A       | Current report; club chat only (local/global work); logout/login fixes         |
| 2026-06-25 | RareSKEETLEZ                        | 2b175d0f-24b5-4df2-96f6-1fbdcdc1c43c     | Xbox / UWP    | club 6777                     | A       | Current report (clubmate)                                                      |
| (orig STR) | test player 1                       | 80dedbc9-86e4-4d76-ad16-a3d3208af476     | Steam (prod)  | FT session                    | A       | [J] Original 2024-08 STR test account                                          |
| (orig STR) | test player 2                       | 65cc96ef-1b16-4d0c-a0aa-4d2cb44527c9     | Steam (prod)  | FT session                    | A       | [J] Original 2024-08 STR test account                                          |

## Chronology

### 2024-06-26 - thread opened [S]
- **10:06 Viktoriya Shulyak** opens the thread: "BGxdaredevil, Xbox". Player quote (FB): *"It is said before, but it is very annoying that after a while fishing you don't see your own or others fish anymore in the chat. I truly hope they are working on this problem."* Another player confirmed in the comments the problem is long-standing. Screenshot: a friend just caught and is holding a fish, but it did not show in chat.
- **10:14 Ivan Malyshev** (initial misread): treats it as normal history-depth trimming - *"Повідомлення через певний час пропадають. І це нормально... Так завжди було і ми не працюємо над тим щоб це полагодити. Бо нема що лагодити."*
- **10:15 Viktoriya** pushes back: after fishing a while, messages about fish caught by them or friends stop showing; not the first report; screenshot is proof of intended reading.
- **10:17 Viktoriya** posts the FB source (original post = Kristof Boes). FB sub-thread: **Pete Whear** "This isn't a new thing it's been happening for a long time on x box"; **Kristof Boes** (author) "more then a year if it isn't two years"; **Pete Whear** "seemed to get better for a while but... most of the time now so most times I just fish in a private room but it's not the same".
- **10:27 Viktoriya** posts gamertag screenshot (BG x DareDeviL, visser099). **Dan Shapovalov**: support also has this report, awaiting player video.
- **10:28 Olga Sova**: *"обовязкове все глянемо на проді. В 4 патч все піде, якщо бага підтвердиться."*
- **10:29 Ivan Malyshev** (corrected): clarifies after talking to the player - both in same room, visser099 just caught & holds a fish, but **BG X DareDeviL does not see it in club chat**. *"'after a while fishing' означає, що на початку гравці бачать повідомлення... але через певний час перестають їх бачити. Це не про аутдейт старих повідомлень, а про те, що перестають з'являтися нові."* Asks QA to file the bug. (@qa)
- **10:57 Viktoriya** - input from **Recon870**: *"club room chat would drop off after a little bit in the room. And usually it would suddenly 'catch up'... the fish caught and the comments anyone wrote will start running through the chat box, kinda like someone is scrolling through everything."* (variant C)
- **11:07 Viktoriya** - more from Recon870 (window 22:00-23:00 his time = 02:00-03:00 UTC 2024-06-26): *"it isn't only in a club room... the list of what fish you caught doesn't show up and then comes back later happens even in a private room... I went to a private room in the Congo... between 2230 and 2300 hours it stopped showing what I caught... it suddenly the list popped up listing my previous 5 or 6 fish... it's usually 'quiet'... and lasts for 15 mins or so."* (A + C, also in private room - not club-only)

### 2024-08-19 - bug filed [S]/[J]
- **09:00 Viktoriya** [S]: players still complaining on Xbox, "вже декілька років таке", ~couple times/week; FB quotes (Justin W. Rhoades "yall ever gonna fix the chat system on XBOX?"; Gary Brown post + FP admin reply "this issue was reported before, our developers are working on it"; Simon Maitland "Chat constantly fails on xbox").
- **16:25 Olga Sova** [S]: creates **FP-33074** (To Do, Bug, assignee sergii.chop, Medium).
- **18:21 [J] issue created** (reporter Olga Sova). Original STR: Steam 5.0.9 (43849), server prod (13048). Two friends -> FT session -> fish -> move between buoys -> host winds time forward by a day several times -> minimize -> device sleep/off -> on return chat broke. ACT: after sleep mode old service messages sometimes missing and new ones (caught fish) stop appearing. Reproduced once, specifically after laptop sleep. Test players (Steam): 80dedbc9..., 65cc96ef.... Viktoriya 19.08: *"Гравці в одній кімнаті і visser099 щойно впіймав... а BG X DareDeviL не бачить."*

### 2024-09-12 - break/pause repro [S]/[J]
- [S] 11:59 Viktoriya + [J] comment 75246 (Viktoriya): **Kristof Boes** FB - *"if I take a small break or go to the pause menu for a little while that afterwards I don't see my or my friends fish anymore in the room chat. I know it is a common problem on Xbox."*

### 2024-10-23 - Gonzo1964 [S]/[J]
- [S] 09:43 **Anna Stepanenko** + [J] comment 76876 (Olga Sova): player **Gonzo1964** `38aeb767-...`, Xbox. No messages anywhere (global or room). Reinstalled / cleared cache / changed rooms - nothing. *"I am not receiving any chat room messages anywhere, other than Custom Competition messages, and my messages about my own catches."* Screenshot shows club "Reelin' in the Years", "Gonzo1964 *79 caught garfish".
- [S] 09:45 Olga: "беремо в тест зараз".

### 2024-10-24 - first QA repro notes [J]
- comment 76929 (sergii.chop): reproduced once (FT, fishing, buoys, host winds time, minimize, sleep/off -> chat broke; restart fixes). Host lobby full of service messages; guest only had host's early message.
- comment 76930 (sergii.chop): the Gonzo report is **not** FT-related (player on Congo). Similar issue previously seen on mobile test servers after disconnect/sleep; mobile prod currently fine.

### 2024-11-22 - two more Xbox reports [S]
- 13:00 **Dan Shapovalov**: `20384df7-...` (Sunshine0369564), Xbox. *"те, що я спіймав, або те, що спіймали інші... не з'являється в кутку чату, і коли хтось говорить в глобальному... я не можу відповісти... це відбувається щоразу після виходу оновлення до Дня Подяки."*
- 14:27 **Dan Shapovalov**: `81658bbf-...`, Xbox. *"чому я не бачу, що ловлю в чаті, або що ловлять інші... я люблю цю гру через спільноту, і відчуваю, що втратив її через те, що не можу спілкуватися через чат."*

### 2025-01-08 - escalation + cross-room leak [S]/[J]
- [S] 07:46 **Dan Shapovalov**: `5ca4833d-...` (GarHunter17), Xbox Series S, issue 2024-12-19. *"Я взагалі не бачу журнал чату... перепробував усі налаштування, видаляв і перевстановлював гру, але це все одно не допомогло."*
- [S] 08:51 Olga: bug is in To Do, will be scheduled into a release.
- [S] 12:39 Viktoriya -> @Stan Samoilov.
- [S] 13:41 **Stan Samoilov**: *"Основное здесь то, что **новые сообщения перестают приходить**."*
- [S] 16:16 **Oleksandr Surin** (variant B): on Mongolia (Xbox prod) sees a chat line that **KingShaen** caught a Unique Nile Perch - but Nile perch don't live on Mongolia and that player isn't in the room. Screenshot shows `[XBOXCHANNEL] ... joined / left` lines and "[Flipping Boostbobo] KingShaen *79 caught 168.33 Unique Nile Perch".
- [S] 18:13 **Stan Samoilov**: *"очень странно. Как будто **чат сервер доставил сообщение не в тот канал**."*
- [S] 18:32 **Oleksandr Surin**: *"То може й інші меседжи доставляються в якийсь не той канал, то гравці їх і не бачать?"* (links variant B to variant A as one root)
- [J] comment 79701 (Viktoriya): Slack discussion link.

### 2025-01-09 [S]
- 14:05 **Oleksandr Surin**: Dnipro screenshot - "kogs1 *79 caught ... Trophy Nile Perch" + "joined" leaked cross-room (variant B).

### 2025-01-21 - FPOLGA cross-room investigation [J]
- comment 80187 (Dmytro Kurylovych) - reconstructs FPOLGA's event sequence: Congo room (KingShaen catch) -> base room -> Selenge room; chat accumulated messages from different rooms. (matches Surin's Slack findings)

### 2025-01-22 - client STR + server instrumentation [J]
- comment 80245 (Dmytro Kurylovych) - **client-side STR where subscription breaks**:
  - On game entry: Join to club channel "club12345" (if in a club); if not in a club, default Join to global "g3"; Join to global only happens when opening chat.
  - **Pond -> Globe travel: Leave called twice** (club + global), then Join.
  - Create UGC and enter lobby: Join to "ugc12345".
  - **UGC delete: no Leave** from the UGC channel (also: create+start UGC without entering -> no Leave).
  - **Create FT -> enter -> finish FT: room changes but no Join to club/global channel** (root of the original FT report).
- comment 80253 (Dmytro): **HFH r13569** - log join/leave/expire into SYS log; leave channels on reconnect; PhotonTool channel debugging. **HFH r13571** - PhotonTool online-players cache debug. PhotonTool commands documented (`ctx.Channels.*`, `ctx.OnlinePlayers.ToArray()`, room `DebugChatMessages`).

### 2025-01-24 [J]
- comment 80328: **HFH r13577** - Game.CustomEventCache debug. **HFH r13578** - remove peers in PreviewDisconnect on Master.

### 2025-02-19 [J]
- Description appended: new Steam complaints - clubmate online status no longer shown reliably (suspected after the Steam fix of 2025-01-23).
- comment 81194: **HFH r13726** - add info command to PhotonTool.

### 2025-03-31 [J]
- comment 83034 (Dmytro): **R0yalm0nk3y / carlos valdez** `30e6c754-...`, Xbox - chat doesn't work at all; catch info not always shown. Plan: when XBOX is released, interact with this player with per-player logging on.

### 2025-04-07 [J]
- comment 83293 (Anna Vorona): @Sergii Karchavets - review the STR, give assessment / fix.

### 2025-04-14 - client fix landed [J]
- comment 83579 (Sergii Karchavets): **client r46484** - UGC delete -> Leave fixed.
- comment 83605 (Sergii Karchavets): **client r46485** - **club-chat fixed**.
- comment 83607 (Dmytro): verified - after FT finish club chat works; after UGC delete player leaves the UGC channel.

### 2025-05-13 [S]
- 13:31 **Mariana Kachurovska**: `4f5cac4b-...`, Xbox (Polish UI). *"Гравець бачить лише свої повідомлення в глобальному чаті, хоча з ним в кімнаті є інші гравці, і нема повідомлення про їхні вилови."* Video: club "No kiLL", PiotruIRybki.
- 19:59 Mariana: problem video (IMG_3406.mp4).

### 2025-05-14 [S]
- 11:54 Olga: *"бага пофіксена, залетить з релізом."*

### 2025-05-15 - REOPENED [J]
- comment 85018 (sergii.chop): **Reopened**. Steam 5.0.13 (**47184** - includes the r46485 club-chat fix), server qa (14152). STR: both players in same club -> both in FT -> guest device sleep 3+ min -> return -> host re-invites guest -> host writes in club chat. **Host's messages do not appear; guest's do.** After FT/UGC finish, works. Host log: `5de9ddb7-...`.
  - NOTE: this repro is on a **Steam** build that already contains r46485, so the April fix is **incomplete** independent of the Xbox-no-release issue below.

### 2025-06-05 [J]
- comment 86250 (Dmytro): log analysis - **no Leave from the club channel in the host's SYS log** (so he should still be subscribed and receiving, yet isn't). Host successfully invited guest; messages flow to/from host. Need to reproduce live and inspect chat server via PhotonTool + client logs.

### 2025-06-28 [S]
- 09:45 **Anna Stepanenko**: `9295144d-...` (RodL2025), Xbox. *"знову прийшов гравець з Хбокса у якого не приходять повідомлення в чатік"*; video (English UI).

### 2025-06-30 [S] - KEY
- 13:25 **Anna Sydorchuk**: *"в нас ще не було релізу на хб, тому бага досі на проді."*
  - The April-2025 client fix (r46485) reached **Steam** but there was **no Xbox release**, so on Xbox the bug persisted unchanged through 2025-2026.

### 2026-06-25 [J]/[S] - current incident (reopen)
- comment 126312 (Stanislav Samoilov): **Waz 10000** `a0fe2188-...`, Xbox/UWP, **club 6777**. Club chat only (local private + global work). STR (player's words): chats appeared in real time 8-9 PM yesterday; next morning while fishing, "morning" greeting failed to appear; pressing enter cleared the box but the message did not post; logout/login restored. President **Gonzo1964** `38aeb767-...` has the same symptom -> **same account as the 2024-10-23 report**.

## Client release timeline (revisions)

Source: Confluence "Releases 2025" (page 4488331269) and "Releases 2026" (page
5259296769). Client SVN revisions are **cross-platform / sequential** (one trunk;
a build cut at revision N includes every client fix committed at <= N regardless
of platform). The chat fix landed in client SVN on **2025-04-14**: `r46484`
(UGC delete -> Leave) + `r46485` (club-chat fixed).

XBOX/UWP client builds and their source revisions:

| Release date   | Platforms              | Client rev | Version                    | Includes r46485?                               |
|----------------|------------------------|------------|----------------------------|------------------------------------------------|
| 2025-01-28     | PS4, XBOX/UWP          | (n/a)      | -                          | **NO** (pre-fix)                               |
| **2025-08-19** | XBOX/UWP               | **r48781** | XB 2.9.2                   | **YES** (first patched Xbox build)             |
| 2025-08-20     | XBOX/UWP (hotfix)      | (n/a)      | -                          | YES                                            |
| 2025-09-11     | XBOX/UWP/PS4 (crashes) | (n/a)      | -                          | YES                                            |
| 2026-02-26     | XBOX/UWP               | r52351     | XB 2.9.8                   | YES                                            |
| 2026-03-19     | XBOX/UWP               | r52709     | XB 2.9.9 / UWP 2.9.13      | YES                                            |
| 2026-03-24     | PS/XB/UWP              | r52770     | XB 2.9.10                  | YES                                            |
| **2026-05-07** | XB                     | **r53869** | XB 2.9.11 / **UWP 2.9.15** | YES (latest at time of 2026 report; SRV/16069) |

- The Jan-2025 Xbox build (last before the gap) predates the fix; the next Xbox
  build was 2025-08-19 (r48781). This is the window Anna Sydorchuk described on
  2025-06-30 ("no Xbox release yet, bug still on prod") - it holds for 2025 only.
- The Steam reopen (2025-05-15) ran on Steam 5.0.13 / build 47184 (QA, r > 46485)
  - fix present, still reproduced.
- **At the 2026-06-25 club-6777 report the Xbox/UWP client is r53869 (UWP 2.9.15)
  - fully patched.** "Xbox lacks the fix" cannot explain the 2026 recurrence.

## Forensic tools available

- **Admin `/Stats/Errors`** - records protocol version *and* client version per
  error; clients emit errors densely, so a given client release can be timed
  almost to the second. Introduced ~2025. Use to (a) confirm the exact client
  build a specific player (e.g. Waz 10000 `a0fe2188-...`) was running at the
  incident moment, (b) cross-check release timing independently of the Releases
  pages.
- **PhotonTool** (chat server): `ctx.Channels.GetChannelNames()`,
  `ctx.Channels.ToArray()` (members, messages, expiration), `ctx.OnlinePlayers.ToArray()`,
  `ctx.GetRoomByName("...").last.DebugChatMessages`. Added/extended in HFH
  r13569/r13571/r13577/r13726 specifically to diagnose this bug live.

## Cross-references / intersections (facts)

- **Gonzo1964 `38aeb767-...`** appears in two reports ~20 months apart: 2024-10-23 (club "Reelin' in the Years") and 2026-06-25 (club 6777, as president). Same Xbox account.
- **Xbox never shipped the fix**: the April-2025 client fix (r46485) was validated and went to Steam; the 2025-05-15 reopen was tested on Steam 47184. Anna Sydorchuk confirms (2025-06-30) Xbox had no release -> all 2025-2026 Xbox reports are on un-fixed client code. The current 2026 incident is Xbox/UWP.
- **The fix is incomplete even with the client patch**: the 2025-05-15 reopen reproduced on a Steam build (47184) that already contained r46485 - host stops receiving after guest sleep/reconnect; SYS log shows no Leave from the club channel for the host (membership intact, delivery fails).
- **Two symptom families share a root** per the team's own reading (Stan + Surin, 2025-01-08): (A) a peer stops receiving = delivered to nowhere / stale peer; (B) cross-room leak = delivered to the wrong channel / stale subscription not torn down. Both point at channel-membership / peer desync around disconnect, reconnect, room change, FT finish, and travel.
- **Not club-only and not FT-only**: Recon870 saw it in a private room (Congo); the Gonzo 2024 report was on Congo (not FT). FT + sleep/reconnect is the most reliable repro, but the failure surface is broader.

## Open questions for fact reconstruction

**Resolved:**
- ~~Does the 2026 Xbox/UWP client predate r46484/r46485?~~ **No** - 2026 Xbox/UWP is r53869 (UWP 2.9.15), fully patched. The 2026 recurrence is not a missing-fix issue.
- ~~Is the residual Steam repro the same defect as the Xbox reports, or distinct?~~ **Same residual defect** - both reproduce on patched, post-r46485 clients (Steam 47184 in 2025-05; Xbox r53869 in 2026-06). Client code is shared and revisions are cross-platform, so it is one defect surfacing on every platform once the early "Xbox had no release" gap (2025) is excluded.

**Open (next - requires code investigation):**
- For the 2025-06-05 finding (host has NO Leave from the club channel in SYS log, yet receives nothing), which is the actual failure?
  - (a) **Missing re-Join** - client never re-Joins the club channel after reconnect / FT-finish (matches client STR 80245); "no Leave" is then trivially true because the shown membership is the stale pre-disconnect entry.
  - (b) **Stale peer in a live membership** - host is listed, but the channel holds a dead peer reference, so broadcasts write to a closed connection. r13569 (leave channels on reconnect) / r13578 (remove peers in PreviewDisconnect on **Master**) were meant to evict it - but channels live on the **Chat** server, so a Master-side eviction may not clear the Chat-side reference.
  - (c) **Live membership + live peer, fan-out skips him / client drops the event** - membership and peer correct, but the broadcast loop excludes him or the client fails to render.
  - To distinguish: read the Chat-server Join/Leave/reconnect/PreviewDisconnect handlers + the channel broadcast loop, and on a live repro inspect `ctx.Channels.ToArray()` (is the host listed? is his peer the live one?).
- Why did r13569 / r13578 not cover the residual case? Depends on the branch above: if (a) they are irrelevant (they address Leave/peer-removal, not a missing Join); if (b) they target the wrong server (Master vs Chat) or the wrong lifecycle hook.
