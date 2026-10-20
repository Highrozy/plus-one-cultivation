# +1 Cultivation — Claude Code rules

Roblox xianxia cultivation incremental/simulator. Greybox prototype v0.1.
**`GameDesign.md` is the spec. Build exactly that, nothing more.**
Design context (decisions, parked ideas, open questions) lives in the Obsidian vault at
`C:\Users\lberr\OneDrive\Documents\+1 Cultivation`. Don't write to the vault unless asked.

## Workflow
- Rojo syncs `src/` into Studio (`rojo serve`). Code lives in files, never only in the place.
- One system at a time, in the spec's build order. After each system: tell the user what to
  test in Studio, wait for "it works" (or the red error text from Output), then `git commit`.
- Commit before any big change so it can be rolled back.

## Code rules
- **Server is authoritative.** Never trust the client for qi, currency, damage, rewards or
  targets. The client only sends intents ("clicked", "buy technique X", "breakthrough",
  "rebirth"); the server validates everything.
- **ModuleScripts with one job each** (ClickService, RealmService, BeastService, LootService,
  TechniqueService, RebirthService, MapBuilder, UI controllers). No giant scripts.
- **All tunable numbers live in `src/shared/Config.luau`** (qi rates, stage requirements,
  multipliers, beast HP/loot, technique costs/effects, click cap, spirit vein multiplier,
  rebirth multiplier). Display names (realms, techniques) live there too.
- **Greybox only:** plain colored parts, default fonts, no models, no Toolbox free models.
- **No data saving in v0.1** (on purpose).
- **Mobile first:** tap anywhere works; UI buttons big enough for phones.
- **No features outside the spec.** Suggest ideas to the user instead; they decide whether
  they go to Parked Ideas.

## Talking to the user
- Short, beginner-friendly explanations. They're learning as we go.
- If something breaks, ask for the exact red error text from Studio's Output window.

## Layout
- `src/server` → ServerScriptService.Server (`init.server.luau` boots the services)
- `src/client` → StarterPlayerScripts.Client (`init.client.luau` boots the controllers)
- `src/shared` → ReplicatedStorage.Shared (Config, Remotes, shared helpers)

## Notes
- `DebugService` exposes `ServerStorage.DebugCommand` in Studio only (give qi/currency/rebirths
  for testing). It does nothing on live servers.
- New Roblox avatars use `AnimationConstraint` joints, not `Motor6D`, and client scripts can't
  set joint `C0`. The punch animation writes `.Transform` in `PreSimulation` instead.
