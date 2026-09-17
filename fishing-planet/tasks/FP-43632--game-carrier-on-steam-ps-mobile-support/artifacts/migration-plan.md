# GameCarrier Migration Plan — Mobile / PlayStation / Steam

Execution plan for the production transport migration under FP-43632. Management wants this ASAP; the answer
below is a defensible schedule rather than a date. Sections are agreed one at a time.

## Facts the plan rests on

Verified against SVN, the `vegasrc` GitHub org, TeamCity build configuration, and Confluence "Environment and
branch status" (v380).

### Which branch feeds which production farm

| Production farm | Build branch  | Protocol | Transport today |
|-----------------|---------------|----------|-----------------|
| MOB PROD        | `IMV20250220` | 1122.7   | Photon          |
| NX PROD         | `IMV20250220` | 1122.8   | **GameCarrier** |
| STEAM PROD      | `MFT20260325` | 1126.0   | Photon          |
| PS PROD         | `MFT20260325` | 1126.0   | Photon          |
| XB PROD         | `MFT20260325` | 1126.0   | **GameCarrier** |

The nine config files delivered under FP-43670 (r16405, r16406) currently live in `NPN20260602`, which feeds no
production farm.

### Where the configs must end up

Two production branches consume them — IMV for Mobile, MFT for Steam and PlayStation — but the merge rule
decides the rest. Per `CLAUDE.md` → Branch Roles, merge direction is OldStable → Stable → Content → Code, each
level merging into every level above it. With current role assignments that chain is:

```
IMV20250220 (OldStable) → KNW20250723 (OldStable) → LBM20251201 (Stable) → MFT20260325 (Content) → NPN20260602 (Code)
```

Anything living in IMV must therefore exist in every branch above it. Neither KNW nor LBM currently hosts a
production server, but leaving a hole in the chain means the next upward merge from IMV carries these files as
new content into branches that should already have them. The full set goes into all five.

This is how Retail configs are already maintained — Retail itself is frozen on MI20200128, yet its configs are
kept current in modern branches.

The content sits at the top of the chain today, so it is carried down once and then walked back up, each step
merging the previous step's commit so nothing anywhere reads as unmerged:

| Step | Merge                                                       | Carries                                             |
|------|-------------------------------------------------------------|-----------------------------------------------------|
| 1    | MFT → IMV and NPN → IMV in one working copy, committed once | content; commit A                                   |
| 2    | IMV → KNW, revision A                                       | content; commit B                                   |
| 3    | KNW → LBM, revision B                                       | content; commit C                                   |
| 4    | LBM → MFT, revision C                                       | partly empty — some of it originated here; commit D |
| 5    | MFT → NPN, revision D                                       | nothing but mergeinfo; use `--record-only`          |

Each commit stacks on the previous one. Verbose, but it closes the circle: no branch shows these revisions as
outstanding afterwards. Merge by explicit revision (`-c`) at every step — a blanket merge from IMV into KNW
would drag along the rest of the accumulated difference between those branches.

### Packages are universal; existing GameCarrier builds can be reused

One TeamCity configuration — "Build and Package all Server Binaries for F2P (All platforms)" — produces the
package, and its `Server Prod F2P` VCS root is repointed between branches over time. Package `#816` was built
29 Oct 25 from IMV@15229, which is why Mobile still reports `816`; package `831` came later from MFT and serves
Steam and PlayStation. Nintendo has its own configuration with a `Server Prod Nintendo` root plus a VCS root on
the GC `artifacts` repository.

SoftwareDistributor pushes binaries from the package and picks configs by the platform declared in the
installation JSON (the "farm"). The package therefore carries no platform identity, and an existing GameCarrier
package can be reused on a different platform's nodes.

**Steam and PlayStation need no build at all.** XB PROD, STEAM PROD and PS PROD all run from MFT on protocol
1126.0, so the current Xbox GameCarrier package `27` already carries exactly the business logic those farms run
today. Deploy it, drop in `Steam.*` / `PlayStation.*` configs, and nothing changes except the transport.

**Mobile needs one rebuild.** The existing Nintendo package `16` was built with GC artifacts `05ac949405da`
from 3 Nov 2025 — a year before structured `args`, counters, lifecycle-management fixes and msquic 2.4.8. A
pilot on that package would validate a GameCarrier that differs from the one going to Steam and PlayStation,
and would run without the performance counters. Rebuilding from current IMV with the current `artifacts`
master gives Mobile a package whose business logic is what Mobile already runs, on a GameCarrier identical to
the one the other platforms will get.

### IMV has drifted very little

Five commits landed in IMV after r15232 in a year:

| Revision | Content                                                                                                  |
|----------|----------------------------------------------------------------------------------------------------------|
| r15364   | minor protocol bump 1122.8 → 1122.9 after the 2025.5.4 Maldives Nintendo release                         |
| r15395   | merge from KNW: GC-267 deployment backup on node shutdown; GameCarrier QUIC config for Nintendo          |
| r15620   | FP-30194 — disconnect when cutting line with no fish during the new year event                           |
| r16053   | FP-42164 — competition leaderboard rating replacement (stored procedure already applied to the database) |
| r16210   | FP-44460 — ReleaseTool conversion granting the Frankenfish mount (tool is built and run ad hoc)          |

Only r15620 touches game logic, and it is a bug fix. Rebuilding Mobile from current IMV HEAD is safe. Mobile
moves to protocol 1122.9 in the process, which is a logging marker rather than a compatibility barrier — the
connection gate compares only the major version, minor versions merely separate releases in the logs. The side
effect is useful: post-migration Mobile logs become distinguishable from pre-migration ones.

### Assembly binding redirects: the host supplies them

A strong-named assembly is identified by name, version, culture and public key together, so a request for
`Newtonsoft.Json 12.0.0.0` is not satisfied by 13.0.0.0 — the loader refuses. A `bindingRedirect` rewrites the
requested version before the search happens. The loader takes those redirects from the configuration file
assigned to the AppDomain, which the host names explicitly when creating the domain; a `.dll.config` sitting
beside a library is never picked up on its own.

Current `GC.Runtime` supplies them itself. `GC.Runtime/AssemblyBinding.cs` reads the `<assemblyBinding>`
section from `GC.Runtime.dll.config`, writes a generated copy of the guest config beside the original as
`*.binding.config`, and points the domain at that copy. If the guest config already carries the section, it is **cut out
and replaced** rather than merged. The injected set is broader than what was written by hand — it
covers `System.Text.Encodings.Web` in addition to the four assemblies the manual copies list.

That mechanism is recent: `photon-server-integration` commit `024f9fe7`, 8 July 2026 — the same day as r16278,
which removed the copies it made redundant. Everything built before that date has no injection, and the state
of the tree reflects the two eras rather than a free choice:

| Branch | Platform       | Redirects | Why it works                                          |
|--------|----------------|-----------|-------------------------------------------------------|
| MFT    | all platforms  | absent    | package `27` injects them                             |
| IMV    | Nintendo, XBox | present   | package `15-16` predates injection and relies on them |
| IMV    | Mobile         | absent    | no GameCarrier node yet                               |

So the redirects are not optional in general — they are optional only under a host that injects. Mobile gets a
freshly rebuilt package, so its configs need nothing added. Had the old Nintendo package been reused instead,
the mobile configs would have gone to a host without injection and with no redirects of their own, and the
applications would not have started. That is a second, independent reason the rebuild was necessary.

**Removing the redirects from IMV** (r15848, r15773, r16278 as one set — the additions and the removal cancel
out for XBox, and Nintendo's own copies, which arrived much earlier in r14276/r14278, go away) would leave the
branch clean and consistent with MFT. Nothing has to be removed from the Mobile configs: they never carried
redirects.

Rolling back to Photon is not a hazard here. Redirects were introduced *for* GameCarrier — r15848 is literally
"Add Bindings Redirects for Game Carrier" — and the Photon farms run without them today: Steam and PlayStation
build from MFT, where no platform config has a redirect. So a cleanup cannot break a Photon fallback.

The one real exposure is a Nintendo node deployed from the existing `15-16` package, whose host predates
injection. A deployment is three artefacts, not one: the same build places `pack<N>.7z` into `C:\Shared\Pub`,
configs into `C:\Shared\Cfg` and action scripts into `C:\Shared\Act`, wiping the two latter each time. Devops
back up and restore all three together, so the pairing survives a rollback as long as every part is put back —
the failure mode is restoring some without the others. `Act` deserves particular care during this migration:
r16246 changes the `*.Apply.cmd` scripts, so IMV's action set changes with our merge, and a newer script
against an older package breaks Apply rather than just deploying stale settings.

Given that, the cleanup does not belong to this migration. Do it as a separate task once the farms are on
GameCarrier and stable, or fold it into the wider rework of how binding redirects are handled — see the
`software-distributor` module backlog.

### The migration is transparent to clients

Every Game config binds both protocol families on the same node — for Mobile:

| Port | Transport | Protocol     |
|------|-----------|--------------|
| 4531 | tcp       | PHOTON       |
| 9091 | wss       | PHOTON       |
| 4551 | wss       | GAME_CARRIER |
| 4541 | quic      | GAME_CARRIER |

Existing clients keep speaking the Photon wire protocol and `photon-server-integration` serves them on the
GameCarrier host. No store release is on the critical path. Moving clients onto the GameCarrier transports is a
separate, later gain.

### Node inventory and spare capacity

Spare nodes move freely between platform installations, and devops manage that pool themselves.

| Platform    | Game nodes running | Spare (stopped)                            | Relative load |
|-------------|--------------------|--------------------------------------------|---------------|
| Mobile      | 1 — Node138        | Node73 (the stronger machine of the two)   | lowest        |
| PlayStation | 5                  | Node143, Node116, Node133, Node135, Node35 | middle        |
| Steam       | 7                  | Node99                                     | highest       |

A node leaving rotation empties by natural attrition in 8–12 hours; there is no mechanism to push players off.
So as many Photon nodes can leave rotation at once as GameCarrier nodes have been introduced, without losing
capacity — the migration proceeds in waves rather than one node at a time. Freed hardware flows forward: Mobile
releases one node, PlayStation five, and Steam — heaviest load, thinnest reserve of its own — goes last and
inherits them.

## Decisions taken

- **Mobile first** as the pilot: smallest audience, lowest revenue exposure.
- **Pipeline ordering**: Mobile → PlayStation → Steam, each starting while the previous finishes its tail.
- **Rolling waves** for Game nodes; **one scheduled downtime window per platform** for Master, Chat and Club.
- Downtime windows are booked next-day, same-day if urgent, so they do not constrain the schedule.
- **Do not modify the existing Photon build configuration.** Photon nodes still need support; add a new
  GameCarrier build and archive the old one when it is no longer needed, rather than editing and later
  reverting.

## Ownership

| Work                                                        | Owner                             |
|-------------------------------------------------------------|-----------------------------------|
| Configs, branch merges, SVN                                 | server team lead                  |
| Machine preparation, package builds, deployment, spare pool | two devops engineers              |
| GameCarrier internals — diagnosis of anomalous behaviour    | GC developer (currently on leave) |

Preparation and rollout are not blocked by the GC developer's absence. Diagnosis inside the transport layer is
possible without them but slower and more expensive, so an anomaly on the pilot costs schedule rather than
stopping work. Reusing packages that already run in production on Xbox and Nintendo makes that scenario less
likely.

## Section 1 — Preparation

**1.1. Distribute the config set along the merge chain.** The nine configs plus the GameCarrier line must exist
in all five branches: IMV, KNW, LBM, MFT, NPN. They sit in NPN today, so they travel downward.

Revisions to carry into IMV — the branch the GameCarrier line never reached:

| Revision | Content                                                                  | Origin |
|----------|--------------------------------------------------------------------------|--------|
| r16267   | structured adapter/app `args` in the Nintendo and XBox configs           | MFT    |
| r16246   | performance-counter install/uninstall added to the `*.Apply.cmd` scripts | MFT    |
| r16405   | `counters.per_second_window = 10` on the Nintendo and XBox configs       | NPN    |
| r16406   | the nine `Mobile.*` / `PlayStation.*` / `Steam.*` configs                | NPN    |

Both merges into IMV land in **one commit, not two**: in a single working copy run `svn merge -c 16246,16267`
from MFT and `svn merge -c 16405,16406` from NPN without committing in between, then commit once. The
resulting `svn:mergeinfo` holds two entries, one per source branch — normal for SVN, since the property is a
list of path-to-ranges. One commit means the chain above carries one revision per step instead of two.

The binding-redirect revisions (r15848, r15773, r16278) are deliberately **not** in this set; that cleanup is
separate work, see above.

Into MFT — r16405 and r16406. KNW and LBM take whatever they lack so the chain has no hole.

The set was derived by diffing the `SoftwareDistributor/Configs/GameCarrier` and
`SoftwareDistributor/Actions/GameCarrier` trees between IMV and MFT, not by listing revisions by eye. Earlier
GameCarrier work — r15270, r15272, r15394 — is already in IMV via r15395. Out of scope: r15560 (SQLServerProject
deployment) and r16455 (FP-46013, a test skip).

**1.2. Rebuild the Mobile package.** Run the Nintendo build configuration against current IMV with the current
`artifacts` master, producing a package with Mobile's own business logic on an up-to-date GameCarrier.

Steam and PlayStation need no rebuilt **binaries** for the migration itself — Xbox package `27` already carries
the business logic those farms run. But that package was built from MFT@r16375, before r16406 landed the nine
new configs, so its accompanying config set does not contain `Steam.*` or `PlayStation.*`. Either place the
configs into `C:\Shared\Cfg` by hand, or re-run the Xbox build after the merge so the set is regenerated. The
second is cleaner and costs one build; the first is faster and is standard devops practice.

If any fix is to ride along (see 1.5), the MFT package is rebuilt rather than reused — and because the package
carries no platform identity and Steam, PlayStation and Xbox all build from MFT, **one rebuild covers all
three**.

**1.3. Verify on MOBTEST2.** Done — the environment was set up on the yellowtest pattern, the staging build was
deployed on 7 September and QA started a shortened BVT the same day. MOBTEST stays untouched and available,
though it currently sits on a branch relevant to neither production nor the upcoming FTUE release for Mobile.

No environment-specific GameCarrier `config.json` needs to be committed to SVN for staging: AllInOne staging
nodes run on the default `config.json` shipped in the artifacts repo. This is a statement about SVN content
only — the build configuration is separate work.

**1.4. Two independent sets of performance counters, and only one of them is automatic.**

`PerfCounterManager` is our own tool (`Photon/tools/PerfCounterManager/`). It registers .NET categories for the
business logic — `"Photon Socket Server: Common"` and siblings — and r16246 wired its `-u` / `-i` calls into
the per-app `Apply.cmd`, so those install on every deployment. MFT has this already; IMV gets it with the merge
above.

`gcscnt.reg` is unrelated. It registers a native Windows V2 performance provider under
`Perflib\_V2Providers\{5cd11e68-…}`, whose counter names live in `resource.dll` next to `gcs.exe` — these are
the GameCarrier transport counters. Nothing installs it automatically: `install.bat` only runs
`gcs.exe install LoadBalancing -C config.json`. It stays a manual step in the node commissioning checklist.
Currently applied on yellowtest only. Skipping it is expected to cost the transport counters and nothing else,
but that has not been verified — and with the node count this low, applying it by hand is cheaper than finding
out.

**1.5. Fixes may ride along, and the order is the point.** The migration rebuilds both packages anyway, so a
server fix ready in time travels with it. The value is not the saved downtime — that is minor — but the
sequence: the IMV package is built a week before the MFT one, so anything landing in Mobile gets a week of
production exposure on the lowest-revenue platform, watched over a weekend, before the same code reaches Steam
and PlayStation. The defect would be the same in either place; the bill would not.

Mobile is therefore a canary twice over — the same week and the same nodes prove both the new transport and
the new business logic. That is an independent argument for having picked it as the pilot, separate from it
simply being the cheapest platform to disturb.

A fix of this shape cannot be verified on a stand. FP-46092 guards against unpredictable input from a tampered
client, and reproducing that needs a fuzzer we do not have. QA can confirm that normal fishing still works — a
regression check, not a verification of the fix. The only real proof is production, which is what makes the
IMV-then-MFT order matter: Mobile is where that proof gets collected.

This is an opportunity, not a commitment: the migration has an external date and a fix does not, so nothing
here waits for one. Missing the Mobile window is an acceptable outcome — the fix then travels with a later
cycle. What is not negotiable is the order, if it travels at all.

Two cut-offs, because the two packages are built from different branches at different times:

| Package | Platforms                | Built                                | Content must be committed by |
|---------|--------------------------|--------------------------------------|------------------------------|
| IMV     | Mobile, Nintendo         | 9 Sep                                | 9 Sep, before the build      |
| MFT     | Steam, PlayStation, Xbox | 15 Sep, before the PlayStation phase | 15 Sep, before the build     |

The order of these windows — IMV a week ahead of MFT — is deliberate and must not be swapped, however
convenient it might look for scheduling. Reversing it would put untested business logic on the revenue
platforms first and leave the canary running behind them — which does not make anything worse, it simply
throws the early warning away.

**Before each build, diff the branch against the deployed package's baseline** (`svn log` from r15229 for IMV,
from r16375 for MFT). Rebuilding is safe today precisely because those deltas are almost empty — two commits
in MFT with no runtime code, one bug fix in IMV. If more has accumulated by build time, a rebuild silently
stops being a no-op and becomes a release; that is a decision to take deliberately, not to discover afterwards.

Missing a cut-off costs one downtime window, not a schedule slip. A routine business-logic patch is
Stop → Apply → Start across the whole farm at once — roughly 45 minutes early morning, off-peak. The rolling
approach in this plan is not how patching normally works; it is required here because the migration replaces
the host itself — the server core and its settings, not just the business-logic DLLs — and because a gradual
swap keeps a retreat available. Downtime windows in the migration exist only for Master, Chat and Club, which
cannot be taken out of a farm without breaking it.

Note that the platforms outside this migration pay that window regardless: Xbox and Nintendo already run
GameCarrier, so any fix reaches them as a separate patch. Xbox is worth scheduling right after Steam — its
Win10 client is a PC target with the same exposure — but it sits outside the 1 October deadline.

Estimate: **2–3 working days.**

## Section 2 — Mobile phase (the pilot)

Starting state: branch IMV, package `816`. Node138 carries the platform on Photon; Node73 — the stronger of the
two — sits stopped.

### Step 1 — Introduce the pilot node (day 1)

Devops bring up **Node73** with the rebuilt GameCarrier package and `Mobile.Game.config.json` from IMV.
Node138 stays on Photon and the farm runs mixed — which the configs support, since every node binds both
protocol families. Master routes new players to the empty node on its own.

No rollback procedure is needed here: taking Node73 out of rotation restores today's state with no player
affected.

### Step 2 — Observation (days 1–3)

Mobile stresses the weakest part of the stack harder than Steam or PlayStation would. Mobile networks drop,
apps are backgrounded, devices sleep — so ungraceful disconnects are frequent, and ungraceful disconnects are
what leaves connections stuck in LWS, where the GC developer has a workaround rather than a fix. Piloting here
tests the riskiest surface first, at the lowest exposure.

Node138 is the Photon control. Watch:

- player count on Node73 climbing to a comparable level — clients do connect over Photon on 4531/9091
- disconnect rate no worse than the control
- `TracePeers-Game.log` — how many connections stick and whether they clear
- performance counters, CPU, memory

Gate: one full day without deviation from the control, two if a wider margin is wanted.

### Step 3 — Drain Node138 (day 4)

Node138 leaves rotation, empties over 8–12 hours, and is shut down — then either returns on GameCarrier or goes
to the spare pool, since Node73 alone carries current Mobile load comfortably.

Rollback: bring up any spare node with the Photon package.

### Step 4 — Downtime window (day 5)

A 1–2 hour window moves MobMaster and MobChat (Chat + Club) onto GameCarrier. Booked the day before. Rollback
is restoring the Photon package together with its configs and actions — all three shares, see above. The
window is sized for the rollback, not the work.

**Mobile phase: 5 working days** after preparation. Hands-on time is a few hours; the rest is observation.

## Section 3 — PlayStation

Starting state: branch MFT, five Game nodes on Photon and five in reserve. `PsMaster` holds the lobby;
`PlayStationChat` hosts both Chat and Club. The package is the MFT one — reused from Xbox or rebuilt per 1.5 —
plus `PlayStation.*` configs.

By this point the transport has two independent endorsements: Xbox has been running it in production for
months, and Mobile has just carried it through a pilot with a weekend of observation. PlayStation adds no new
unknowns of its own — the platform differences live in the configs, not in behaviour.

### Step 1 — Swap the fleet in place (day 1)

The reserve here exactly matches the working fleet, so the swap needs no intermediate state. Nodes are
introduced as they become ready, and each new GameCarrier node is paired with a Photon node leaving rotation.

Leaving rotation is not shutting down: the node stops accepting new players and keeps serving those already on
it. That pairing is what makes the test fast — all new traffic goes to GameCarrier immediately instead of
spreading across ten nodes, so the new fleet reaches realistic load within hours rather than over a day.

The retreat stays a couple of clicks away throughout. The Photon nodes are still up and still holding players;
returning them to rotation restores the previous state, and no player is moved anywhere by either direction of
the switch.

### Step 2 — Observation (day 1–2)

Because load arrives quickly, a single day covers both the ramp and a peak. Same signals as the Mobile pilot,
with the draining Photon nodes serving as a live control on the same farm — a better comparison than the pilot
had. The transport is no longer the unknown here; only its behaviour under PlayStation's traffic is.

### Step 3 — Retire the Photon nodes (day 2–3)

All five leave rotation together — capacity is already covered by their replacements — and empty over 8–12
hours. Then they shut down and return to the spare pool, where they become the hardware Steam needs.

### Step 4 — Downtime window (day 3)

One window moves `PsMaster` and `PlayStationChat` (Chat + Club) onto GameCarrier. Rollback is restoring the
Photon package with its configs and actions.

**PlayStation phase: 3–4 working days**, of which one is waiting for nodes to drain.

## Section 4 — Steam

Starting state: branch MFT, seven Game nodes on Photon and one weak virtual machine of its own in reserve.
`SteamMaster` holds the lobby; `SteamChat` hosts Chat and Club. Same MFT package, plus `Steam.*` configs —
which serve both Steam and Epic, since the two share one farm and one config.

Steam goes last for two reasons that happen to agree. It is the largest platform, so it benefits most from
everything learned on the previous two. And it owns almost no spare hardware — the machines it needs are the
ones Mobile and PlayStation release, six or seven by then, which is roughly what its seven working nodes
require.

### A single wave

Steam converts the same way as PlayStation, on a larger fleet: GameCarrier nodes enter rotation as they become
ready, each paired with a Photon node leaving it. Fourteen Game nodes up at once — seven draining, seven taking
traffic — is well within what this farm has carried; it has run twenty on weaker hardware, and database load
follows the player count, which a swap does not change. Nothing about Steam makes the mechanism riskier than it
was on the previous two platforms; it is the same swap on more machines, run last precisely so that it is the
one with the most evidence behind it.

**Possible acceleration, deliberately not in the schedule.** Machines freed on PlayStation can move to Steam as
they are released, so Steam's preparation can begin before the PlayStation Master cutover rather than after it.
That overlaps the two platforms and pulls the finish left. The cost is a messier rollback — two farms
mid-swap at once — which is why the schedule does not assume it. If PlayStation goes cleanly, this is the first
place to look for time.

### Step 1 — Swap the fleet (day 1–2)

GameCarrier nodes enter rotation paired with Photon nodes leaving it, the same mechanism as on PlayStation. The
drained nodes empty over 8–12 hours and shut down.

### Step 2 — Observation (day 2–3)

Both transports serve comparable shares of the largest live audience, with the draining Photon nodes as the
control. This is the last point at which retreat is cheap, so it is the one that should not be shortened for
schedule reasons.

### Step 3 — Downtime window (day 4)

One window moves `SteamMaster` and `SteamChat` (Chat + Club) onto GameCarrier, completing the migration.
Rollback is restoring the Photon package with its configs and actions.

**Steam phase: 3–4 working days.**

## Schedule

The team works a four-day week, Monday to Thursday; devops cover all seven days. That shapes the whole
schedule: **observation costs no team days**. Every phase is arranged so that the acting steps — introducing
nodes, draining, downtime windows — land Monday to Thursday, and the watching happens Friday to Sunday with
devops on hand to react. One platform therefore fits one calendar week.

Target: **1 October 2026**. The work finishes 30 September, leaving that Thursday as reserve.

Four milestones carry the whole story; the day-by-day table below is how they are reached. Actual dates are
filled in as they happen, so that running ahead is visible rather than something to be worked out by comparing
two documents.

| Milestone                                       | Planned | Actual |
|-------------------------------------------------|---------|--------|
| Mobile pilot node live on GameCarrier           | 9 Sep   | 10 Sep |
| Mobile fully on GameCarrier                     | 15 Sep  | 17 Sep |
| PlayStation fully on GameCarrier                | 22 Sep  |        |
| Steam fully on GameCarrier — migration complete | 30 Sep  |        |

Dates are a plan, not a per-day commitment. Several steps can finish early — a pilot that looks clean after
three days rather than five, a fleet swap that completes in a morning — and the schedule is built so that time
gained early is kept rather than absorbed. Each phase begins when the previous one is signed off, not on its
calendar date. Completed days are marked ✔ in the table below, so progress against the plan reads at a glance.

| Date       | Day     | Work                                                                                                                                                                                  |
|------------|---------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 7 Sep      | Mon     | ✔ staging build deployed to MOBTEST2; QA started                                                                                                                                     |
| **8 Sep**  | Tue     | ✔ QA continued the BVT; devops prepared Node73. The merges slipped to the 9th |
| **9 Sep**  | Wed     | ✔ branch chain merged and committed — IMV `r16519` (plus `r16520` reverting two local files swept in by mistake), KNW `r16522`, LBM `r16523`, MFT `r16524`, NPN `r16525` record-only. Still open: back up the Xbox set (package `27` + `Cfg` + `Act`) **before** building, then build the Mobile package and **introduce Node73 on GameCarrier**                                                                                                                                     |
| **10 Sep** | Thu     | ✔ Node73 introduced on GameCarrier; observation started                                                                                                                              |
| 11–13 Sep  | Fri–Sun | ✔ observation, no incidents — rotation switching exercised, and at times the whole platform ran on Node73                                                                            |
| **14 Sep** | Mon     | ✔ pilot accepted. Node138 left rotation and returned: mobile sessions are short, so a node empties within the hour                                                                    |
| **15 Sep** | Tue     | ✔ release package prepared; the Mobile window moved to the 17th                                                                                                                      |
| **16 Sep** | Wed     | ✔ Game port fixed at 4531 across the branch chain — IMV `r16547` through NPN `r16551`                                                                                                |
| **17 Sep** | Thu     | ✔ **Mobile downtime window — Mobile complete** (build `NxGC#18` from `r16547`); two GameCarrier nodes introduced on PlayStation                                                       |
| 18–20 Sep  | Fri–Sun | observation — PlayStation, devops                                                                                                                                                     |
| **21 Sep** | Mon     | five PlayStation Photon nodes leave rotation                                                                                                                                          |
| **22 Sep** | Tue     | shut down; **PlayStation downtime window**                                                                                                                                            |
| **23 Sep** | Wed     | **Steam — swap the fleet**, GameCarrier nodes paired with Photon nodes leaving rotation                                                                                               |
| **24 Sep** | Thu     | drained nodes shut down; observation                                                                                                                                                  |
| 25–27 Sep  | Fri–Sun | observation — devops                                                                                                                                                                  |
| **28 Sep** | Mon     | slack — finish any node not yet swapped                                                                                                                                               |
| **29 Sep** | Tue     | observation; preparation for the window                                                                                                                                               |
| **30 Sep** | Wed     | **Steam downtime window — migration complete**                                                                                                                                        |
| **1 Oct**  | Thu     | reserve                                                                                                                                                                               |

The order of operations on 8 September is the whole safety margin for that day: the Mobile package is built by
the Nintendo configuration from IMV, which overwrites `Cfg` and `Act` with IMV content. The MFT set that Steam,
PlayStation and Xbox deploy from exists only in those shares — back it up before building, or it has to be
recreated by a rebuild.

Introductions are deliberately placed on Wednesdays and Thursdays so that observation lands on Friday to
Sunday, when the team is off and devops are on. That is what the weekly rhythm is for.

**The detector is the end of Thursday 10 September.** The merges slipping by a day costs nothing on its own —
the pilot introduced on the 9th or the 10th is observed over the same weekend and judged on Monday the 14th
either way; only the length of observation shrinks. What matters is that the pilot reaches production before
the team's week ends. If it does not, the weekend is spent idle and the whole chain shifts by one week, to
8 October.

**The buffer is one day.** With a four-day week a troubled week slips everything by exactly one week — there is
no "we'll make up half a day" — so the reserve absorbs a bad day, not a bad week. A lost week means 8 October.

The schedule therefore carries a second detector further along: **if PlayStation is not closed by 22
September, Steam moves to 8 October.** Saying that up front turns a one-iteration slip into something
anticipated rather than a failure discovered at the end of the month.

How each platform is converted differs by what its spare capacity allows, and the reasoning sits in Sections 3
and 4 rather than here. The one thing common to all three: the day of observation is what makes a retreat
cheap, and it is the first thing that will look expendable if the schedule tightens. It is not.

## Open items

- **Staging environments still run Photon** and will need their own migration to GameCarrier.
- **Xbox and Nintendo patches** for whatever ships in these packages — both are already on GameCarrier, so they
  take a separate ~45-minute window each, outside the 1 October deadline. Xbox goes right after Steam.
- **Binding-redirect cleanup in IMV** (r15848, r15773, r16278) — deliberately out of scope here. Do it after
  the farms are migrated and stable, or as part of the wider redirect rework tracked in the FP-43632 backlog
  and the `software-distributor` module backlog.
- FP-43669 sits in To Do although the build automation is in production and already shipped an Xbox release;
  FP-43670 is in review; FP-43632 has been On Hold since May. The board contradicts what will be reported to
  management — worth tidying once dates are agreed.
