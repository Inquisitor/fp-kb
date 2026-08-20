# Decision Log — build

## 2026-07-28 [CodeBranch r56720] Build failure now fails the Unity step itself

`serg` added `BuildScriptBase.ExitOnBuildFailure` — it returns early only on `BuildResult.Succeeded`, so `Failed`, `Cancelled`, `Unknown` and a null report all reach `EditorApplication.Exit(1)`. Wired into Xbox GDK dev/master, Xbox Series dev/master, UWP, GDK PC dev/master, PS4 SCEA dev/master and PS4 SCEE master. Commit message states the intent exactly: *fail the Unity build step instead of the next one when BuildPlayer reports failure*.

Nine entry points still carry the legacy inline handler (PS4 SCEE development, both PS4 patch builds, iOS, Steam, Steam development, both Nintendo builds, Epic), which exits non-zero only on `BuildResult.Failed` — `Cancelled` and `Unknown` still fall through to exit 0. Recorded by the client lead in FP-45257 as a follow-up candidate.

Relates: FP-45238 (Xbox build fails silently — the defect this fixes), FP-45257 (its PS4 SCEE clone).

## 2026-08-19 Finding: the fix is in CodeBranch only; console builds run from MainClient

`ExitOnBuildFailure` appears 10 times in CodeBranch `BuildScript.cs` and **zero times in MainClient**, while `XBoxProd` (and the other console configs) build the `MainClient` VCS root. The Code-role branch is therefore protected and the branch that actually ships is not — merge direction runs Content -> Code, so the fix only reaches MainClient with the next CodeBranch -> MainClient release merge.

Consequence, observed live in build #218 (2026-08-19): Unity's player build failed, Unity still exited 0, TeamCity kept step 7 green, and the failure surfaced two steps later as `Source folder not found: F:\Builds\GDK\Xbox\Package` — the exact "fails silently" behaviour FP-45238 describes, reproduced three weeks after it was fixed upstream.

Everything the pipeline signals inherits this: the `notifications` build feature (`buildFailed = true`, added to XBoxProd and UWPProd on 2026-07-29 to close FP-45238) only fires when TeamCity believes the build failed; the Slack step posts `Build load success` with revision and version whenever preceding steps stayed green; the ~300 MB artifact is published either way. In #218 the alarm rang only because step 2 wipes the output directory, so the missing `Package` folder tripped the upload step — an accident of ordering, not a check.

The remaining hole even after the merge lands: a failure occurring *after* packaging, or one producing a partial package, still passes the upload step. Only the exit code distinguishes those.
