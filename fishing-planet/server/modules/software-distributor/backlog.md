# software-distributor — Backlog

Findings from FP-43632. None of these block the GameCarrier migration; they are debt discovered while
reading the deployment mechanism.

- [ ] **Package layout: drop the nested archive and ship configs and actions inside the package.**
  `Build/Package.cmd` wraps `pack.7z` in a second archive purely to hide the file listing — 7-Zip does that
  natively with `-mhe=on`, so the extra pass costs build time and disk space for nothing. Extraction stays a
  single command either way, so keeping backward compatibility is cheap.
  Separately, a deployment is not one artefact but three, and only one of them is versioned. `Package.cmd`
  publishes `pack<N>.7z` to `C:\Shared\Pub`, `SoftwareDistributor/Configs/*` to `C:\Shared\Cfg` and
  `SoftwareDistributor/Actions/*` to `C:\Shared\Act`, wiping the two latter before copying. All three come from
  the same working copy of the same build — synchronous at build time, desynchronised immediately after,
  because only the archive carries a version.
  `Actions` matters most here because it is the executable half of a deployment: `*.Apply.cmd` are the scripts
  that unpack and install on the node. A mismatch there does not merely deploy stale settings, it breaks Apply
  — a newer script can invoke a tool the older package does not contain. r16246, which added
  `PerfCounterManager.exe` calls to the per-app Apply scripts, is exactly that shape of change.
  Consequences: redeploying an older package pairs it with current configs and current actions, and a rebuild
  for one platform overwrites both sets for every other platform. Shipping all three inside the package — or
  versioning them alongside it as `cfg<N>` / `act<N>` — restores the pairing.
  *Caveat:* configs and actions can currently be replaced by hand in the shares without a rebuild, and that
  path is in active use. A fix has to keep an override mechanism, or the loss of that workflow has to be
  accepted deliberately.

- [ ] **Collapse the near-duplicate production build configurations.** Separate scripts per platform are a
  leftover from when packaging genuinely differed. Today one script serves all F2P platforms and the survivors
  differ only in which SVN branch they build from. Worth folding into one configuration parameterised by
  branch, which would also make the package-number confusion above go away.

- [ ] **Verify and fix the synchronous file load in `Distributor.cs`.** The FP-43424 catalogue records a
  `.Result` call in the singleton constructor, blocking on a network filesystem. Not re-verified; confirm
  before acting.
