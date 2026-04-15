# Backlog — DAL

- [ ] Verify agent findings: write-path mappers `ExtractParamsFromDto()` / `ExtractParamsFromObject()` in `MsSqlHelper.cs`, asymmetric failure modes (silent read vs loud write)
- [ ] Investigate adding attribute-based column mapping to `RestoreObjectFromReader` (would simplify future renames)
- [ ] Document full list of DAL sub-providers (tournament, inventory, player, etc.)
- [ ] Document profile serialization: `SerializationHelper.JsonSerializerSettings` has no `StringEnumConverter` — enums persist as int in `Profiles.ProfileJson`. Map all serializer variants and their usage contexts
- [ ] Document `ObfuscateClientProfile()` — what gets stripped before sending to client, implications for new profile fields
