--!strict
-- CombatService: punching beasts. Used by taps (ClickService) and by auto-combat,
-- which punches automatically whenever a beast is in range.
-- Damage = qi + fist technique bonuses; Heavy Strike makes every Nth punch bigger.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local BeastService = require(script.Parent.BeastService)
local LootService = require(script.Parent.LootService)

local CombatService = {}

local floatText: RemoteEvent
local punchFx: RemoteEvent
local nextAutoPunch: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Punch the nearest beast in range. Returns true if a beast was hit.
function CombatService.TryPunch(player: Player): boolean
	local data = PlayerData.Get(player)
	local rootPart = rootOf(player)
	if not data or not rootPart then
		return false
	end
	local beast = BeastService.FindNearest(rootPart.Position, Config.Combat.PunchRange)
	if not beast then
		return false
	end

	-- Any punch (tap or auto) pushes back the next auto-punch, so they never double up.
	nextAutoPunch[player] = os.clock() + Config.Combat.AutoPunchInterval

	local damage = Formulas.PunchDamage(data)
	data.PunchCount += 1
	local heavyLevel = data.Techniques.HeavyStrike or 0
	local heavy = Formulas.GetTechnique("HeavyStrike")
	local isHeavy = heavyLevel > 0 and data.PunchCount % heavy.EveryNthPunch == 0
	if isHeavy then
		damage *= Formulas.HeavyStrikeMultiplier(heavyLevel)
	end

	CombatService.Hit(player, beast, damage, if isHeavy then "Heavy" else "Damage")
	return true
end

-- Damage one beast for `player`: shows the number, and gives loot if it dies.
-- `kind` picks the damage number style ("Damage", "Heavy", "Skill").
function CombatService.Hit(player: Player, beast: BeastService.Beast, damage: number, kind: string)
	local position = beast.Body.Position + Vector3.new(0, beast.Body.Size.Y / 2 + 1, 0)
	floatText:FireClient(player, position, Format.Number(math.floor(damage)), kind)

	if BeastService.Damage(beast, damage) then
		LootService.Drop(player, beast.Tier, beast.Body.Position)
	end
end

function CombatService.Init()
	floatText = Remotes.Get("FloatText")
	punchFx = Remotes.Get("PunchFx")

	-- Auto-combat: punch for the player whenever a beast is close.
	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				if now >= (nextAutoPunch[player] or 0) and CombatService.TryPunch(player) then
					punchFx:FireAllClients(player)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		nextAutoPunch[player] = nil
	end)
end

return CombatService
