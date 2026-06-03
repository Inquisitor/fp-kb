# Personal Offers config — TDD parameter tables (working artifact, FP-44184)

Ready-to-paste replacements for the unformatted bullet lists in the TDD ("Personal Offers - Server Technical Design", `/wiki/x/LYCl5Q`, section **Additional TA properties**). Parameter names are canonical = C# property in `TargetedAdConfig` / `TargetedAd` (`Shared/ObjectModel/Monetization/TargetedAd.cs`) = JSON config key. Types are C# types (`?` = nullable); durations are in hours.

## Offer lifetime settings

| Parameter                                 | Type           | Default | Note                                                                                                                   |
|-------------------------------------------|----------------|---------|------------------------------------------------------------------------------------------------------------------------|
| `PersonalOffersChainTimeoutHours`         | `float?` hours | none    | Whole offer/chain lifetime (incl. intervals). If unset, the offer is unlimited and lives while its conditions are met. |
| `PersonalOffersChainPreserveTimeoutHours` | `float?` hours | 0       | Keeps an unlimited offer alive this many hours after its conditions become unmet. 0 = invalidated immediately.         |

## Chain scheduling properties

| Parameter                               | Type                  | Default       | Note                                                                                                                                             |
|-----------------------------------------|-----------------------|---------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| `PersonalOffersElementShowTimeoutHours` | `float?` hours        | none          | Show duration of one chain element; drives the client timer. If unset, no fixed per-element duration — the offer is bound by the campaign `End`. |
| `PersonalOffersElementCooldownHours`    | `float?` hours        | 0             | Pause between chain elements. 0 = no pause.                                                                                                      |
| `PersonalOffersChainRerunTimeoutHours`  | `float?` hours        | 0 (immediate) | Pause before restarting the chain after the last element. Negative = no rerun.                                                                   |
| `PersonalOffersExcludeBought`           | `bool?`               | false         | Skip chain elements whose product the player already owns.                                                                                       |
| `Designs`                               | `AdDesignReference[]` | none          | The chain itself: ordered designs, each with a `DesignId`. JSON: `"Designs": [{ "DesignId": ... }]`.                                             |

## Existing TA properties reused

| Parameter       | Type        | Default | Note                                                                                        |
|-----------------|-------------|---------|---------------------------------------------------------------------------------------------|
| `IsActive`      | `bool`      | —       | Offer on/off.                                                                               |
| `Start` / `End` | `DateTime?` | —       | Offer activity period (campaign window). `End` is the hard upper bound for any offer timer. |
| `OrderId`       | `int?`      | —       | Display ordering / priority.                                                                |

## Global Variables

GlobalVariables config keys (key = property name in `GlobalVariablesCache`, `Shared/SharedLib/Config/GlobalVariablesCache.cs`). Old TDD names: `NumberOfShowsPerDay` -> `NumberOfPersonalOfferShowsPerDay`; `NumberOfActiveOffers` -> `NumberOfActivePersonalOffers`.

| Parameter                          | Type  | Default | Note                                                                                                                                                                                                                                                                                                       |
|------------------------------------|-------|---------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `NumberOfPersonalOfferShowsPerDay` | `int` | —       | Intended max offers shown per day. **Not implemented and likely unnecessary** — declared in `GlobalVariablesCache` but has no consumer in code, and absent from the GD design (neither "1st iteration" nor the parent concept doc). To be removed during a future `TargetedAdsManager` cleanup (FP-32370). |
| `NumberOfActivePersonalOffers`     | `int` | —       | Max number of simultaneously active offers. Code blocks a new offer once the active count reaches this value (dev: 20).                                                                                                                                                                                    |

## Old TDD name -> canonical (for the rename)

| Old TDD name            | Canonical                                 |
|-------------------------|-------------------------------------------|
| OfferTimeout            | `PersonalOffersChainTimeoutHours`         |
| OfferPreserveTimeout    | `PersonalOffersChainPreserveTimeoutHours` |
| ChainElementShowTimeout | `PersonalOffersElementShowTimeoutHours`   |
| ChainElementCooldown    | `PersonalOffersElementCooldownHours`      |
| ChainRerunTimeout       | `PersonalOffersChainRerunTimeoutHours`    |
| ExcludeBoughtProduct    | `PersonalOffersExcludeBought`             |
| Chain (int[] DesignIds) | `Designs` (`AdDesignReference[]`)         |

> FP-44184: `PersonalOffersElementShowTimeoutHours` no longer defaults to 1h (was "Default 1" in the TDD). Unset now means no per-element duration; the offer runs until the campaign `End`.
