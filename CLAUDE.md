# +1 Cultivation — Claude Code rules

Roblox xianxia cultivation incremental/simulator, **v0.2** (clean-slate rebuild).
The v0.1 prototype is saved under git tag `prototype-v0.1` and in
`C:\Users\lberr\Projects\_archive\plus-one-cultivation-prototype-v0.1` (never run Rojo there).
Design context (decisions, parked ideas, open questions) lives in the Obsidian vault at
`C:\Users\lberr\OneDrive\Documents\+1 Cultivation`. Don't write to the vault unless asked.

## v0.2 approach
- **Systems first, map later.** Systems must not depend on the map. They find
  CollectionService-tagged marker parts (training spots, beast spawns, shop, portals),
  so any map works.
- Build one system at a time, chosen together with the user.

## Workflow
- Rojo syncs `src/` into Studio (`rojo serve`). Code lives in files, never only in the place.
- After each system: tell the user what to test in Studio, wait for "it works" (or the red
  error text from Output), then `git commit`.
- Commit before any big change so it can be rolled back.

## Code rules
- **Server is authoritative.** Never trust the client for qi, currency, damage, rewards or
  targets. The client only sends intents ("clicked", "buy X"); the server validates everything.
- **ModuleScripts with one job each.** Services in `src/server/Services`, controllers in
  `src/client/Controllers`, each with an `Init()` listed in the entry script's ORDER.
- **All tunable numbers and display names live in `src/shared/Config.luau`.**
  Game math lives in `src/shared/Formulas.luau` (shared so the client can display it).
- **Greybox only:** plain parts, default fonts, no Toolbox free models.
- **Mobile first:** tap anywhere works; UI buttons big enough for phones.
- **No features the user didn't ask for.** Suggest ideas instead.

## Talking to the user
- Short, beginner-friendly, click-by-click explanations. They're learning as we go.
- If something breaks, ask for the exact red error text from Studio's Output window.

## Layout
- `src/server` → ServerScriptService.Server (`init.server.luau` boots the services)
- `src/client` → StarterPlayerScripts.Client (`init.client.luau` boots the controllers)
- `src/shared` → ReplicatedStorage.Shared (Config, Formulas, Remotes, Format)
- Rojo does not touch Workspace or Lighting, so the map can be built by hand in Studio.

## Notes
- `DebugService` / `DevPanelController` give Studio-only test buttons. They do nothing live.
- Rojo must be running and connected, and a playtest must be restarted after code changes.
