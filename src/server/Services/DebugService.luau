--!strict
-- DebugService: Studio-only test shortcuts sent from the DEV panel.
-- Does nothing on live servers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BeastService = require(script.Parent.BeastService)
local PlayerData = require(script.Parent.PlayerData)
local RealmService = require(script.Parent.RealmService)

local DebugService = {}

local SPAWN_DISTANCE = 12 -- studs in front of the player

local COMMANDS: { [string]: (Player, PlayerData.Data, any) -> () } = {
	-- Spawn a beast in front of the player (no respawn).
	SpawnBeast = function(player, _, id)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and typeof(id) == "string" and Config.Beasts[id] then
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			local ground = root.Position - Vector3.new(0, 3, 0)
			BeastService.Spawn(id, ground + look.Unit * SPAWN_DISTANCE)
		end
	end,
	ClearBeasts = function()
		BeastService.ClearAll()
	end,
	-- Jump straight to the next stage.
	NextStage = function(player, data)
		local nextQi = Formulas.NextStageQi(data.Stage)
		if nextQi then
			RealmService.AddQi(player, nextQi - data.Qi)
		end
	end,
	AddStones = function(player, data)
		data.SpiritStones += 100
		PlayerData.Sync(player)
	end,
	-- Count one more rebirth without resetting or bonus (for testing pad unlocks).
	AddRebirth = function(player, data)
		data.Rebirths += 1
		PlayerData.Sync(player)
	end,
	-- Put 5 random cores (rolled like real drops, any zone's type) into the pockets, ignoring the cap.
	AddCores = function(player, data)
		for _ = 1, 5 do
			local id = Config.CoreOrder[math.random(#Config.CoreOrder)]
			PlayerData.AddCores(data, id, Formulas.RollGrade(Formulas.Luck(data)), 1)
		end
		PlayerData.Sync(player)
	end,
	-- Consume one pill for its qi (stand-in until the seclusion cave exists).
	-- arg: { Tier = n, Failed = bool }
	EatPill = function(player, data, which)
		if typeof(which) ~= "table" or typeof(which.Tier) ~= "number" or not Config.Pills[which.Tier] then
			return
		end
		local failed = which.Failed == true
		local pills = if failed then data.FailedPills else data.Pills
		if (pills[which.Tier] or 0) <= 0 then
			return
		end
		PlayerData.AddPills(data, which.Tier, failed, -1)
		RealmService.AddQi(player, Formulas.PillQi(which.Tier, failed))
	end,
	Reset = function(player)
		PlayerData.Reset(player)
	end,
}

function DebugService.Init()
	if not RunService:IsStudio() then
		return
	end
	Remotes.Get("DevCommand").OnServerEvent:Connect(function(player, name, arg)
		local data = PlayerData.Get(player)
		local command = COMMANDS[name]
		if data and command then
			command(player, data, arg)
		end
	end)
end

return DebugService
