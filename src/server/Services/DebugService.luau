--!strict
-- DebugService: Studio-only test shortcuts sent from the DEV panel.
-- Does nothing on live servers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local RealmService = require(script.Parent.RealmService)

local DebugService = {}

local COMMANDS: { [string]: (Player, PlayerData.Data) -> () } = {
	-- Jump straight to the next stage.
	NextStage = function(player, data)
		local nextQi = Formulas.NextStageQi(data.Stage)
		if nextQi then
			RealmService.AddQi(player, nextQi - data.Qi)
		end
	end,
	Reset = function(player)
		PlayerData.Reset(player)
	end,
}

function DebugService.Init()
	if not RunService:IsStudio() then
		return
	end
	Remotes.Get("DevCommand").OnServerEvent:Connect(function(player, name)
		local data = PlayerData.Get(player)
		local command = COMMANDS[name]
		if data and command then
			command(player, data)
		end
	end)
end

return DebugService
