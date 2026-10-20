--!strict
-- DebugService: Studio-only testing shortcuts (never active in a live server).
-- Lets test scripts fast-forward progress, e.g. give qi to reach rebirth quickly:
--   ServerStorage.DebugCommand:Invoke(player, "Qi", 30000)
-- Commands: "Qi", "Stones", "Cores", "Rebirths" (adds the amount), "Get" (returns data).

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local PlayerData = require(script.Parent.PlayerData)
local RealmService = require(script.Parent.RealmService)

local DebugService = {}

function DebugService.Init()
	if not RunService:IsStudio() then
		return
	end

	local command = Instance.new("BindableFunction")
	command.Name = "DebugCommand"
	command.OnInvoke = function(player: Player, name: string, amount: number?)
		local data = PlayerData.Get(player)
		if not data then
			return nil
		end
		if name == "Qi" then
			RealmService.AddQi(player, amount or 0)
		elseif name == "Stones" then
			data.Stones += amount or 0
		elseif name == "Cores" then
			data.Cores += amount or 0
		elseif name == "Rebirths" then
			data.Rebirths += amount or 0
		end
		PlayerData.Sync(player)
		return table.clone(data)
	end
	command.Parent = ServerStorage
end

return DebugService
