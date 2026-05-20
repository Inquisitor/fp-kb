# equipment-rules -- backlog

## Research / documentation

- [ ] **Document `RodTemplates` test architecture.** `Shared/ObjectModel.Tests/RodTemplatesTests.cs` uses a `Block` / `BlockRow` declarative DSL: per-block `Existing = InitItems(...)` declares the universe, `blockX.CanMove(...)` declares the allow-set, and `_CantMove = Existing.Except(_CanMove)` is implicit negative-coverage. `Test_Compatibility_Core()` orchestrates. There are ~30+ `[TestMethod]` scenarios covering most templates -- but the coverage matrix is not documented anywhere. Needed: which (template x rod-subtype x slot) cells are tested vs not; which scenarios use `.Move(realItem)` to drive `ExpectedTemplate` vs leave the block dangling; where to add a new scenario when adding a template or restriction. Triggers from FP-43502: had to read the file end-to-end to find the 10 scenarios that needed the `monoLeader` allow-set update.

- [ ] **Map template -> restriction matrix.** Currently the relationship (template x leader-group, template x reel-group, ...) lives only in `RodTemplates.cs:307-372` as a flat list. A table or matrix in a deep dive would let a reader answer "which templates accept `SpinLeaders`?" without grepping. Useful when planning compatibility expansions.

- [ ] **Inventory the client parallel compatibility sources.** `ListOfCompatibility.cs` is the confirmed one. Spot-checked during FP-43502 deep review: `DollHighlightHint.cs`, `HintSystem.cs`, `MonoLeadersFilter` / `LeaderFilter` / `LineAndLeadersFilter` do **not** gate by rod x leader compatibility (subtype-identity or pure-category filters). Has not been exhaustively swept. If a future change touches compatibility, run a fresh grep for "rod x leader" hard-coded mappings client-side.

- [ ] **Document `IsPartial` template semantics.** `RodTemplates.Templates[]` has "complete" rows; `TemplatesPartial[]` has partial-match rows. `MatchedTemplate` vs `MatchedTemplatePartial` vs `MatchedLargestTemplatePartial` -- who consumes which (UI hints? mission progression? cast-validation?), and how does `IsPartial` interact with `MatchTemplate`'s nested full-template loop. Surfaced as adjacent context in FP-43502 but not load-bearing for that task.

- [ ] **Aggregation rules vs template restrictions -- division of responsibility.** `Rod.cs:CanAggregate` adds per-item-pair rules on top of template restrictions (e.g. `HeadStarterSinker` allowed only with reel/line/SpinLeader at L190; `TrollingSkirt` excludes sinkers/lures/non-skirt-hooks). When does a rule belong in template restrictions vs aggregation? Worth a short note in a deep dive.

## Open questions

- [ ] Is `SaltwaterMonoLeader` deliberately absent as a subtype, or just not yet introduced? FP-43502 worked around by extending freshwater `MonoLeader` cross-water; if a future content task introduces a SW variant, the SpinLeaders extension may need to split.
