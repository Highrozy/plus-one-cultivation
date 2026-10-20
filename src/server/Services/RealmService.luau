--!strict
-- RealmService: adds qi and moves players up through realm stages.
-- Normal stage-ups are automatic. The major breakthrough (QC9 -> FE1) needs
-- the player to press the Breakthrough button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local RealmService = {}

local STAGE_QI = Config.Realms.StageQi
local MAJOR = Config.Realms.MajorBreakthroughStage

-- Advance through every stage the player's qi already covers (stops before the major breakthrough).
local function autoAdvance(data: PlayerData.Data)
	while data.Stage < Formulas.MaxStage() and data.Stage + 1 ~= MAJOR and data.Qi >= STAGE_QI[data.Stage + 1] do
		data.Stage += 1
	end
end

function RealmService.AddQi(player: Player, amount: number)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	data.Qi += amount
	autoAdvance(data)
	PlayerData.Sync(player)
end

function RealmService.CanBreakthrough(data: PlayerData.Data): boolean
	return data.Stage == MAJOR - 1 and data.Qi >= STAGE_QI[MAJOR]
end

function RealmService.Init()
	local tribulation = Remotes.Get("Tribulation")
	local strikes = Config.Tribulation
	local tribulationTime = strikes.FirstStrikeDelay + (strikes.Strikes - 1) * strikes.TimeBetweenStrikes + 0.3

	-- Major breakthrough: everyone sees the tribulation lightning, then the player reaches the new realm.
	Remotes.Get("Breakthrough").OnServerEvent:Connect(function(player)
		local data = PlayerData.Get(player)
		if not data or data.InTribulation or not RealmService.CanBreakthrough(data) then
			return
		end
		data.InTribulation = true
		player:SetAttribute("InTribulation", true)
		tribulation:FireAllClients(player)

		task.delay(tribulationTime, function()
			if PlayerData.Get(player) ~= data then
				return -- player left
			end
			data.InTribulation = false
			player:SetAttribute("InTribulation", false)
			data.Stage = MAJOR
			autoAdvance(data)
			PlayerData.Sync(player)
		end)
	end)
end

return RealmService
