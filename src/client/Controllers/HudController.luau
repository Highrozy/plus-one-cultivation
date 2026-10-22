--!strict
-- HudController: the bar at the bottom of the screen. Shows the current realm stage
-- and how much qi is still needed for the next breakthrough.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Ui = require(script.Parent.Ui)

local HudController = {}

function HudController.Init()
	local screen = Ui.Screen("Hud", 1)

	local holder = Ui.New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0.6, 0, 0, 70),
		Parent = screen,
	}, {
		Ui.New("UISizeConstraint", { MaxSize = Vector2.new(600, math.huge) }),
	})

	local stageLabel = Ui.Label({
		Size = UDim2.new(1, 0, 0, 28),
		Parent = holder,
	})

	local bar = Ui.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BackgroundTransparency = 0.2,
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 34),
		Parent = holder,
	}, {
		Ui.Corner(12),
		Ui.New("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2 }),
	})
	local fill = Ui.New("Frame", {
		BackgroundColor3 = Config.QiPopup.Color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	}, {
		Ui.Corner(12),
	})
	local barText = Ui.Label({
		Size = UDim2.fromScale(1, 0.8),
		Position = UDim2.fromScale(0, 0.1),
		ZIndex = 2,
		Parent = bar,
	})

	-- Currency counters on the right side of the screen.
	local currencies = Ui.New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(200, 64),
		Parent = screen,
	}, {
		Ui.New("UIListLayout", { Padding = UDim.new(0, 4) }),
	})
	local stonesLabel = Ui.Label({
		Size = UDim2.new(1, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = currencies,
	})
	local coresLabel = Ui.Label({
		Size = UDim2.new(1, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Config.Loot.CoreColor,
		Parent = currencies,
	})

	Ui.OnStateChanged(function()
		local state = Ui.State()
		stageLabel.Text = Formulas.StageName(state.Stage)
		stonesLabel.Text = `{Config.Names.SpiritStones}: {Format.Number(state.SpiritStones)}`
		coresLabel.Text = `Pockets: {state.BeastCores}/{Formulas.CoreCap(state)}`

		local nextQi = Formulas.NextStageQi(state.Stage)
		local progress = 1
		if nextQi then
			local stageQi = Config.Realms.StageQi[state.Stage]
			progress = math.clamp((state.Qi - stageQi) / (nextQi - stageQi), 0, 1)
			barText.Text = `{Format.Number(state.Qi)} / {Format.Number(nextQi)} {Config.Names.Qi}`
		else
			barText.Text = `{Format.Number(state.Qi)} {Config.Names.Qi} (MAX)`
		end
		TweenService:Create(fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(progress, 1) }):Play()
	end)
end

return HudController
