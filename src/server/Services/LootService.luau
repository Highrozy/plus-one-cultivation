--!strict
-- LootService: rewards for killing a beast (placeholder design).
-- Spirit stones go straight to the killer (no cap). Beast cores always drop as pickups
-- that only the killer can collect, by holding the pickup prompt, up to their core cap.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local LootService = {}

-- The client uses this tag to hide other players' cores and show "Pockets full".
local CORE_TAG = "BeastCore"

-- The core mesh placed in ServerStorage by hand, or a plain ball if there isn't one.
local function newCorePart(): BasePart
	local template = ServerStorage:FindFirstChild("BeastCoreModel")
	if template and template:IsA("BasePart") then
		return template:Clone()
	end
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * Config.Loot.CoreSize
	ball.Color = Config.Loot.CoreColor
	ball.Material = Enum.Material.Neon
	return ball
end

local function dropCore(owner: Player, ground: Vector3)
	local loot = Config.Loot
	local angle = math.random() * math.pi * 2
	local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.random() * loot.CoreScatter

	local core = newCorePart()
	core.Name = "BeastCore"
	core.Anchored = true
	core.CanCollide = false
	core.Position = ground + offset + Vector3.new(0, core.Size.Y / 2 + 0.5, 0)
	core:SetAttribute("Owner", owner.UserId)
	CollectionService:AddTag(core, CORE_TAG)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = Config.Names.BeastCores
	prompt.HoldDuration = loot.CoreHoldDuration
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = core
	core.Parent = workspace

	prompt.Triggered:Connect(function(player)
		local data = PlayerData.Get(player)
		if player ~= owner or not data or not core.Parent then
			return
		end
		if data.BeastCores >= Formulas.CoreCap(data) then
			Remotes.Get("Notify"):FireClient(player, "Pockets full! Sell cores at the Manual Shop.")
			return
		end
		data.BeastCores += 1
		PlayerData.Sync(player)
		core:Destroy()
	end)
	Debris:AddItem(core, loot.CoreLifetime)
end

function LootService.Drop(killer: Player, info: Config.BeastInfo, ground: Vector3)
	local data = PlayerData.Get(killer)
	if not data then
		return
	end
	data.SpiritStones += info.SpiritStones
	PlayerData.Sync(killer)
	for _ = 1, info.BeastCores do
		dropCore(killer, ground)
	end
end

function LootService.Init() end

return LootService
