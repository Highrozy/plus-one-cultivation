--!strict
-- PlayerData: holds each player's progress in memory (saving comes in a later system)
-- and mirrors it onto Player attributes so the client can display it.
-- Only the server ever writes these values.

local Players = game:GetService("Players")

export type Data = {
	Qi: number, -- total qi ever gathered (stage requirements are totals)
	Stage: number, -- 1 = Qi Condensation 1
}

local PlayerData = {}

local dataByPlayer: { [Player]: Data } = {}

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
end

function PlayerData.Reset(player: Player)
	dataByPlayer[player] = { Qi = 0, Stage = 1 }
	PlayerData.Sync(player)
end

function PlayerData.Init()
	Players.PlayerAdded:Connect(PlayerData.Reset)
	for _, player in Players:GetPlayers() do
		PlayerData.Reset(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		dataByPlayer[player] = nil
	end)
end

return PlayerData
