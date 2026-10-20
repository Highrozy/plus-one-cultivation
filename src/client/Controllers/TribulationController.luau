--!strict
-- TribulationController: the heavens' answer to a major breakthrough.
-- The sky darkens and lightning strikes the player several times. Every player in the
-- lobby sees it (the server sends Tribulation(player) to everyone).

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local TribulationController = {}

local BOLT_COLOR = Color3.fromRGB(200, 220, 255)
local active = 0 -- how many tribulations are happening right now (the sky stays dark until all end)
local darkness: ColorCorrectionEffect

-- A jagged bolt of neon segments from the sky down to `target`.
local function bolt(target: Vector3)
	local top = target + Vector3.new(math.random(-12, 12), 90, math.random(-12, 12))
	local segments = 10
	local points = { top }
	for i = 1, segments - 1 do
		local p = top:Lerp(target, i / segments)
		table.insert(points, p + Vector3.new(math.random(-30, 30) / 10, 0, math.random(-30, 30) / 10))
	end
	table.insert(points, target)

	local parts = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local part = Ui.New("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.Neon,
			Color = BOLT_COLOR,
			Size = Vector3.new(0.7, 0.7, (b - a).Magnitude),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Parent = Workspace,
		})
		table.insert(parts, part)
	end
	Ui.New("PointLight", { Color = BOLT_COLOR, Brightness = 8, Range = 40, Parent = parts[#parts] })

	-- Impact flash on the ground
	local flash = Ui.New("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Material = Enum.Material.Neon,
		Color = BOLT_COLOR,
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3,
		Position = target,
		Parent = Workspace,
	})
	TweenService:Create(flash, TweenInfo.new(0.4), { Size = Vector3.one * 12, Transparency = 1 }):Play()

	-- Brighten the whole screen for a moment
	darkness.Brightness = 0.5
	TweenService:Create(darkness, TweenInfo.new(0.25), { Brightness = -0.25 }):Play()

	task.delay(0.18, function()
		for _, part in parts do
			part:Destroy()
		end
	end)
	task.delay(0.4, function()
		flash:Destroy()
	end)
end

local function run(player: Player)
	active += 1
	TweenService:Create(darkness, TweenInfo.new(0.6), {
		Brightness = -0.25,
		Contrast = 0.2,
		Saturation = -0.4,
		TintColor = Color3.fromRGB(170, 160, 220),
	}):Play()

	local settings = Config.Tribulation
	task.wait(settings.FirstStrikeDelay)
	for strike = 1, settings.Strikes do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			bolt(rootPart.Position - Vector3.new(0, 2.5, 0))
			if player == Players.LocalPlayer then
				Ui.ShakeCamera(1.5, 0.35)
			end
		end
		if strike < settings.Strikes then
			task.wait(settings.TimeBetweenStrikes)
		end
	end

	task.wait(0.6)
	active -= 1
	if active == 0 then
		TweenService:Create(darkness, TweenInfo.new(1), {
			Brightness = 0,
			Contrast = 0,
			Saturation = 0,
			TintColor = Color3.new(1, 1, 1),
		}):Play()
	end
end

function TribulationController.Init()
	darkness = Ui.New("ColorCorrectionEffect", { Name = "TribulationSky", Parent = Lighting })
	Remotes.Get("Tribulation").OnClientEvent:Connect(function(player: Player)
		task.spawn(run, player)
	end)
end

return TribulationController
