# SPIKE: FP2 Project Structure Design
## Status: completed
## Executor: Inquisitor
## JIRA: (none — architectural spike)

## Summary
Design for FP2 (Fishing Planet 2) client project structure — Unity 6, HDRP.
Covers team structure (~20 people), repositories (fp2-client / fp2-art / fp2-packages on GitLab self-hosted),
asset architecture (hybrid: feature modules + shared scenes/art), art pipeline (WIP/Review/Export flow),
assembly definitions with dependency rules, CI/CD, and responsibility separation.

## Artifacts
- 2026-02-09-fp2-project-structure-design.md — full design (English)
- 2026-02-09-fp2-project-structure-summary.md — summary (Ukrainian)
- fp2-project-structure-feedback.md — feedback on design (Ukrainian)

## Decisions
- 2026-02-09: Tech Artist as gateway for asset pipeline (WIP -> Review -> Export flow)
- 2026-02-09: Two-repo split — fp2-client (dev) + fp2-art (art production), with UPM packages extracted when mature
- 2026-02-09: Zenject + SignalBus for DI and inter-module communication
- 2026-02-09: Hierarchical FSM for game state management
- 2026-02-09: Boot scene as Scene 0 + additive scenes (HUD/Weather/Audio) to reduce merge conflicts
- 2026-02-09: Assembly definitions with strict rules — FP2.Core has no deps, modules depend only on Core, .Editor assemblies separate
- 2026-02-09: Hybrid Assets/ folder — feature modules (Fishing/Environment/Character/Economy/UI/Audio) + _Core foundation
- 2026-02-16: Feedback identified risks — Git LFS vs UnityYAMLMerge policy conflict, UI/Resources memory risk, signal soup potential
- 2026-02-16: Recommended either merge-friendly (no LFS for scenes) or lock-first (LFS locking) approach, not both
- 2026-02-16: Recommended UI presentation contracts layer (FP2.PresentationContracts) to prevent tight coupling
