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
