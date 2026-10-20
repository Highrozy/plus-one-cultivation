--!strict
-- ClickService: handles "I tapped" from the client. Every accepted tap gives qi
-- and punches the nearest beast in range (if the punch timer is ready).
-- Taps beyond Config.Click.MaxPerSecond are ignored (basic auto-clicker guard).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CombatService = require(script.Parent.CombatService)
local PlayerData = require(script.Parent.PlayerData)
local RealmService = require(script.Parent.RealmService)

local ClickService = {}

-- Taps can arrive bunched up because of network lag, so the server allows a
-- slightly longer window than the client's 1 second before counting them out.
local WINDOW = 1.1

local recentClicks: { [Player]: { number } } = {}

-- True if this tap fits inside the per-second limit.
local function allowClick(player: Player): boolean
	local now = os.clock()
	local times = recentClicks[player] or {}
	recentClicks[player] = times
	while times[1] and now - times[1] >= WINDOW do
		table.remove(times, 1)
	end
	if #times >= Config.Click.MaxPerSecond then
		return false
	end
	table.insert(times, now)
	return true
end

function ClickService.Init()
	Remotes.Get("Click").OnServerEvent:Connect(function(player)
		local data = PlayerData.Get(player)
		if not data or not allowClick(player) then
			return
		end
		RealmService.AddQi(player, Formulas.QiPerClick(data))
		CombatService.TryPunch(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		recentClicks[player] = nil
	end)
end

return ClickService
