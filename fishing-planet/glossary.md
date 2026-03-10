# Glossary — Fishing Planet

## General

| Term                   | Meaning                                                                                                                                                                                    | Notes                                                                                                  |
|------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| Carousel               | BiteSystem's fish selection mechanism (`FishSelector._carousel`) — builds weighted probability wheel from bite maps, weather, depth, attractors; rolls dice to select which fish generates | Primary meaning. Source=`B`. See [fish-generator card](server/modules/fish-generator/_card.md)         |
| FishGenerator Carousel | Legacy alternative fish selection in `FishGenerator.GenerateCarouselFishTemplate()` — Absolute (Source=`A`) and Active (Source=`C`)                                                        | Rarely used, lives inside FishBox path. Weight via `GameUtils.RandomizeFishWeight()`, not BiteSystem   |
| FishBox                | Legacy fish spawn system — predefined boxes with fish lists, conditions, cooldowns                                                                                                         | Ancient system, currently used only in missions. Mostly replaced by BiteSystem                         |
| BiteSystem             | Primary fish generation system — uses bite maps, weather layers, attractors to select and weigh fish                                                                                       | `Shared/BiteSystem/`. Weight via `FishDescription.GenerateRandomWeight()` → `GetPossibleNormalFloat()` |

## Matchmaking
| Term         | Code Name               | Notes                                          |
|--------------|-------------------------|------------------------------------------------|
| Bracket      | `TournamentBracket`     | Rating range definition (was: GroupSettings)   |
| Bucket       | `TournamentBucket`      | Group of players within a bracket (was: Group) |
| Group Budget | `AllocateGroupBudget()` | How many groups per bucket                     |
