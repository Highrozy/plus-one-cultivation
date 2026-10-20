--!strict
-- FloatTextController: numbers that pop up in the world and float away
-- (damage numbers, Heavy Strike hits, "+qi" from training dummies, loot).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local FloatTextController = {}

local STYLES = {
	Damage = { Color = Color3.fromRGB(255, 255, 255), Size = 36 },
	Heavy = { Color = Color3.fromRGB(255, 80, 60), Size = 64 },
	Qi = { Color = Color3.fromRGB(120, 220, 255), Size = 30 },
	Loot = { Color = Color3.fromRGB(255, 220, 90), Size = 32 },
}

function FloatTextController.Show(position: Vector3, text: string, kind: string)
	local style = STYLES[kind] or STYLES.Damage

	-- An invisible anchor part to hang the text on
	local jitter = Vector3.new(math.random(-15, 15) / 10, 0, math.random(-15, 15) / 10)
	local anchor = Ui.New("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one * 0.1,
		Position = position + jitter,
		Parent = Workspace,
	})
	local gui = Ui.New("BillboardGui", {
		Size = UDim2.fromOffset(200, style.Size),
		AlwaysOnTop = true,
		MaxDistance = 150,
		Parent = anchor,
	})
	local label = Ui.Label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = style.Color,
		TextStrokeTransparency = 0,
		Parent = gui,
	})

	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { Position = anchor.Position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.9, function()
		anchor:Destroy()
	end)
end

function FloatTextController.Init()
	Remotes.Get("FloatText").OnClientEvent:Connect(FloatTextController.Show)
end

return FloatTextController
