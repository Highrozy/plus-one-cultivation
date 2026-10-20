--!strict
-- Server entry point: starts every service in order.
-- Each service is a ModuleScript in Services/ with one job and an Init() function.

local Services = script.Services

local ORDER = {
	"MapBuilder", -- first: other services look for map parts
	"PlayerData",
	"RealmService",
	"BeastService",
	"LootService",
	"CombatService",
	"ClickService",
	"TrainingService",
	"TechniqueService",
	"RebirthService",
	"TagService",
	"DebugService", -- Studio-only test shortcuts
}

for _, name in ORDER do
	local service = require(Services:WaitForChild(name)) :: any
	service.Init()
end

print("[+1 Cultivation] Server started")
