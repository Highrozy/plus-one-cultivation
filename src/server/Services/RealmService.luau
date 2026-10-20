--!strict
-- RealmService: adds qi and moves players up through realm stages.
-- Every breakthrough is automatic: as soon as qi reaches the next stage's requirement,
-- the player moves up (several stages at once if they have enough).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local PlayerData = require(script.Parent.PlayerData)

local RealmService = {}

local function autoAdvance(data: PlayerData.Data)
	local nextQi = Formulas.NextStageQi(data.Stage)
	while nextQi and data.Qi >= nextQi do
		data.Stage += 1
		nextQi = Formulas.NextStageQi(data.Stage)
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

function RealmService.Init() end

return RealmService
