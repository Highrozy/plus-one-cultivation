--!strict
-- LootService: rewards for killing a beast (placeholder design).
-- Spirit stones go straight to the killer (no cap). Every beast drops one beast core as a
-- pickup that only the killer can collect, by holding the pickup prompt, up to their core cap.
-- The core's type comes from the beast; its grade is rolled when it drops, using the
-- killer's luck plus the beast's luck bonus.

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

-- The core mesh placed in ServerStorage by hand, or a plain ball if there isn't one,
-- in the grade's color.
local function newCorePart(color: Color3): BasePart
	local template = ServerStorage:FindFirstChild("BeastCoreModel")
	local core: BasePart
	if template and template:IsA("BasePart") then
		core = template:Clone()
		if core:IsA("MeshPart") then
			core.TextureID = "" -- so the color shows
		end
	else
		core = Instance.new("Part")
		core.Shape = Enum.PartType.Ball
		core.Size = Vector3.one * Config.Loot.CoreSize
		core.Material = Enum.Material.Neon
	end
	core.Color = color
	return core
end

local function dropCore(owner: Player, coreId: string, grade: number, ground: Vector3)
	local loot = Config.Loot
	local name = Formulas.CoreName(coreId, grade)
	local core = newCorePart(Config.CoreGrades[grade].Color)
	core.Name = "BeastCore"
	core.Anchored = true
	core.CanCollide = false
	core.Position = ground + Vector3.new(0, core.Size.Y / 2 + 0.5, 0)
	core:SetAttribute("Owner", owner.UserId)
	CollectionService:AddTag(core, CORE_TAG)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = name
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
			Remotes.Get("Notify"):FireClient(player, "Pockets full! Go back to the safe zone to store them.")
			return
		end
		PlayerData.AddCores(data, coreId, grade, 1)
		PlayerData.Sync(player)
		core:Destroy()
		local message = if grade >= Config.RareGrade then `Rare! {name}!` else `Picked up {name}`
		Remotes.Get("Notify"):FireClient(player, message)
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
	-- Every beast drops exactly one core.
	local grade = Formulas.RollGrade(Formulas.Luck(data, info.LuckBonus))
	dropCore(killer, info.Core, grade, ground)
end

function LootService.Init() end

return LootService
