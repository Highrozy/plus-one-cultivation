--!strict
-- LootFxController: when a beast dies, ores burst out of it and fly to you.
-- Blue crystals = spirit crystals, red chunks = beast cores. Purely visual:
-- the server already added the loot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)
local FloatTextController = require(script.Parent.FloatTextController)

local LootFxController = {}

local MAX_ORES_SHOWN = 6 -- per currency, so big drops don't spawn hundreds of parts

local function spawnOre(from: Vector3, color: Color3, size: number)
	local ore = Ui.New("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Material = Enum.Material.Neon,
		Color = color,
		Size = Vector3.one * size,
		CFrame = CFrame.new(from) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
		Parent = Workspace,
	})

	-- Pop out in a random direction...
	local burst = from + Vector3.new(math.random(-6, 6), math.random(3, 6), math.random(-6, 6))
	TweenService:Create(ore, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = burst }):Play()

	-- ...then fly to the player and vanish
	task.delay(0.45 + math.random() * 0.2, function()
		local character = Players.LocalPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			local fly = TweenService:Create(ore, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = rootPart.Position,
				Size = Vector3.one * 0.2,
			})
			fly:Play()
			fly.Completed:Wait()
		end
		ore:Destroy()
	end)
end

function LootFxController.Init()
	Remotes.Get("LootFx").OnClientEvent:Connect(function(position: Vector3, stones: number, cores: number)
		for _ = 1, math.min(stones, MAX_ORES_SHOWN) do
			spawnOre(position, Color3.fromRGB(80, 200, 255), 0.8)
		end
		for _ = 1, math.min(cores, MAX_ORES_SHOWN) do
			spawnOre(position, Color3.fromRGB(230, 60, 60), 0.9)
		end
		FloatTextController.Show(
			position + Vector3.new(0, 6, 0),
			`+{stones} {Config.Names.Stones}  +{cores} {Config.Names.Cores}`,
			"Loot"
		)
	end)
end

return LootFxController
