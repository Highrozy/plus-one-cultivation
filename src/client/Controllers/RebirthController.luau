--!strict
-- RebirthController: the Rebirth button on the right side of the screen and its
-- "Are you sure?" popup. The popup shows the cost, what resets and the bonus you'd get.
-- Confirm only sends "rebirth"; the server checks the cost and does the reset.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local RebirthController = {}

local READY_COLOR = Color3.fromRGB(150, 70, 170)
local CONFIRM_COLOR = Color3.fromRGB(60, 140, 70)
local OFF_COLOR = Color3.fromRGB(80, 80, 90)

local function multiplierText(bonus: number): string
	return `x{string.format("%.2f", 1 + bonus)}`
end

function RebirthController.Init()
	local rebirthRemote = Remotes.Get("Rebirth")
	local screen = Ui.Screen("Rebirth", 4)

	-- Button + rebirth count, under the currency counters.
	local holder = Ui.New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0.5, 44),
		Size = UDim2.fromOffset(200, 90),
		Parent = screen,
	})
	local countLabel = Ui.Label({
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = holder,
	})
	local openButton = Ui.Button({
		Text = "Rebirth",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 30),
		Size = UDim2.fromOffset(150, 56),
		Parent = holder,
	})

	-- Confirm popup.
	local popup = Ui.New("Frame", {
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BackgroundTransparency = 0.1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.9, 0.6),
		Parent = screen,
	}, {
		Ui.Corner(14),
		Ui.New("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2 }),
		Ui.New("UISizeConstraint", { MaxSize = Vector2.new(480, 340) }),
	})
	Ui.Label({
		Text = "Rebirth?",
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 36),
		Parent = popup,
	})
	local lines = {}
	for index = 1, 5 do
		lines[index] = Ui.Label({
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Gotham,
			Position = UDim2.fromOffset(16, 52 + (index - 1) * 32),
			Size = UDim2.new(1, -32, 0, 26),
			Parent = popup,
		})
	end
	local confirmButton = Ui.Button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.new(0.6, -18, 0, 56),
		Parent = popup,
	})
	local cancelButton = Ui.Button({
		Text = "Cancel",
		BackgroundColor3 = Color3.fromRGB(160, 50, 50),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.new(0.4, -6, 0, 56),
		Parent = popup,
	})

	local canAfford = false

	Ui.OnStateChanged(function()
		local state = Ui.State()
		local cost = Formulas.RebirthCost(state)
		local gain = Formulas.RebirthGain(state)
		canAfford = state.SpiritStones >= cost

		countLabel.Text =
			`Rebirths: {state.Rebirths} ({multiplierText(state.RebirthBonus)} {Config.Names.Qi})`
		openButton.BackgroundColor3 = if canAfford then READY_COLOR else OFF_COLOR

		lines[1].Text = `Cost: {Format.Number(cost)} {Config.Names.SpiritStones} (you have {Format.Number(
			state.SpiritStones
		)})`
		lines[2].Text = `Resets: {Config.Names.Qi} and stage, back to {Formulas.StageName(1)}`
		lines[3].Text = "Keeps: stones, cores, manuals, upgrades"
		lines[4].Text =
			`Gain: +{Format.Number(gain * 100)}% {Config.Names.Qi} per tap (from {Formulas.StageName(
				state.Stage
			)})`
		lines[5].Text = `New total: {multiplierText(state.RebirthBonus + gain)} {Config.Names.Qi} per tap`

		confirmButton.Text = if canAfford then "Rebirth!" else `Need {Format.Number(cost)} Stones`
		confirmButton.BackgroundColor3 = if canAfford then CONFIRM_COLOR else OFF_COLOR
	end)

	openButton.Activated:Connect(function()
		popup.Visible = not popup.Visible
	end)
	cancelButton.Activated:Connect(function()
		popup.Visible = false
	end)
	confirmButton.Activated:Connect(function()
		if canAfford then
			rebirthRemote:FireServer()
			popup.Visible = false
		end
	end)
end

return RebirthController
