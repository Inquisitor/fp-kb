# Log — Cache

## 2026-04-15 — Module created
Finding: pond config has a non-obvious pipeline (BaseConfigJson → SP → PondConfigurations → MultilingualPonds). Column-level settings like `UnlimitedBuoyRecolors` bypass JSON entirely via PondDto + MakeEqualTo(). Discovered during FP-43334 review.
