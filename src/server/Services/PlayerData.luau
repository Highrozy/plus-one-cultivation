--!strict
-- PlayerData: holds each player's progress in memory (no saving in v0.1)
-- and mirrors it onto Player attributes so the client can display it.
-- Only the server ever writes these values.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Data = {
	Qi: number,
	Stage: number,
	Stones: number,
	Cores: number,
	Rebirths: number,
	Techniques: { [string]: number },
	PunchCount: number, -- beast punches landed, for Heavy Strike
}

local PlayerData = {}

local dataByPlayer: { [Player]: Data } = {}

local function freshTechniques(): { [string]: number }
	local levels = {}
	for _, technique in Config.Techniques do
		levels[technique.Id] = 0
	end
	return levels
end

function PlayerData.Get(player: Player): Data?
	return dataByPlayer[player]
end

-- Push the current values to the player's attributes (what the client sees).
function PlayerData.Sync(player: Player)
	local data = dataByPlayer[player]
	if not data then
		return
	end
	player:SetAttribute("Qi", data.Qi)
	player:SetAttribute("Stage", data.Stage)
	player:SetAttribute("Stones", data.Stones)
	player:SetAttribute("Cores", data.Cores)
	player:SetAttribute("Rebirths", data.Rebirths)
	for id, level in data.Techniques do
		player:SetAttribute("Tech_" .. id, level)
	end
end

-- Reset everything a rebirth resets. Rebirth count is kept.
function PlayerData.ResetProgress(player: Player)
	local data = dataByPlayer[player]
	if not data then
		return
	end
	data.Qi = 0
	data.Stage = 1
	data.Stones = 0
	data.Cores = 0
	data.Techniques = freshTechniques()
	data.PunchCount = 0
end

function PlayerData.Init()
	local function onPlayerAdded(player: Player)
		dataByPlayer[player] = {
			Qi = 0,
			Stage = 1,
			Stones = 0,
			Cores = 0,
			Rebirths = 0,
			Techniques = freshTechniques(),
			PunchCount = 0,
		}
		PlayerData.Sync(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		dataByPlayer[player] = nil
	end)
end

return PlayerData
