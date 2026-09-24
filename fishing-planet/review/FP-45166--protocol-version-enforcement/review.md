---
status: reopened
executor: Yuriy Burda
branch: MFT20260325 @ r16363, merged to NPN20260602 @ r16364
jira: https://fishingplanet.atlassian.net/browse/FP-45166
---

# Review: FP-45166 — Server: Enforce client/server protocol version compatibility on the server

## Summary

Moves the client/server protocol-version compatibility decision from the client to the server. Before this change the client asked the server for its protocol version, compared locally and decided whether to continue; the server accepted anything that connected. The task makes the Master server the authority: authentication and account registration (plus the pre-authentication checks supporting it) must carry the client's protocol version and are refused on mismatch or absence, before any session/token/profile work happens.

Error/diagnostic reporting and the operation that reports the server's own protocol version stay open so a refused client can still report and discover why. Rejection must be distinguishable so the client shows the existing "outdated version, please update" prompt, and rejections must be logged with the reported version. Scope is the Master connection only — a Game server is unreachable without a Master-issued token. Service logins (AsyncProcessor, WebAdmin, ReleaseTool, automated test clients) must keep working.

Ships with 2026.5 Anniversary (FPA), which releases from MFT20260325.

**Why the check moved server-side at all** (background from the executor, recorded 2026-09-23): compatibility was originally validated on the client alone. A commit that muted that client-side check was landed by accident, after which nothing stopped incompatible clients, and a server-side guard became necessary. Worth carrying into any reading of the findings: no client built before FPA has a handler for the new refusal code, so those builds bail out silently to their start screen, while the FPA client and later show the update prompt. The silent drop is therefore a transitional property of the old client population, not of the refusal.

## Scope

### MFT20260325
- **r16363** — Server: Enforce client protocol version on the Master server

### NPN20260602 (merged)
- **r16364** — Merge from MFT r16363

### CodeBranch (client)
- **r56688** — Client: Send protocol version, prompt to update on mismatch

## Investigation Journal

- Phase 1 intake: JIRA read, no pre-existing review folder for FP-45166 (globbed `<kb>/fishing-planet/review/FP-45166--*/`) — new card, first round.
- Commit list taken from the executor's JIRA comment at face value; SVN audit deferred to Phase 2.
- VCS audit: `svn log -r 16340:HEAD | grep FP-45166` on both branches confirms exactly the two commits claimed in JIRA — MFT r16363 (author `yuriy.burda`), NPN r16364 (merge of r16363). No unposted commits. Client r56688 confirmed on `Unity_Fishing_CodeBranch`.
- WC freshness: server WC at r16364 ≥ reviewed r16363, so server files were read from disk. Client WC at r56602 is BEHIND r56688 — all client reads went through `svn cat -r 56688` / `svn diff -c 56688`; the stale-WC warning was propagated into both delegated reviewers' prompts.
- Pre-auth surface parity verified by reading both sides: server allows exactly five sub-operations without auth (`MasterClientPeer.HandleProfileOperation` — RegisterUser, CheckEmailIsUnique, CheckUsernameIsUnique, CheckPromoCode, GenerateUsername); client r56688 adds `AddProtocolVersion` to exactly those five plus `Authenticate`. No gap.
- Service-login exemption traced to its consumers, not assumed: WebAdmin, ReleaseTool and AsyncProcessor's FarmManager authenticate as `Settings.MessengerUser`, the PhotonHelper console tool as `Settings.ServiceUser` — both GUIDs are what `LoginAdapter.IsServiceAccount` covers. `PhotonStandaloneClient` additionally sends the version now, so a version-skewed service build is protected twice.
- Hypothesis "the DLL merged into MainClient carries a different protocol version" — disproven: `svn cat` on `Shared/Photon.Interfaces/SharedConsts.cs` shows `F2PProtocolVersion = 1126` on both MFT and NPN. The executor's "safe to merge" claim holds for the version, but the two branches' `Photon.Interfaces` still differ in four files (see F-4).
- Hypothesis "client sends back the version it asked the server for, making the check tautological" — disproven: client `ProtocolVersion` resolves to the compile-time `SharedConsts.F2PProtocolVersion` from the bundled DLL (`PhotonServerConnection.cs`), not to the `GetProtocolVersion` response.
- Hypothesis "other platform managers also destroy saved credentials on the new failure, and only Apple was fixed" — disproven: `svn cat -r 56688` on `AndroidManager.OnAuthFailed` and `EpicManager.OnAuthFailed` shows both only log; no other platform subscribes a credential-resetting handler to `OnAuthenticationFailed`.
- Token-issuance check: `LoginProviderBase.GenerateToken` is stateless crypto (`Crypto.EncryptPassword`), persisting nothing — a refused client leaves no server-side token behind, and the generated one never reaches it (the response object is replaced).
- Build-integration check: both `LoadBalancing.csproj` and `LoadBalancing.Tests.csproj` are SDK-style, so the two added files compile without a csproj edit.

- Delegation (Step 7): blind defect hunt run in parallel by the `code-reviewer` agent and Codex (gpt-5.6-sol), neither pre-loaded with recon findings. Every delegated claim was re-verified independently before being promoted; disagreements resolved on evidence, recorded per finding.
- Delegation disagreement resolved — parameter type handling: the agent judged it clean ("the client always sends a boxed `int`"), Codex reported an unhandled-exception path. Both were reading the same code with different threat models; the agent bounded itself to a correct client, Codex to arbitrary input from an unauthenticated peer. The latter is the reachable population on this path, so the finding stands (F-4), at Low because no correct client is affected.
- Reviewer's argument corrected by the user during F-1 discussion: the case for keeping `IsServiceAccount` was partly built on deployment version skew between Photon and the separately-deployed WebAdmin/AsyncProcessor. Production deploys all components as one batch, so that risk is smaller than the review assumed — dropping the exemption entirely (now that `PhotonStandaloneClient` sends the version itself) is a viable option too, and the choice is the executor's.
- Severity raised above the reviewer's own initial reading on F-1: recon rated it Medium on the strength of the Steam password rotation alone. The stuck `Users.IsOnLine` flag — established afterwards by reading the `MarkLoggedIn` procedure body and `PreviewDisconnect`'s guard — applies to every refused platform login, which on a blocking release is the whole not-yet-updated player base. That population argument, not the delegates' severity labels, is what moved it to High.

## Findings

### F-1: Authentication mutates persistent state before the protocol-version rejection [High]

**Description:** In `MasterAuthenticator.HandleAuthenticateOperation` the version check runs after `LoginAdapter.ValidateLoginInformation`, so the full platform-authentication flow — including SQL writes — completes before a mismatched client is refused. The refused peer leaves `Users.IsOnLine = 1` behind permanently, and on the Steam path its account's secondary password is rotated in the database while the response carrying the new password is discarded. On a blocking release this applies to every player who has not yet updated.

**Investigation:**
- Read `MasterAuthenticator.HandleAuthenticateOperation` at r16363: the guard sits after `ValidateLoginInformation` and before `SetLoginData`. Concluded the acceptance criterion's three named items hold — `OnlineCacheAdaper.LogOn`, `CreateSessionStats`, `LoadProfile` and `Peers.AddPeer` are all downstream of the guard.
- Read `LoginProviderBase.GenerateToken`: `Crypto.EncryptPassword` over a composed string, no persistence. Concluded a refused client leaves no server-side token, and the generated one never reaches it — "no token" holds from the client's side.
- Read `SqlLoginProvider.ValidateUserByExternalId` (the Steam/Epic/PSN/Apple/Android/Nintendo path): calls `RefreshLastActivity`, then `MarkLoggedIn`, and clears expired chat/account bans. Read `LoginProviderBase.ValidateToken`: also calls `MarkLoggedIn`. Concluded both authentication styles write before the guard.
- Read the `MarkLoggedIn` procedure body (`SQL/Patches/CLY.M.2023.08.11-059.sql`): `UPDATE Users WITH (ROWLOCK) SET IsOnLine = 1 ...`. Concluded the flag is persisted, not in-memory.
- Read `MasterClientPeer.PreviewDisconnect`: `Logout` is called only `if (!string.IsNullOrEmpty(UserId))`, and `UserId` is assigned by `SetLoginData` — downstream of the guard. Concluded the refused peer never clears `IsOnLine`; it stays 1 until that account's next successful login and disconnect. This settles as CONFIRMED what Codex had recorded as an unresolved hypothesis.
- Read `LoginAdapter.ValidateSteamAuth` (main ticket path, not the `#if DEBUG` one): `HandleSuccessfulLogin` writes a `SuccessfulLogIn` security-log entry, then `GeneratePassword` + `UpdatePassword` persists a new Steam secondary password and puts it in `context.Response`. Concluded the client keeps its old secondary password while the database holds the new one, so the Steam fallback login (used when Steam is unavailable — `ValidateUser(UserId, ClientAuthenticationParams + SecondaryPasswordSufix)`) fails for that account until the next successful primary login.
- Read `LoginAdapter.ValidateXboxAuth`: `SetUserName` on initial login — a further pre-guard write, benign in effect.
- Grepped `Users.IsOnLine` consumers: a `SELECT` grant to the `webhooks` login (`SQL/Users/WebhooksLogin.sql`). The `IsOnline` hits in the `CLU.M.*` patches are `Rooms.IsOnline`, a different column. Concluded the stuck flag corrupts reporting/webhook data, not the login path itself.

**Resolution:** Reopened — returned to the executor for rework; the release is not blocked (reviewer and executor have a day before the 2026-07-29 cut).

Direction agreed: move the check to the top of `HandleAuthenticateOperation`, right after `OperationHelper.ValidateOperation` and before `GenerateNewSessionId`. Order inside the guard is what keeps it cheap — compare the version first, and resolve service-account status only on the mismatch path, where the identity lookup is needed. A matching client pays nothing.

Resolving service status before credentials are validated:
- Email+password logins (how WebAdmin, ReleaseTool, AsyncProcessor and PhotonHelper all connect): `GetUser(request.UserId, updateActivity: false)` → `IsServiceAccount`. Verified this is side-effect-free — it runs `GetUserByEmail`, and `RefreshLastActivity` fires only when `updateActivity` is true.
- Token re-auth: no side-effect-free token parse exists today. `LoginProviderBase.ValidateTokenInt` calls `MarkLoggedIn` unconditionally at the end, and its `updateLastLoginDate` parameter only governs the `LastLoginDate` column — the procedure sets `IsOnLine = 1` on both branches. The parse needs extracting into its own method, with `MarkLoggedIn` left to the caller. Small but non-zero.

Spoofing the claimed identity buys only a skipped version check, which the ticket already scopes as trivially bypassable, so an unverified marker is acceptable for an exemption.

**Discovered by:** skill recon, code-reviewer agent, Codex (independently).

### F-2: Refusal path lets an unauthenticated peer grow the exceptions table without limit [Low]

**Description:** Every refusal in `ProtocolVersionValidator.Validate` writes a log line and calls `AnalyticsAdapter.SaveMasterException`, which is a synchronous SQL round-trip. On the `MasterClientPeer.OnOperationRequest` ProfileOperation branch this path needs no credentials at all, and the reported version is part of the grouping key, so varying it produces new rows rather than incrementing one.

**Investigation:**
- Read `HashHelper.CleanupExceptionMessageFromParameters`: `PatternNumber2` (`[#\s][\+-]?\d+`) only masks a number preceded by whitespace or `#`. In `v1127` the digits are glued to the `v`, so they survive masking — which is what the executor's own comment and test intend, to keep builds apart. Concluded the reported version is part of the group key by design.
- Read `AnalyticsAdapter.SaveException`: group identity is `errorData.GetHashCode()` over class name + cleaned message. Concluded a varying reported version yields a different hash each time.
- Read `MasterClientPeer.OnOperationRequest`: the ProfileOperation branch is reached with no authentication; `antiCheatManager.UnauthorizedOperation` — used by other guarded operations in the same method — is not invoked here, and the peer is not disconnected after refusal.
- Compared against the prior behaviour: an unauthenticated peer sending a protected ProfileOperation previously got `HandleUnauthorizedOperation`, which only writes a debug log. Concluded this is a newly introduced write path, not a pre-existing one.
- Not established: whether Photon's own engine or an upstream proxy applies inbound per-peer/per-IP throttling. Both delegates flagged the same gap and neither could observe it from the repository; recorded unresolved.
- Second scenario, distinct from abuse: on a blocking release every not-yet-updated client's login attempt costs a synchronous SQL round-trip on the operation-handling thread, at the exact moment the login flood peaks. Grouping collapses the rows, so the cost is round-trips rather than table growth.

**Resolution:** Reopened — folded into the same rework round as F-1: stop emitting the analytics write per refusal, and drop the connection instead of staying in conversation with a client there is nothing more to say to.

Constraint on the disconnect: it must happen only after the `ProtocolVersionMismatch` response is delivered. The client needs that code to raise the update prompt; a disconnect that races it lands the player in the generic disconnect flow — the exact behaviour this ticket set out to replace. The client side is already sensitive here, r56688 having patched `DisconnectServerAction` so a disconnect does not tear the prompt down. So: deferred disconnect through the normal path, not immediately after `SendOperationResponse`.

**Discovered by:** Codex and code-reviewer agent (recon had noted the cost, not the unbounded cardinality).

### F-3: The update prompt only fires on the initial connection, not on a later Master re-authentication [Info]

**Description:** In the client's `TravelManager`, `AuthState.ProtocolVersionMismatch` is handled only in the initial-connection path. `CreateRoom` and `JoinRoom` re-authenticate against Master and treat anything other than `Authenticated` as a generic failure, calling `ForceDisconnect()`. The asymmetry is real but unreachable under the current release regime — see Resolution.

**Investigation:**
- Client WC is stale (r56602), so `svn cat -r 56688` was used for the whole file rather than a disk read.
- Traced every `await Authenticate()` call site at r56688: the initial path handles `ProtocolVersionMismatch` and raises `OnProtocolVersionIncorrect`; the four remaining call sites sit inside `CreateRoom` and `JoinRoom` and branch only on `== Authenticated` / `!= Authenticated`, falling through to `ForceDisconnect()`.
- Initially concluded the failure was reachable during a live rollout that bumps the version under connected old-build clients. That premise was wrong: the protocol version is only ever bumped behind a downtime, so the server's expected version is constant for the lifetime of any connection. A client whose initial authentication succeeded cannot get a mismatch on re-authentication.

**Resolution:** Skipped — the code asymmetry exists but is unreachable while protocol bumps require downtime. It becomes live only if rolling updates without downtime are ever introduced.

**Discovered by:** code-reviewer agent (reachability premise corrected by the user).

### F-4: A non-integer protocol-version parameter throws instead of producing the refusal [Low]

**Description:** `ProtocolVersionValidator.Validate` reads the version via `GetParameter(..., out int? reported)`, which uses `Convert.ToInt32`. A non-numeric string or an overflowing `long` throws. On the ProfileOperation path the guard is evaluated in an `else if` condition, outside `OnOperationRequest`'s `try`, so no refusal response is produced at all; on the Authenticate path it is inside the `try` and surfaces as a generic error rather than the distinguishable code.

**Investigation:**
- Read `ParameterDictionaryExtensions.GetParameter(..., out int? value)`: `Convert.ToInt32(obj)` with no `try`/type check. Concluded `FormatException` / `OverflowException` / `InvalidCastException` are all reachable from attacker-controlled parameter values.
- Read `MasterClientPeer.OnOperationRequest`: the new branch is `else if (... && !ProtocolVersionValidator.Validate(...))`; the `try` opens only in the following `else`. Concluded the exception is not caught locally on that path, while `HandleAuthenticateOperation` runs inside the `try`.
- Read the client's `LoadbalancingPeer.OpAuthenticate` and `AddProtocolVersion` at r56688: both assign a C# `int`. Concluded no correct client can trigger this, which caps the severity.
- Not established: what Photon's host does with the escaping exception (disconnect, host-level error, or ignore) — that needs a runtime probe, so it is recorded unresolved rather than asserted.
- Reachability does not depend on deploy timing (unlike F-3): the value comes from an unauthenticated peer and is fully attacker-controlled.

**Resolution:** Reopened — folded into the same rework round. Preference is to read the parameter with a type check instead of `Convert.ToInt32`, rather than widening the `try` — that removes the cause instead of masking it.

**Discovered by:** Codex.

### F-5: The legacy load-test client will be refused [Low]

**Description:** `Photon/src-server/Loadbalancing/TestClient` hand-builds its `Authenticate` request without `ParameterCode.ProtocolVersion` and logs in with ordinary accounts, so it is refused. This conflicts with the ticket's constraint that automated test clients keep working, though the project appears dormant.

**Investigation:**
- Read `TestClient/ConnectionStates/Master.cs` `Authenticate()`: the parameter dictionary carries only `UserId` and `Secret`.
- Read `TestClient/users.xml`: ordinary `@domain.com` accounts, not the two service GUIDs — so `IsServiceAccount` does not exempt them.
- Ran `svn log` on the `TestClient` directory: the last four revisions are all branch-copy commits (r15943, r15396, r14593, r14175); no content change since at least 2025-05. Grepped `LoadBalancing.sln` — the project is not a member. Concluded the practical cost is near zero.
- Checked the clients that *were* updated: `NunitClient` and `PhotonStandaloneClient` both send the version now, so "automated test clients" is satisfied for the ones actually in use.

**Resolution:** Skipped — the project is not in use and not in the solution, so nothing in the test suite depends on it. The constraint is satisfied by the test clients that are actually used (`NunitClient`, `PhotonStandaloneClient`), both updated in this commit.

**Discovered by:** Codex (recon reached the same file while reading its search trail; verified independently here).

### F-6: Test clients are hardwired to the F2P protocol version [Low]

**Description:** `NunitClient.DefaultProtocolVersion` and `PhotonStandaloneClient.DefaultProtocolVersion` are both `SharedConsts.F2PProtocolVersion` unconditionally, while `ProtocolVersionValidator.Expected` honours `MasterServerSettings.Default.IsRetail`. Against a Retail Master they send 1126 where 96 is expected and are refused. Separately, the Retail client sends no version at all.

**Investigation:**
- Read both added `DefaultProtocolVersion` constants in the r16363 diff: neither consults `IsRetail`.
- Read `ProtocolVersionValidator.Expected`: selects `RetailProtocolVersion` when `IsRetail`. Read `SharedConsts`: `F2PProtocolVersion = 1126`, `RetailProtocolVersion = 96`.
- Checked the release table in `<kb>/_index.md`: the releases currently shipping from this branch line are FTUE and FPA, both F2P; no Retail release is scheduled from it. Concluded the exposure is latent, and the scope caveat is that it binds to the current release plan — a future Retail cut from this line would need a paired Retail client.

**Resolution:** Skipped — no Retail release is planned. If Retail is ever brought back onto this line, authentication breaking immediately makes this self-announcing, and it would be far from the largest problem in that effort.

**Discovered by:** Codex (Retail angle), skill recon (client-side pairing).

### F-7: The MainClient DLL should be rebuilt from MFT rather than merged from CodeBranch [Low]

**Description:** The executor's note says `Photon.Interfaces.dll` is safe to merge into MainBranch. The protocol version agrees across branches, but the two `Photon.Interfaces` sources do not, so merging the CodeBranch binary would carry NPN-only definitions into the Content client instead of a build matching its paired server.

**Investigation:**
- `svn cat` on `SharedConsts.cs` for both branches: `F2PProtocolVersion = 1126` on MFT and NPN alike — the executor's safety claim holds for the version itself.
- `svn diff --old MFT@16364 --new NPN@16366` over `Shared/Photon.Interfaces`: four files differ — `OperationCode.GetPondPinIcons = 102`, `ProfileParameterCode.FriendsBanEndDate = 142`, two `Chat` constants, plus a whitespace-only hunk. Concluded the divergence is additive and inert for a Content client, so this is a process point rather than a defect.
- Re-read `<kb>/reference/photon_interfaces_dll_distribution.md`: the branch-pairing rule already prescribes rebuilding from the target branch after the server-side merge lands, rather than carrying the binary across.

**Resolution:** Skipped — not worth interrupting the client team's merge. The divergence is additive (enum values and string constants, no serialization-contract change), so it is inert in a Content client. The only real consequence is that the shipped binary carries the names of unreleased opcodes, which tells a datamining player something about upcoming features.

**Discovered by:** skill recon.

### F-8: The guard covers every unauthenticated ProfileOperation, not just the pre-auth ones [Info]

**Description:** The version check in `OnOperationRequest` runs before the sub-operation is inspected, so an unauthenticated peer sending a normally protected ProfileOperation gets the expensive `ProtocolVersionMismatch` path instead of the cheap unauthorized response. No authorization is bypassed; it widens the surface behind F-2.

**Investigation:**
- Read `MasterClientPeer.HandleProfileOperation`: exactly five sub-operations are legal without authentication — `RegisterUser`, `CheckEmailIsUnique`, `CheckUsernameIsUnique`, `CheckPromoCode`, `GenerateUsername`; everything else returns `HandleUnauthorizedOperation`.
- Read `OnOperationRequest`: the guard keys on `opCode == OperationCode.ProfileOperation` alone, upstream of that switch. Concluded the ordering is safe for authorization but broader than the ticket's stated surface.
- Checked that relocating the guard is safe: `HandleProfileOperation` is `protected virtual` but has no overrides — its only caller is the `OperationCode.ProfileOperation` case. The same-named method in `GameClientPeer` is a private method on a different class, not an override.
- Read the tail of `OnOperationRequest`'s `try`: `if (response != null) SendOperationResponse(...)` followed by `performanceTracking.LogDelayAction()`. Concluded a refusal returned from inside `HandleProfileOperation` is sent and tracked through the normal path, so the dedicated branch with its own `LogDelayAction()` is not needed.

**Resolution:** Reopened — cheap enough to fix in the same round. Move the validator call out of `OnOperationRequest`'s `else if` and into `HandleProfileOperation`, immediately after the existing "operations allowed without auth" block on the `!IsAuthenticated` path. Version is then checked for exactly the five sub-operations the ticket names, protected operations go back to the cheap `Unauthorized`, and `OnOperationRequest` returns to its previous shape. Side effect: the guard lands inside the `try`, which covers half of F-4 — the type check there is still wanted, since catching the exception masks the cause rather than removing it. Cost is parsing `ProfileRequest` before refusing: contract parsing only, no writes.

**Discovered by:** Codex.

### F-9: Test coverage does not pin the logged message or the expected-version selection [Info]

**Description:** The integration tests genuinely discriminate — reverting the production guards makes them fail — but two requirements have no test that would catch a regression: the logged content, and the Retail/F2P choice of expected version.

**Investigation:**
- Read `ProtocolVersionValidatorTests.Refusal_message_should_keep_versions_and_mask_external_id_and_ip`: it formats `SecurityLogEntries.ProtocolVersionMismatch` itself instead of calling `Validate` and inspecting what the validator passes on. Concluded reordering the format arguments or dropping the `"v"` prefix in production would leave the test green, so "rejections must be logged with the reported version" is unpinned.
- Read `Validate_matching_version_should_pass`: the request is built from `ProtocolVersionValidator.Expected`, the same expression production compares against. Concluded it cannot detect a wrong Retail/F2P branch in `Expected`.
- Read `LoginTest.UserWithWrongProtocolVersionCannotLoginToMaster` / `...CannotRegisterNewAccount`: real integration tests asserting the distinct error code and absence of token/authentication — these do discriminate. Noted they would still pass under F-1, since they assert on the client-visible outcome and not on pre-rejection database state.

**Resolution:** Reopened — folded into the same round. Have the log-message test call `Validate` and inspect what it actually emits, instead of formatting the template itself. Worth adding alongside the F-1 rework: an assertion that a refused login leaves `Users.IsOnLine` unset — that is the regression class F-1 belongs to, and the existing tests are blind to it because they only assert what the client sees. `LoginTest` is already `Integrated` and runs against a live server and database, so the assertion is cheap to place.

**Discovered by:** Codex and code-reviewer agent.

## Verdict

**Approve, with rework returned to the executor** — the change ships with 2026.5 Anniversary; the reopened items are non-blocking and land in a follow-up round before the cut.

The feature does what the ticket asked. The server is now the authority on protocol compatibility, the pre-authentication surface is covered exactly (server's five allowed sub-operations against the client's five `AddProtocolVersion` calls, verified on both sides), `Diag` and `GetProtocolVersion` stay open, service logins keep working, and the rejection is distinguishable enough for the client to raise the existing update prompt. Enum allocation is clean and the integration tests discriminate.

What comes back, in one round:
- **F-1 [High]** — move the version check ahead of `ValidateLoginInformation` so a refused client stops leaving `Users.IsOnLine = 1` behind and stops having its Steam secondary password rotated out from under it.
- **F-2 [Low]** — drop the per-refusal analytics write and disconnect the refused peer, after the response is delivered.
- **F-4 [Low]** — read the version parameter with a type check rather than `Convert.ToInt32`.
- **F-8 [Info]** — relocate the guard into `HandleProfileOperation` so it covers the five pre-auth sub-operations rather than every ProfileOperation.
- **F-9 [Info]** — have the log-message test exercise `Validate`, and assert that a refused login leaves `Users.IsOnLine` unset.

Skipped: F-3 (unreachable while protocol bumps require downtime), F-5 (dormant load-test client), F-6 (no Retail release planned), F-7 (client-side merge left alone; inert opcode names in the shipped DLL are the only consequence).

**Verification scope:** the review is static — code, diffs and the `MarkLoggedIn` procedure body read at the reviewed revisions, plus the SVN record. Nothing was run. Not established, and not claimed: Photon's runtime reaction to the escaping exception in F-4; whether any inbound throttling exists beneath the application layer (F-2); and the executor's own note that platforms other than Steam were not manually tested still stands — no platform behaviour was verified here by execution.

## Considered and rejected

- Codex reported as High that a mismatched client with bad credentials or an unregistered platform account gets a generic error instead of `ProtocolVersionMismatch`. Rejected as a standalone finding: a build old enough to mismatch does not understand the new error code anyway, and a future client in that position is routed into registration, where the guard runs before any credential work and returns the correct code. It is a consequence of F-1's ordering, not a separate defect.
- `PhotonStandaloneClient.ConnectAndAuthenticate` reads `Secret`/`UserId` out of the response before checking `ReturnCode`, so a refusal surfaces as `KeyNotFoundException` rather than the return code. Verified by reading the method — but the ordering predates this commit and any refusal (bad password, ban) already behaved this way. Pre-existing, not introduced here.
- Hypothesis that the platform login paths auto-create an account for an unknown external id, which would let a mismatched client register before being refused: disproven — `ValidateUserByExternalId` returning null sets `UserIsNotRegistered` and the flow returns false.

## Close

- **Cross-branch merge:** none performed by the reviewer. Source is Content (MFT20260325), so the only upward target is Code (NPN20260602), and the executor had already merged it at r16364. Branch-copy inheritance does not apply — r16363 is above NPN's creation source rev (MFT:16130).
- **Paired client commit — not in the release client.** Verified by content, not `mergeinfo`: at MainClient HEAD (r56705) `LoadbalancingPeer.cs` was last touched at r50354 and its `ParameterCode` block runs `MasterPeerCount = 227` straight to `UserId = 225` with no `ProtocolVersion = 226`; `AddProtocolVersion` does not appear in `PhotonServerConnection_ProfileOperations.cs`; and `svn log` over r56400:HEAD carries no FP-45166 revision. Since 2026.5 Anniversary ships from MFT plus MainClient, and the MFT server half already refuses clients that send no version, releasing this pair as-is would refuse every MainClient build at login. Client-branch merges belong to the client team, so this was raised to the client lead in its own JIRA comment rather than merged from the server side.
- **Release-step field (`customfield_11323`):** left empty, legitimately — the diff touches only C# sources. No `SQL/Patches`, `SQL/Releases` or `NoSql` scripts, no WebHooks or Twitch project, no profile conversion, no DataPump content, and the verdict carries no post-release action. Nothing in the gate's derivation table applies.
- **KB `_index.md`:** the Active Reviews row is left to the user — the file was carrying concurrent edits from another session, and this review's row shares a diff hunk with them.
- **Handoff:** the ticket was transitioned back to the executor by the user (JIRA status `Reopened`, assignee Yuriy Burda); the MainClient merge was passed to the client lead over Slack with a link to the JIRA comment.
- **Client pair resolved (2026-07-28):** the client lead merged r56688 into MainClient at r56710. Verified by content, not `mergeinfo` — every file from r56688 is present, including `PhotonConnectionFactory.cs` where `LoadbalancingPeer.GetProtocolVersion` is wired (without that line the client would silently send nothing), `AddProtocolVersion` on all pre-auth operations including `CheckPromoCode`, and the `TravelManager` / `AppleManager` / `DisconnectServerAction` handling. The shipped `Photon.Interfaces.dll` is byte-identical to the CodeBranch one, and its metadata was read directly rather than inferred: `F2PProtocolVersion = 1126`, `ParameterCode.ProtocolVersion = 226`, `ErrorCode.ProtocolVersionMismatch = 32531` — all matching the MFT server.
- **Release decision (2026-07-28):** shipping as-is, with the rework to follow as a hotfix once it lands — the ticket carries fix versions `2026.5 Anniversary` and `Next Server Hotfix`. The rework had not arrived at decision time — no FP-45166 commit exists on MFT above r16363 (branch HEAD r16377). Accepted consequence, recorded so post-release symptoms are not re-diagnosed from scratch: for the duration of the not-yet-updated tail, every refused login leaves `Users.IsOnLine = 1` behind (F-1), rotates the Steam secondary password without delivering it, logs a `SuccessfulLogIn` for a client that is then refused, and costs a synchronous SQL write per refusal at the login peak (F-2). The stale flag clears for each player once they update and disconnect normally.

## Round 2 checklist

To verify when the rework lands, before the release:

- **F-1** — the check runs ahead of `ValidateLoginInformation`; a refused login leaves `Users.IsOnLine` untouched (assert against the DB, not the client-visible outcome); the Steam secondary password is not rotated on a refusal; service logins still authenticate (WebAdmin, ReleaseTool, AsyncProcessor via `MessengerUser`, PhotonHelper via `ServiceUser`). If the token re-auth path was covered, check that the extracted token parse does not call `MarkLoggedIn`.
- **F-2** — no per-refusal analytics write; the disconnect lands after the refusal response is delivered, so the client can still raise the update prompt.
- **F-4** — the version parameter is read with a type check rather than `Convert.ToInt32`.
- **F-8** — the guard sits in `HandleProfileOperation` on the `!IsAuthenticated` path; protected sub-operations are back to `Unauthorized`; the `else if` branch in `OnOperationRequest` is gone.
- **F-9** — the log-message test drives `Validate` instead of formatting the template itself; a refused login asserts `Users.IsOnLine` unset.
- **Regression, already verified in round 1 — confirm the rework did not disturb it:** the pre-auth surface still matches exactly (server's five allowed sub-operations against the client's `AddProtocolVersion` calls); `Diag` and `GetProtocolVersion` stay open to an unauthenticated peer.
- **Cross-repo** — re-check by content (not `mergeinfo`) that the client half reached MainClient: `ParameterCode.ProtocolVersion = 226` in `LoadbalancingPeer.cs` and the `AddProtocolVersion` calls in `PhotonServerConnection_ProfileOperations.cs`.

## Notes

- Executor field (`customfield_11224`) was empty at intake; set to Yuriy Burda during close.
- Executor stated in JIRA that platforms other than Steam were not manually tested.

## Round 2

Executor: Yuriy Burda. Opened 2026-09-17, reviewing the rework returned in round 1.

### Scope

- **NPN20260602 r16384** — Rework server protocol version check per review

### Investigation

- Phase 1 intake: existing card reused per the re-review guard; JIRA re-read at round-2 intake rather than carried from the round-1 session — status `In Review`, assignee Stanislav Samoilov, Executor field populated (Yuriy Burda). Commit taken at face value from the executor's JIRA comment; SVN audit deferred to Phase 2.
- Round-1 close left two open threads that round 2 must settle: the rework's absence from MFT (the branch the `Next Server Hotfix` fix version would ship from), and whether the shipped 2026.5 defects are actually fixed by this commit.
- VCS audit: `svn log | grep FP-45166` finds exactly one rework commit, NPN r16384, matching the executor's JIRA note. Layer 3 (grep both branch logs for `16384`) finds no revert or follow-up citing it. MFT carries no FP-45166 commit above r16363 — the rework exists only on the Code branch.
- WC freshness: NPN WC sits at r16551 — above the reviewed r16384 and below branch HEAD r16566 — so it shows neither state exactly. All reads went through `svn diff -c 16384` and `svn cat`; the same warning was propagated into both delegated reviewers' prompts.
- HEAD verification (commit is ~7 weeks old): `svn cat` at branch HEAD shows both guards still in place and unmodified — the relocated check at the top of `HandleAuthenticateOperation` and the one inside `HandleProfileOperation`. No later commit rewrote the reviewed code.
- Compile-surface check on the changed exemption: `IsServiceAccount` changed signature from `Guid` to `string`; `MessengerUserEmail` / `ServiceUserEmail` already existed as constants in `LoginAdapter`, and the method has exactly one call site, so no other caller was left behind.
- `DbAssert.AssertRecordCount` (used by the new database assertion in `LoginTest`) exists in the test project and runs its SQL against the test connection — the assertion is real, not a stub.
- Contract properties the guards now read were confirmed present at r16384: `AuthenticateRequest.UserId` is bound to `ParameterCode.UserId`, and `ProfileRequest.ExternalId` exists; both are what the refusal is attributed to.
- Production measurement (DataGrip reconnected for round 2; unavailable in round 1). Steam prod `Stats.dbo.ServerExceptions`, filtered `Exception = 'ProtocolVersionMismatch'`: 30 498 refusals across 36 grouped rows, 2026-08-01 → still arriving today. Every refusal is `client reported none`; refusals carrying a wrong number: zero. Distinct messages: 2 (one per operation). Distinct `ClientVersion`: 36. Probe was validated first — an initial `Message LIKE` filter returned zero because `TryParseExceptionClassFromMessage` strips the class out of the text into its own column; the control query (365 065 total rows, 53 by `Exception LIKE '%Protocol%'`) exposed the broken pattern before any conclusion was drawn from the zero.
- Round-1 model corrected by that measurement: F-2 claimed rows multiply because the reported version escapes masking behind its `v` prefix. In practice no client ever reports a version, and row count tracks `ClientVersion` — a separate column that masking never touches. The mechanism described in round 1 was wrong, and the volume (~620 refusals/day) makes the "synchronous SQL at the login peak" concern from round 1 an overestimate.
- Stuck-flag measurement: Steam prod has 4 655 rows with `IsOnLine = 1`, of which 4 499 were active within 24h (plausible live population) and 156 are stale; oldest stale activity 2026-08-11, i.e. no seven-week accumulation — the self-clearing path works. PlayStation shows the same shape (28 stale of 3 776). Mobile shows zero stale, but its farm restarted the same day, so it is a weak control rather than a clean negative.
- Wire compatibility with the already-shipped client: `ParameterCode.ProtocolVersion = 226` and `ErrorCode.ProtocolVersionMismatch = 0x7FFF - 236` are unchanged at r16384, and no stale call site of the old `Validate` signature remains. The rework can ship server-side without a paired client change.
- Delegation (Step 7): `code-reviewer` agent and Codex (gpt-5.6-sol) run in parallel, blind. Codex settled the Photon contract-validation question the agent had to leave unresolved, by checking the branch's Photon assemblies directly.
- Delegated claim rejected — "the changed tests do not prove the new ordering" (Codex): disproven. `SqlLoginProvider.ValidateUser(email, password)` calls `MarkLoggedIn`, so under the old ordering the test's own email/password login would set `IsOnLine = 1` and the new `DbAssert` would fail. The test does discriminate on the ordering.
- Delegated claim rejected — "attribution regressed because external auth formerly logged `ExternalId`" (Codex): disproven. The client's `OpAuthenticate` never sends `ProfileParameterCode.ExternalId`, so that value was already absent on the Authenticate path before the rework; for email/password logins the new `request.UserId` is strictly more informative.
- Delegated claim narrowed — the agent concluded the claimed-service-email exemption "does not grant access, ValidateUser still requires the real password". True only for the Default path. `ValidateLoginInformation` dispatches on `ClientAuthenticationType`, and `ValidateSteamAuth` authenticates from the ticket in `Secret` without reading `UserId`, so on every external-auth platform the claim grants a complete bypass, not a delayed failure (see R2-F1).

### Findings

Round-1 items settled by this rework: F-1 (guard moved above `ValidateLoginInformation`), F-4 (version arrives through the request contract, `Convert.ToInt32` gone from the path), F-8 (guard relocated into `HandleProfileOperation` after the allowed-without-auth list), F-9's main gap (`DbAssert` asserts `IsOnline = 0` after a refusal). F-2 is only partially settled — see R2-F5.

#### R2-F1: Claiming a service email bypasses the version check entirely on external-auth platforms [Medium]

**Description:** `MasterAuthenticator.HandleAuthenticateOperation` now exempts service logins by the *claimed* email (`LoginAdapter.IsServiceAccount(request.UserId)`), before any identity is proven. The code comment justifies this by saying a spoofed claim fails the login below anyway. That holds only for the Default email/password path. On every external-auth platform the login never reads `UserId`, so a client supplying a service email plus its own ordinary platform ticket skips the guard and authenticates fully — session, token and profile included — without its protocol version ever being checked.

**Investigation:**
- Read `LoginAdapter.ValidateLoginInformation` at r16384: the path is chosen by `switch (context.Request.ClientAuthenticationType)`, not by `UserId`.
- Read `ValidateSteamAuth` at r16384: the main path verifies `context.Request.Secret` as a Steam ticket and resolves the account through `ValidateUserByExternalId(SteamSource, steamId)`; `request.UserId` is read only on the secondary-password fallback used when Steam is unreachable. The Xbox/PS/Apple/Android/Epic/Nintendo cases have the same shape. Concluded the comment's premise is false for these paths.
- Grepped the branch for the two literals: `svc@domain.com` and `messenger@domain.com` appear in 135 checked-in `.config` files, including per-environment deploy configs. Concluded the claim needs no guessing.
- Confirmed the fix carries no collateral: every named service tool authenticates through `PhotonStandaloneClient.CreateAuthenticateRequest(email, password)`, which sets no `ClientAuthenticationType` and therefore uses `ClientAuthenticationTypeDefault = 0`. Narrowing the exemption to that type keeps all of them exempt.
- Severity held at Medium rather than High: reaching this requires a deliberately modified client, and the ticket scopes the mechanism as a compatibility guard rather than an anti-cheat measure, noting that a modified client can already supply the expected value — so the same class of client had an equivalent bypass before. It remains a regression against r16363, where the exemption keyed off a DB-resolved `Guid`.

**Resolution:** Accepted — not patched on its own. The only prize is playing on an outdated client, which breaks the player's own game. The bypass disappears once the login refactor restores a resolved identity as the exemption key, and the misleading comment goes with it.

**Discovered by:** skill recon and Codex independently; the code-reviewer agent found the exemption change but stopped at the Default path.

#### R2-F2: A version sent with the wrong wire type yields the generic contract error, not the update-prompt code [Low]

**Description:** `ProtocolVersion` is now a `DataMember` of type `int?` on both request contracts, and `OperationHelper.ValidateOperation` runs before the validator. A value that is present but of another type — including a correct version sent as `Int64` — fails contract validation and returns `ErrorCode.OperationInvalid`, so the client gets no distinguishable code and no refusal is logged. The previous manual read used `Convert.ToInt32` and accepted convertible representations.

**Investigation:**
- Read both contracts and both call sites at r16384: `ValidateOperation` precedes `ProtocolVersionValidator.Validate` on the Authenticate and ProfileOperation paths alike, and returns `OperationInvalid` when the contract is not valid.
- Absence is unaffected: `IsOptional = true` makes a missing member valid and `null`, which the validator refuses with the correct code — that is the mainline outdated-client scenario.
- Verified the shipped client sends a C# `int` (`LoadbalancingPeer.OpAuthenticate`, `AddProtocolVersion`), so no real client is affected.
- Not reproduced by this reviewer: the claim that Photon marks the alternative representations contract-invalid rather than coercing them. Codex reports verifying it against the branch's Photon assemblies for GP Binary V17, V16, V16V2 and the base byte protocol; disassembling the closed SDK was not attempted here, so the claim is recorded with its source rather than as independently settled.

**Resolution:** Accepted — unreachable with the clients we ship. Every client that sends the field (Unity, `PhotonStandaloneClient`, `NunitClient`) sends a C# `int`, and absence — the actual outdated-client case — is handled correctly through `IsOptional`. `int?` is also the right width: the version is a four-digit number and would stay in range even if it later encoded a date. Tolerance to the wire representation itself sits in the Photon libraries, outside what this codebase can reasonably change, and is not worth pursuing.

**Discovered by:** Codex (the agent reached the same architectural point but labelled the SDK behaviour unresolved).

#### R2-F3: Refusals are no longer attributable to a player in analytics [Low]

**Description:** `ProtocolVersionValidator.Validate` now always passes a null user id to `AnalyticsAdapter.SaveMasterException`, which stores `Guid.Empty`, and the per-player `Sys.Log` write was removed. A refusal can no longer be traced to an account in the analytics store or in that player's log history.

**Investigation:**
- Read the diff: both the user-id argument and the `DalFactory.GetLogger().Sys.Log(...)` call are gone.
- Traced why it is unavoidable: the guard now runs before credentials are validated, so no proven identity exists at refusal time. Concluded this is inherent to the ordering fix, not an oversight.
- Checked the claimed additional loss of `ExternalId` attribution and rejected it — the parameter was never present on the Authenticate path.
- ProfileOperation refusals pass a null client version, recorded as `0.0`; confirmed against production, where ProfileOperation rows indeed carry `ClientVersion = 0.0`. Pre-existing rather than introduced: the old code read `ParameterCode.AppVersion`, which ProfileOperation requests do not carry either.

**Resolution:** Requirement for the refactor, not an accepted loss. The per-player `sys` entry is what diagnosed the 2026-09-22 support case, and r16384 removed it. The refactor restores it by resolving identity before the check; where identity does not resolve, the entry goes to the dedicated `00000000-0000-0000-0000-000000000000` id with whatever the client sent. The DB round trip is not an objection — an ordinary login attempt costs one too.

**Discovered by:** Codex and the code-reviewer agent.

#### R2-F4: Grouped error statistics no longer separate reported versions [Info]

**Description:** `BuildRefusalMessage` drops the `v` prefix, so `HashHelper` masks both version numbers to `NUM` and all numeric mismatches collapse into one grouped row. The ticket's measurability requirement is still met by the raw `Log.Error` line, which carries the unmasked value.

**Investigation:**
- Read `BuildRefusalMessage` and `HashHelper.CleanupExceptionMessageFromParameters`: `PatternNumber2` matches a digit run preceded by whitespace, which the new wording produces and the old `v`-prefixed wording did not. The new test locks the masked form in.
- Measured the practical loss in production: every one of the 30 498 refusals reports `none`, which is a literal and stays its own group, and none reports a number — so there is currently no version distribution to lose. Per-build breakdown survives regardless, in the unmasked `ClientVersion` column with its 36 distinct values.
- Concluded the delegates overstated the practical effect, and recorded the scope caveat: this binds to today's population, where no client sends a version. If a future client sends a wrong number, that distribution would indeed be invisible in grouped stats.

**Resolution:** Accepted, with a refactor note — express the masking explicitly with `[[...]]` instead of relying on `PatternNumber2` catching digits after a space, so the intent survives any rewording of the message. Collapsing is the right call: slices by server and client version are available as filters in the admin panel, so grouping does not need to carry them, and the reported number itself lives in the `sys` log, which is where support reads it anyway — per player, which is the only way that question is ever asked. A text scan across the whole `sysLog` is too heavy on production, but a per-user, time-boxed lookup is not. Collapsing buys no abuse protection either way: that vector stays open through the client-controlled `AppVersion`.

**Discovered by:** code-reviewer agent and Codex.

#### R2-F5: The refusal still writes to analytics per event and still does not drop the peer [Info]

**Description:** Round 1 returned F-2 with two asks — stop the per-refusal analytics write, and disconnect the refused peer after the response is delivered. The rework does neither; it only rewords the message, which closes the abuse vector of inflating row count by varying the version.

**Investigation:**
- Read the diff: `AnalyticsAdapter.SaveMasterException` remains on the refusal path, and no disconnect was added at either call site.
- Measured the cost this was meant to avoid: about 620 refusals per day on Steam prod, spread across the day. Concluded the residual cost is immaterial, and that round 1's framing of synchronous SQL at the login peak was an overestimate on the reviewer's part.

**Resolution:** Deferred to the refactor. The logging stays by decision (~100 refusals/day at the tail; round 1's framing of synchronous SQL at the login peak was the reviewer's overestimate). Requirement: once refused, a peer must not be able to keep issuing requests that cost the server anything. Two candidate mechanisms, to be chosen during the refactor:
- **disconnect after the refusal is delivered** — open questions: the Photon docs contrast `Disconnect` ("closes the connection") with `AbortConnection` ("forces the connection to close immediately", for when `Disconnect` does not shut down cleanly), which suggests but does not state that queued data is sent first, and nothing in our code sends a response and then disconnects, so delivery must be verified by a run; and r56688 had to stop the client's own disconnect path in `DisconnectServerAction` from tearing the update prompt down, so the FPA client's reaction to a server-side disconnect is a known risk;
- **mute the peer** — stop processing further requests, optionally answering each with a cached copy of the refusal without touching the database, and let the client leave on its own. Sidesteps both open questions; the cost is that a looping client holds its slot indefinitely (its pings keep the connection alive), which can be bounded by dropping a muted peer after a period well beyond human reaction time.

**Discovered by:** skill recon.

#### R2-F6: The rework is absent from the branch its fix version ships from [Info]

**Description:** The ticket carries fix version `Next Server Hotfix`, and 2026.5.x hotfixes ship from MFT20260325, but r16384 exists only on NPN20260602. As it stands the fix version is unbacked and the defects fixed here remain live in production.

**Investigation:**
- `svn log` on MFT for r16364 through HEAD (r16566) finds no FP-45166 commit; the only protocol-related commit there is r16388, the post-release minor increment from 1126.0 to 1126.1.
- Measured the backport cost: MFT and NPN differ by 38, 84, 70 and 35 lines across `MasterAuthenticator.cs`, `ProtocolVersionValidator.cs`, `MasterClientPeer.cs` and `LoginAdapter.cs` — largely the rework itself, so the backport looks tractable rather than a rewrite.
- Wire compatibility confirmed separately, so the backport needs no paired client change.

**Resolution:** Deferred to the refactor — backported to MFT once the refactor lands, not in r16384's shape, which is not shipping. Branch divergence on the affected files is small, and rolling out the resulting patch is not expected to be an obstacle.

**Discovered by:** skill recon.

### Considered and rejected (round 2)

- Codex reported the legacy `Loadbalancing/TestClient` as Medium, since it sends no version and would be refused. This is round 1's F-5, already closed as Skipped after the user confirmed the project is unused and outside the solution. The rework does not change it.
- Codex reported that the changed tests do not prove the new ordering. Disproven: `ValidateUser(email, password)` calls `MarkLoggedIn`, so the old ordering would leave `IsOnLine = 1` and fail the new `DbAssert`.
- Codex reported lost `ExternalId` attribution on external-auth refusals. Disproven: the client never sends that parameter in `OpAuthenticate`, so it was already absent before the rework.
- Still valid from that same Codex item: the validator unit tests build their input from `ProtocolVersionValidator.Expected`, so they cannot catch a wrong Retail/F2P branch inside `Expected`. This is round 1's F-9 residue, still Info.

### Decision (2026-09-23, reviewer + executor)

The rework is not taken as the final shape. Instead the login flow gets refactored, and this task's remaining items are folded into that work.

**Root cause named by the executor and the user, above any individual finding:** `ValidateLoginInformation` mutates state while answering a yes/no question. Everything in this review — the ordering fix, the claimed-email exemption, the lost attribution — is the code dancing around that fact. A function called `Validate` should validate and at most *return* context, never write it. The refactor splits identity resolution from effect application so the rest stops being contorted.

Consequences for the findings:

- **Round-1 F-1** — confirmed in production by a live support case (2026-09-22), not just by code reading: a player on an IMV-era build was silently dropped to the login screen, the server log carries `ProtocolVersionMismatch: on Authenticate, client reported none, server expects v1126`, and support reported the account showing permanently online in the admin panel while the machine was off. That is the stuck `Users.IsOnLine` flag. Fixed as part of the refactor.
- **R2-F1 (claimed-email bypass)** — accepted as a low-value prize on its own (it only buys playing on an outdated client, which breaks the player's own game). Not patched separately; it disappears once the exemption keys off a resolved identity again after the refactor.
- **R2-F3 (lost per-player attribution)** — promoted from an accepted consequence to a requirement. The support case above was diagnosed *because* the mismatch is written to the player's `sys` log; that write exists in production only because the guard currently runs after authentication, and r16384 removed it. The refactor must keep it. The cost objection (a DB round trip per refusal) was rejected on the grounds that an ordinary login attempt costs a DB round trip too, and anyone intent on spamming would spam login — which is heavier — rather than the version check.
- **R2-F5 (analytics write retained, peer not dropped)** — resolved by the same decision: the logging stays.
- **Logged identity is worth fixing while there** — the production log shows `external id "none"` because the client never sends `ProfileParameterCode.ExternalId` on `Authenticate`; r16384's `identity` is `request.UserId`, likewise empty on platform logins. With identity resolved before the check, a real identifier can be logged instead of an IP alone.

#### Production exposure, measured 2026-09-23

Measured to decide whether the unfixed state needs a separate backport ahead of the refactor. Source: `Stats.dbo.ServerExceptionUsers` joined to the `ProtocolVersionMismatch` hashes in `ServerExceptions`, Steam prod. (The event-level `sysLog` in Mongo was the better instrument for a day-by-day curve, but a text scan of that collection times out on production, so the SQL side was used instead — a limitation of the probe, not a property of the data.)

- Whole period since the FPA release: **2 470 distinct real accounts** refused, 30 956 refusals, first 2026-07-30 09:50 (release day on Steam), latest 2026-09-23 13:32. All of it sits under server protocol `1126.0` — the only value possible, since the feature did not exist before it, which doubles as a check that the selection is clean.
- Weekly curve by each account's last occurrence: 1 496 users in release week, then 400, 169, 109, 94, 67, 56, 59, and 22 in the partial current week. Better than half the affected population hit this in the first week; the rest decays to a plateau of roughly 55-60 accounts per week.
- An earlier pass measured September alone (186 accounts) and read the plateau as the whole picture. Corrected here: the plateau is the tail, not the scale.
- Stuck `IsOnLine = 1` rows hold at roughly 150 — the same order as the affected population, and what made the admin panel show the support case as permanently online.
- Support conversion is tiny: one ticket out of those 186.

**Conclusion — no separate backport, but the refactor is on a release clock.** The wave has passed: what remains is the tail, and its infrastructure load is nil (round 1's "synchronous SQL at the login peak" concern is fully retired). A patch of its own into a release branch, with its own review and deployment cycle, does not pay for a tail of ~55-60 accounts a week.

What that release-week figure does and does not predict (corrected after the executor's explanation):

- The silent drop to the login screen is a property of **pre-FPA clients**, not of the refusal. They have never seen `ProtocolVersionMismatch`, fall into their generic branch and bail out without a message. The FPA client handles the code and shows the update prompt — verified in MainClient r56710. So this symptom decays on its own as players move to FPA and later builds, and the next forced-update release will not reproduce it: by then the affected clients know the code.
- A version mismatch itself is simply what a forced-update release looks like, not a defect.
- What **does** reproduce on the next blocking release is the server-side symptom: every refusal leaves a stuck `Users.IsOnLine = 1`, and no client update can fix that. That, rather than the prompt, is what puts the refactor on a release clock.

**Additional requirement captured during the discussion:** a dedicated user id (`00000000-0000-0000-0000-000000000000`) already receives entries for failed logins, and is the intended sink for failed protocol checks and failed identity resolutions alike, including the data the client sent. This removes identity resolution as a precondition for logging: write to the player's log when the identity resolves, and to that id with whatever arrived (IP, claimed value, operation, client build) when it does not. The inability to resolve a user has to be a designed-for path from the start — an outdated client sends, by definition, what the server may no longer parse — with forward compatibility added later only if it proves feasible.

### Verdict — Round 2

**Not an approve and not a rejection: the work continues as a refactor.** r16384 stays on NPN as an intermediate state; it is not backported and does not ship on its own. The task's remaining substance moves into the login-flow refactor agreed on 2026-09-23.

On its own merits the rework is sound. Verified by diff reading, by tracing at r16384, and by re-reading branch HEAD (r16566, ~7 weeks later, unchanged): the guard now precedes `ValidateLoginInformation`, so no state is mutated before a refusal; the version arrives through the request contract instead of a manual `Convert.ToInt32`; the ProfileOperation guard sits inside `HandleProfileOperation` after the allowed-without-auth list, restoring the cheap `Unauthorized` for protected operations; `Diag` and `GetProtocolVersion` stay open; the five pre-auth sub-operations are untouched; wire codes are unchanged, so the shipped client stays compatible. The new `DbAssert` on `IsOnline` genuinely discriminates — a claim tested by checking that `ValidateUser(email, password)` calls `MarkLoggedIn`, which is what would make the old ordering fail it.

What the refactor has to carry forward:
- Identity resolution must be separated from effect application, so the version check can sit between them — early enough to leave no side effects, late enough to name the player.
- The per-player `sys` log entry for a mismatch is a requirement, not an optional extra; it is what diagnosed the 2026-09-22 support case. Where identity does not resolve, the entry goes to the dedicated `00000000-0000-0000-0000-000000000000` id with whatever the client sent. Unresolvable identity is a designed-for path, not an error.
- With identity available, the logged value should be a real identifier — today it is `external id "none"` on every Authenticate refusal, because the client never sends that parameter.
- `Validate` must stop writing anything: it answers, and at most returns context. That is the root cause behind the ordering problem, the claimed-email exemption and the lost attribution alike.
- Masking in the refusal message is expressed explicitly with `[[...]]`, not left to `PatternNumber2` catching digits after a space.
- A refused peer must not be able to keep issuing requests that cost the server anything — disconnect-after-delivery or mute, per R2-F5, with the client-reaction and delivery questions settled by a run.
- Once the refactor lands, it is backported to MFT for the `Next Server Hotfix`.

**Verification scope:** static analysis of the diff and of both branch states, plus production measurement over `Stats` on Steam, PlayStation and Mobile. Not performed: running the test suite; independent confirmation that Photon rejects rather than coerces a wrong-typed contract member (recorded on Codex's verification against the branch assemblies, see R2-F2); an event-level day-by-day curve from the Mongo `sysLog`, where a text scan times out on production — the SQL aggregates were used instead, and they report last-occurrence days rather than per-event history.
