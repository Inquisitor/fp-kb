# F2P vs Retail legal/rules documents - substantive diff

Scope: English versions only, body text compared with HTML stripped. Products share one webroot at
`D:\FishingPlanet\website\web-2026-07-07-clean\`.

- **F2P "Fishing Planet"** - folders without `r` suffix: `console/`, `pc/`, `xbox/`, `mobile/`, `nintendo/`, plus root `GameRules.htm`, `GameRulesPC.htm`, `TournamentRules.htm`.
- **Retail "The Fisherman - Fishing Planet"** - folders with `r` suffix: `consoler/`, `pcr/`, `xboxr/`, plus root `GameRulesr.htm`, `TournamentRulesr.htm`. Retail localized docs live under `consoler/lang/<LOCALE>/` (EN used here); `consoler/eula` == `consoler/lang/EN/eula`, etc.

Constants that do **not** differ between products (checked, so a lawyer does not have to):
- **Legal entity + address are identical**: both products are published by `Fishing Planet LLC, 130 Oceana DR W, Apt 1D, Brooklyn, NY 11235, USA`. Retail did **not** introduce a separate publisher entity.
- **Governing law identical**: State of New York, USA (binding arbitration / class-action waiver) in every EULA and TOS.
- **No "exclusive waterbodies", "DLC", "physical disc / boxed copy", or "retail version" clauses exist in any legal doc** for either product. The economy language is entirely virtual-goods / Premium-Shop based.
- Support-email normalization (`support@fishingplanet.com`) and the known `<title>` bug on `consoler/eula` & `xboxr/eula` are excluded per task scope.

---

## 1. EULA

Files: F2P `xbox/eula/`, `console/eula/`, `pc/eula/` (all three byte-identical in body). Retail `consoler/eula/` (= `consoler/lang/EN/eula/`) and `xboxr/eula/`.

**The Retail EULA is a different, older revision of the agreement - not merely a re-branding of the F2P EULA.** The F2P EULA is a newer 16-section version; the Retail EULA is the prior generation with a smaller feature set.

Substantive differences (Retail relative to F2P):

- **Minimum age is higher/stale in Retail.** Retail Game-Rules 1.01: *"players must be thirteen (13) years of age or older, and are allowed only one account registered per server."* F2P: *"players must be three (3) years of age or older... players from AppStore must be thirteen (13)... to use Sign with Apple."* Retail lacks the Apple-sign-in carve-out entirely.
- **Terminology drift: Retail says "clans", F2P says "clubs".** Retail Game Rules use "clan / clan leaders / clan treasury / Clan logos" throughout; F2P uses "club". Retail also uses legacy PvP terms *"battle chat", "battle results", "within the battle"* that F2P dropped.
- **Retail omits the club-conduct clauses F2P added.** F2P Game-Rules 1.07-1.11 (prohibition of advertising/bullying, exploitation/cheating, twink accounts, group-level consequences, club-president ban) and 2.23 (penalties clause) are **absent** in Retail.
- **Retail omits EULA sect. 6.3** (the F2P clause disclaiming liability for engine/graphics upgrades making the game incompatible with low-end/legacy hardware).
- **PlayStation generation is stale.** Retail EULA references only **PS4** ("PlayStation4 system"). F2P EULA references **PS4 and PS5**. (PS5 appears only in the F2P EULA family across the entire webroot.)
- **`xboxr/eula` is inconsistently branded.** It keeps the **F2P brand string "Fishing Planet"** (not "The Fisherman - Fishing Planet") while being Xbox-only (Sony/Apple/Google references stripped). `consoler/eula` is retail-branded and keeps PS4/Apple/Google. So the two retail EULA files disagree on branding.
- **Old currency/economy wording.** Retail Game-Rules 2.14 prohibits *"selling of gold, credits"*; anti-bot 5.02 lists rollback of *"tackle, achievements, funds (credits) and premium goods, premium consumables, and gold"* (typo "golg"). F2P generalized this language.
- **Old contact channel.** Retail routes reports to `http://www.fishingplanet.com/support`; F2P routes to the support email and in-game reporting channels. Retail official-language clause 7.01 still hard-codes *"English, Spanish, and Portuguese"*; F2P says "any of our supported languages."

Governing law, entity, arbitration/class-action waiver, epilepsy warning, survival clause list: identical wording (modulo brand string).

---

## 2. Terms of Service

Files: F2P `console/tos/`, `xbox/tos/` (identical body). Retail `consoler/tos/` (= `consoler/lang/EN/tos/`) and `xboxr/tos/`.

The Retail TOS is again an **older revision**; both point to the same `Fishing Planet LLC` entity/address and New-York governing law.

Substantive differences (Retail relative to F2P):

- **Minimum age is higher/stale in Retail: 13 vs 3.** Retail 2.1/2.2/6.1(a): *"You must be at least 13 years of age."* F2P: *"You must be at least 3 years of age."* Same delta as the EULA. F2P 2.1 also adds *"In EULA we have parent supervision advice for minors."* which Retail lacks.
- **Retail names specific SKUs; F2P is generic.** Retail 1.1 scopes to *"Fishing Planet LLC... for Xbox games and PlayStation4 games"* and 1.1(b) lists *"The Fisherman - Fishing Planet on Xbox One, ... on PlayStation4, ... Fishign Planet"* (sic - two typos). F2P 1.1 is platform-agnostic.
- **Retail retains legacy account-setup clauses (5.4-5.5) F2P removed.** Retail 5.4 references **Xbox 360**, "PSN Online ID", "Sony Entertainment Network account"; 5.5 covers "demo account" / jailbreak progress-loss. F2P collapses this to a single 5.4 ("you need to have an account on the PC platform you play") - so F2P section numbering runs 5.3-5.8 vs Retail 5.3-5.9.
- **Retail TOS *has* a Premium-Shop "Gifts" clause (8.6 a-g) that the F2P console/xbox TOS omits.** It governs cross-region gifting restrictions, 30-day accept window, and **gold compensation for duplicate vehicles**: *"gifts are only available in The Fisherman - Fishing Planet Shop"*, *"gifts... cannot be made to players on the EU server"*, *"that vehicle's full cost in gold... will be automatically compensated."* This is the one place Retail is *more* detailed - the clause appears to originate from the PC-platform TOS and was never stripped from Retail (nor added to the F2P console/xbox TOS).
- **Retail PlayStation generation stale: PS4 only, no PS5.**
- **`xboxr/tos` divergence.** Xbox-only (Sony/Apple/Google stripped from 1.1, 6.4, external-platform clause); removes the 5.4/5.5 legacy account block; forum URL is `/xbox/forum/` vs `/console/forum/`; and 12.3 contains a **broken support URL** `https://na.Fishing Planet LLC..net/support/` (template variable never substituted).
- **Minor:** Retail uses British spelling ("authorised", "unauthorised", "defence"); F2P American. Retail "clan members and clan leader" vs F2P "club members and club leaders" (5.6/5.5).

---

## 3. Privacy Policy

Files: F2P `xbox/privacy/`, `console/privacy/`, `pc/privacy/`. Retail `consoler/privacy/` (= `consoler/lang/EN/`), `xboxr/privacy/`, `pcr/privacy/`.

**This is the most materially stale document.**

- **Effective date gap of 5+ years.** F2P: **"Effective August 30, 2023."** Retail (all variants): **"Effective May 25, 2018"** - i.e. the original GDPR-enforcement-day policy, never revised. Same `Fishing Planet LLC` controller entity/address in both.
- **Weaker children's-data clause in Retail.** Retail: *"We will not knowingly collect Personal Data from any child... without parental consent."* F2P expanded this to COPPA-style language: *"We do not knowingly collect, use or share information from children without verifiable parental consent..."* and **adds parent/guardian rights to review, modify, delete, or withdraw consent** - absent in Retail. (Both define "child" as under 18.)
- **Stale third-party / social references in Retail.** Retail lists *"YouTube, vk.com, Facebook, Instagram and Twitter"* - note **vk.com** (Russian network, now reputationally/legally problematic). F2P dropped vk.com and reads *"YouTube, Facebook, Instagram, Discord, Twitter and other public online resources"* (adds Discord).
- **Stale device-fingerprint list.** Retail collects PC-era fields *"Computer name, Bios version, DirectX version, Video Adapter model, Monitor model and resolution."* F2P modernized to *"OS name, CPU model, Graphic API version, Video RAM size, Video output resolution and quality settings."* Retail also says data is stored on *"your computer's hard drive"*; F2P says *"your device."*
- **Platform-linking sentence differs.** Retail adds *"We also use your identifiers on other platforms like Steam and PlayStation4"* (xboxr: "Steam and Xbox Live"); F2P xbox omits this sentence. Retail scope reads "online and console games"; F2P reads "online PC and mobile games."
- **Policy self-URL** points at the retail path (`/consoler/privacy/`, `/console/privacy/` in pcr, `http://` not `https://`); F2P uses `https://fishingplanet.com/xbox/privacy/`.
- Retail privacy variants are otherwise identical to each other except brand string and the Steam/PS4-vs-Xbox-Live line.

---

## 4. Game Rules

Two distinct document families share the "Game Rules" title; note both are somewhat mislabeled.

**4a. "Short" family - actually the old EULA body.** `GameRules.htm` (F2P root, "Fishing Planet") vs `GameRulesr.htm` (Retail root, "The Fisherman - Fishing Planet"). Both are the **legacy 16-section EULA + Exhibit-A Game Rules** (same body as `consoler/eula`), mistitled "Game Rules."
- **Difference is branding only.** Every diff line is `Fishing Planet` -> `The Fisherman - Fishing Planet`. No substantive divergence.
- Both carry the **stale 13-year** minimum age and **"clan"** terminology (i.e. both are old relative to the current F2P EULA at `xbox/eula`).

**4b. "Long" family - the chat/conduct rules.** `pc/GameRules.htm` and `GameRulesPC.htm` (F2P, identical to each other) vs `pcr/GameRules.htm` (Retail).
- **Difference is branding only** (`Fishing Planet` -> `The Fisherman - Fishing Planet`). No substantive divergence.
- Both state minimum age **"seven (7) years of age or older"** and use mostly **"club"** terminology (with a couple of stray "clan" leftovers).

**Cross-family inconsistency (affects both products equally):** three different minimum ages coexist in the "Game Rules" documents - **3** (current F2P EULA), **7** (long PC game rules), **13** (short game-rules / old EULA). This is a pre-existing content-hygiene problem, not a Retail-vs-F2P difference.

---

## 5. Tournament / Competitive Activity Rules

Files: F2P `TournamentRules.htm` vs Retail `TournamentRulesr.htm`.

- **Renamed in F2P.** F2P heading/title: **"Competitive Activity Rules."** Retail: **"Tournament Rules"** (older name).
- **F2P adds a shared-device restriction that Retail lacks.** F2P 1.2: *"A player can only participate... with one Fishing Planet account. If there are two or more players who share the same device... only one of them can participate in competitive activities."* Retail 1.2 has only *"A player can only participate... with one account"* (no brand, no shared-device rule).
- **F2P splits selling/trading into its own rule.** F2P promotes *"Selling, renting, trading or receiving compensation... is forbidden"* to a standalone 1.3; Retail keeps it appended to 1.2. Net effect: F2P has rules 1.1-1.7, Retail 1.1-1.6 (one fewer).
- **Minor:** Retail *"his own connection"* / *"each participant who enter"* (grammo) vs F2P gender-neutral *"their own connection"* / *"who enters."*
- No economy/DLC/waterbody references in either.

---

## Bottom line: does Retail need updating?

**Yes - the Retail documents are materially stale and should be brought in line with the current F2P versions before hosting.** Priority order:

1. **Privacy Policy (highest).** Retail is the **May 25, 2018 GDPR-launch text, 5+ years out of date** vs F2P's Aug 30, 2023. It carries a weaker children's-consent clause (no verifiable-consent / no parent review-delete-withdraw rights) and a **vk.com** reference. This is the clearest legal-exposure item.
2. **EULA and TOS.** Retail is a prior revision: **minimum age 13 vs the current F2P 3** (with no Apple carve-out), "clan" vs "club" terminology, legacy Xbox 360 / PS4-only / demo-account clauses, and missing the club-conduct prohibitions (twinking, bullying, cheating, president-ban). PlayStation references are frozen at PS4 (no PS5).
3. **Internal consistency fixes.** Two retail files are self-inconsistent: `xboxr/eula` and `xboxr/tos` keep the **F2P brand string** while being Xbox-scoped, and `xboxr/tos` 12.3 has an **unsubstituted broken support URL** (`na.Fishing Planet LLC..net`). The three-way minimum-age contradiction (3 / 7 / 13) spans both products and should be reconciled.

Non-issues confirmed: legal entity, address, governing law, and arbitration/class-action waiver are already identical across both products; there is **no** physical-disc / DLC / exclusive-waterbody language to reconcile. The one clause where Retail is richer than the F2P console/xbox TOS is the Premium-Shop **Gifts** section (8.6) - decide whether that belongs in the console/xbox TOS too, or should be removed from Retail.
