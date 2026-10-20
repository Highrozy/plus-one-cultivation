--!strict
-- CombatService: players punching beasts, and player max health.
-- A tap punches the nearest beast in range, and auto-punch does the same without
-- tapping. Both share one timer, so punches never exceed Config.Combat.PunchesPerSecond.
-- Taps already give qi (ClickService); auto punches give the same qi per punch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local BeastService = require(script.Parent.BeastService)
local PlayerData = require(script.Parent.PlayerData)
local RealmService = require(script.Parent.RealmService)

local CombatService = {}

local lastPunch: { [Player]: number } = {}

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Punch the nearest beast in range if the punch timer is ready. Returns true if it punched.
-- giveQi: also gives qi per tap first (for auto punches; taps already gave it).
function CombatService.TryPunch(player: Player, giveQi: boolean?): boolean
	local data = PlayerData.Get(player)
	local root = aliveRoot(player)
	if not data or not root then
		return false
	end
	local now = os.clock()
	if now - (lastPunch[player] or 0) < 1 / Config.Combat.PunchesPerSecond then
		return false
	end
	local beast = BeastService.FindNearest(root.Position, Config.Combat.PunchRange)
	if not beast then
		return false
	end
	lastPunch[player] = now
	if giveQi then
		RealmService.AddQi(player, Formulas.QiPerClick(data))
	end
	BeastService.Damage(beast, Formulas.PunchDamage(data), player)
	return true
end

-- Set max health from the player's stage, keeping the same health percentage.
local function applyMaxHealth(player: Player, refill: boolean)
	local data = PlayerData.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid or humanoid.Health <= 0 then
		return
	end
	local ratio = if refill then 1 else humanoid.Health / humanoid.MaxHealth
	humanoid.MaxHealth = Formulas.MaxHealth(data.Stage)
	humanoid.Health = humanoid.MaxHealth * ratio
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		applyMaxHealth(player, true)
	end)
	player:GetAttributeChangedSignal("Stage"):Connect(function()
		applyMaxHealth(player, false)
	end)
	if player.Character then
		applyMaxHealth(player, true)
	end
end

function CombatService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastPunch[player] = nil
	end)

	if Config.Combat.AutoPunch then
		RunService.Heartbeat:Connect(function()
			for _, player in Players:GetPlayers() do
				CombatService.TryPunch(player, true)
			end
		end)
	end
end

return CombatService
