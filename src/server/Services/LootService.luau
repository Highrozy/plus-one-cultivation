--!strict
-- LootService: rewards for killing a beast (placeholder design).
-- Spirit stones go straight to the killer. Beast cores drop as glowing balls
-- that only the killer can pick up by walking into them.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)

local LootService = {}

local function dropCore(owner: Player, ground: Vector3)
	local loot = Config.Loot
	local angle = math.random() * math.pi * 2
	local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.random() * loot.CoreScatter

	local core = Instance.new("Part")
	core.Name = "BeastCore"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.one * loot.CoreSize
	core.Color = loot.CoreColor
	core.Material = Enum.Material.Neon
	core.Anchored = true
	core.CanCollide = false
	core.Position = ground + offset + Vector3.new(0, loot.CoreSize / 2 + 0.5, 0)
	core.Parent = workspace

	local collected = false
	core.Touched:Connect(function(hit)
		if collected or Players:GetPlayerFromCharacter(hit.Parent) ~= owner then
			return
		end
		local data = PlayerData.Get(owner)
		if not data then
			return
		end
		collected = true
		data.BeastCores += 1
		PlayerData.Sync(owner)
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
