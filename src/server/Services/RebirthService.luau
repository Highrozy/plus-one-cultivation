--!strict
-- RebirthService: at the final stage, the player can rebirth.
-- Resets qi, stage, currencies and techniques; keeps (and adds to) the rebirth count,
-- which permanently multiplies qi gain and unlocks better training platforms.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local RebirthService = {}

function RebirthService.Init()
	Remotes.Get("Rebirth").OnServerEvent:Connect(function(player)
		local data = PlayerData.Get(player)
		if not data or data.Stage < Formulas.MaxStage() then
			return
		end
		PlayerData.ResetProgress(player)
		data.Rebirths += 1
		PlayerData.Sync(player)
	end)
end

return RebirthService
