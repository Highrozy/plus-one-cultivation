--!strict
-- PlayerData: holds each player's progress in memory (saving comes in a later system)
-- and mirrors it onto Player attributes so the client can display it.
-- Only the server ever writes these values.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Data = {
	Qi: number, -- total qi ever gathered (stage requirements are totals)
	Stage: number, -- 1 = Qi Condensation 1
	SpiritStones: number,
	BeastCores: number, -- total in pockets, all types and grades (always the sum of Cores)
	Cores: { [string]: { [number]: number } }, -- pockets: core id -> grade index -> count
	BagCores: number, -- total in the backpack (always the sum of Bag)
	Bag: { [string]: { [number]: number } }, -- backpack (no cap): core id -> grade index -> count
	Manuals: { [string]: boolean }, -- owned manual ids
	Upgrades: { [string]: number }, -- upgrade id -> level
	Rebirths: number,
	RebirthBonus: number, -- total qi-per-tap bonus from rebirths (1 = +100%)
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
	player:SetAttribute("SpiritStones", data.SpiritStones)
	player:SetAttribute("BeastCores", data.BeastCores)
	player:SetAttribute("BagCores", data.BagCores)
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("RebirthBonus", data.RebirthBonus)
	-- Manuals show up as "Manual_<id>" = true, upgrades as "Upgrade_<id>" = level.
	for id in Config.Manuals do
		player:SetAttribute(`Manual_{id}`, data.Manuals[id] == true)
	end
	for id in Config.Upgrades do
		player:SetAttribute(`Upgrade_{id}`, data.Upgrades[id] or 0)
	end
	-- Cores show up as "Core_<id>_<grade index>" = count (pockets)
	-- and "Bag_<id>_<grade index>" = count (backpack).
	for id in Config.Cores do
		local grades = data.Cores[id] or {}
		local bagGrades = data.Bag[id] or {}
		for grade in Config.CoreGrades do
			player:SetAttribute(`Core_{id}_{grade}`, grades[grade] or 0)
			player:SetAttribute(`Bag_{id}_{grade}`, bagGrades[grade] or 0)
		end
	end
end

-- Add (or remove, with a negative amount) cores of one type and grade to the pockets.
function PlayerData.AddCores(data: Data, id: string, grade: number, amount: number)
	local grades = data.Cores[id] or {}
	data.Cores[id] = grades
	grades[grade] = (grades[grade] or 0) + amount
	data.BeastCores += amount
end

-- Same, for the backpack.
function PlayerData.AddBagCores(data: Data, id: string, grade: number, amount: number)
	local grades = data.Bag[id] or {}
	data.Bag[id] = grades
	grades[grade] = (grades[grade] or 0) + amount
	data.BagCores += amount
end

-- Move everything in the pockets into the backpack. Returns how many cores moved.
function PlayerData.EmptyPockets(data: Data): number
	local moved = data.BeastCores
	for id, grades in data.Cores do
		for grade, count in grades do
			if count > 0 then
				PlayerData.AddBagCores(data, id, grade, count)
				PlayerData.AddCores(data, id, grade, -count)
			end
		end
	end
	return moved
end

function PlayerData.Reset(player: Player)
	dataByPlayer[player] = {
		Qi = 0,
		Stage = 1,
		SpiritStones = 0,
		BeastCores = 0,
		Cores = {},
		BagCores = 0,
		Bag = {},
		Manuals = {},
		Upgrades = {},
		Rebirths = 0,
		RebirthBonus = 0,
	}
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
