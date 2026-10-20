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
	Remotes.Get("Breakthrough").OnServerEvent:Connect(function(player)
		local data = PlayerData.Get(player)
		if not data or not RealmService.CanBreakthrough(data) then
			return
		end
		data.Stage = MAJOR
		autoAdvance(data)
		PlayerData.Sync(player)
	end)
end

return RealmService
