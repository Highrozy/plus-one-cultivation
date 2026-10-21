--!strict
-- RebirthService: spend spirit stones to reset qi and stage for a permanent qi-per-tap bonus.
-- Stones, cores, manuals and upgrades are kept. The cost and the bonus come from Formulas,
-- so the client's confirm popup shows exactly what the server will do.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local RebirthService = {}

function RebirthService.Init()
	local notify = Remotes.Get("Notify")

	Remotes.Get("Rebirth").OnServerEvent:Connect(function(player)
		local data = PlayerData.Get(player)
		if not data then
			return
		end
		local cost = Formulas.RebirthCost(data)
		if data.SpiritStones < cost then
			notify:FireClient(player, `Not enough {Config.Names.SpiritStones}`)
			return
		end
		local gain = Formulas.RebirthGain(data)
		data.SpiritStones -= cost
		data.RebirthBonus += gain
		data.Rebirths += 1
		data.Qi = 0
		data.Stage = 1
		PlayerData.Sync(player)
		notify:FireClient(player, `Rebirth {data.Rebirths}! +{Format.Number(gain * 100)}% {Config.Names.Qi}`)
	end)
end

return RebirthService
