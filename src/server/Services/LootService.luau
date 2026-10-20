--!strict
-- LootService: gives spirit crystals + beast cores when a beast dies.
-- Loot is credited right away (auto-collected); the client just shows ores flying to you.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local LootService = {}

local lootFx: RemoteEvent

function LootService.Drop(player: Player, tier: number, position: Vector3)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local config = Config.Beasts[tier]
	data.Stones += config.Stones
	data.Cores += config.Cores
	PlayerData.Sync(player)
	lootFx:FireClient(player, position, config.Stones, config.Cores)
end

function LootService.Init()
	lootFx = Remotes.Get("LootFx")
end

return LootService
