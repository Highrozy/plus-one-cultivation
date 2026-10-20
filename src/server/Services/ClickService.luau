--!strict
-- ClickService: handles "I tapped" from the client.
-- Every accepted tap gives qi and also punches the nearest beast in range.
-- Taps beyond Config.Click.MaxPerSecond are ignored (basic auto-clicker guard).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local RealmService = require(script.Parent.RealmService)
local CombatService = require(script.Parent.CombatService)

local ClickService = {}

local recentClicks: { [Player]: { number } } = {}

-- True if this tap fits inside the per-second limit.
local function allowClick(player: Player): boolean
	local now = os.clock()
	local times = recentClicks[player] or {}
	recentClicks[player] = times
	while times[1] and now - times[1] >= 1 do
		table.remove(times, 1)
	end
	if #times >= Config.Click.MaxPerSecond then
		return false
	end
	table.insert(times, now)
	return true
end

function ClickService.Init()
	local punchFx = Remotes.Get("PunchFx")

	Remotes.Get("Click").OnServerEvent:Connect(function(player)
		local data = PlayerData.Get(player)
		if not data or not allowClick(player) then
			return
		end
		RealmService.AddQi(player, Formulas.QiPerClick(data))
		punchFx:FireAllClients(player)
		CombatService.TryPunch(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		recentClicks[player] = nil
	end)
end

return ClickService
