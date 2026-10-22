--!strict
-- BrewController: the brewing minigame (rules and numbers in Config.Alchemy and Config.Pills).
-- A ring of dots: green dots are the flow, which moves clockwise at changing speeds; white
-- dots are your tab. Hold Space (or the HOLD button) to push your tab clockwise; let go and it
-- falls back counter-clockwise. The bar fills while your tab's center is on the flow and
-- drains while it's off. Full bar = won, empty bar (or X) = lost.
-- Angles are in degrees, 0 = top of the ring, growing clockwise.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)

local BrewController = {}

local DOT_COUNT = 72 -- one dot every 5 degrees
local RING_RADIUS = 0.42 -- fraction of the ring frame
local HOLD_ACTION = "BrewHold"

local OFF_COLOR = Color3.fromRGB(60, 60, 70)
local FLOW_COLOR = Color3.fromRGB(80, 220, 120)
local TAB_COLOR = Color3.fromRGB(255, 255, 255)
local ON_COLOR = Color3.fromRGB(255, 230, 80) -- tab dots that are inside the flow

local panel: Frame
local dots: { Frame } = {}
local barFill: Frame
local titleLabel: TextLabel
local holdButton: TextButton
local closeButton: TextButton

local running = false
local holding = false

-- Shortest signed difference between two angles, in -180..180.
local function angleDiff(a: number, b: number): number
	return (a - b + 180) % 360 - 180
end

local function buildPanel()
	local screen = Ui.Screen("Brew", 8)
	panel = Ui.New("Frame", {
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BackgroundTransparency = 0.1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(360, 440),
		Parent = screen,
	}, {
		Ui.Corner(14),
		Ui.New("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2 }),
	})
	titleLabel = Ui.Label({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -80, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	closeButton = Ui.Button({
		Text = "X",
		BackgroundColor3 = Color3.fromRGB(160, 50, 50),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(48, 40),
		Parent = panel,
	})

	local ring = Ui.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.fromOffset(280, 280),
		Parent = panel,
	})
	for index = 1, DOT_COUNT do
		local angle = math.rad((index - 1) * 360 / DOT_COUNT)
		dots[index] = Ui.New("Frame", {
			BackgroundColor3 = OFF_COLOR,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(
				0.5 + RING_RADIUS * math.sin(angle),
				0.5 - RING_RADIUS * math.cos(angle)
			),
			Size = UDim2.fromOffset(12, 12),
			Parent = ring,
		}, { Ui.Corner(6) })
	end

	-- Progress bar on the right, filling upwards.
	local bar = Ui.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		Position = UDim2.fromOffset(310, 62),
		Size = UDim2.fromOffset(32, 260),
		Parent = panel,
	}, { Ui.Corner(8) })
	barFill = Ui.New("Frame", {
		BackgroundColor3 = FLOW_COLOR,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		Parent = bar,
	}, { Ui.Corner(8) })

	holdButton = Ui.Button({
		Text = "HOLD (Space)",
		BackgroundColor3 = Color3.fromRGB(70, 90, 150),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -24, 0, 80),
		Parent = panel,
	})
	holdButton.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			holding = true
		end
	end)
	holdButton.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			holding = false
		end
	end)
end

-- Runs the minigame for this pill tier, then calls onDone(won).
function BrewController.Start(tier: number, onDone: (boolean) -> ())
	if running then
		return
	end
	running = true
	holding = false
	panel.Visible = true

	local alchemy = Config.Alchemy
	local pill = Config.Pills[tier]
	local speedRange = pill.FlowSpeed
	local function randomIn(range: NumberRange): number
		return range.Min + math.random() * (range.Max - range.Min)
	end

	local flowAngle = 0
	local flowSpeed = randomIn(speedRange)
	local targetSpeed = flowSpeed
	local nextSpeedChange = if pill.SpeedChangeTime then randomIn(pill.SpeedChangeTime) else math.huge
	local tabAngle = 0 -- start on the flow
	local tabSpeed = 0
	local progress = alchemy.BarStart
	local elapsed = 0

	-- Space pushes the tab; sinking it stops the character from jumping meanwhile.
	ContextActionService:BindActionAtPriority(HOLD_ACTION, function(_, state)
		holding = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space)

	local connection: RBXScriptConnection
	local closeConnection: RBXScriptConnection
	local function stop(won: boolean)
		if not running then
			return
		end
		running = false
		holding = false
		connection:Disconnect()
		closeConnection:Disconnect()
		ContextActionService:UnbindAction(HOLD_ACTION)
		panel.Visible = false
		onDone(won)
	end
	closeConnection = closeButton.Activated:Connect(function()
		stop(false)
	end)

	connection = RunService.RenderStepped:Connect(function(dt)
		-- Auto-follow: for the first AutoFollowTime seconds the tab rides the flow by itself
		-- and the bar doesn't move. Then the warm-up: everything runs at WarmupStart x
		-- normal, building up to normal over WarmupTime seconds.
		elapsed += dt
		local autoFollow = elapsed < alchemy.AutoFollowTime
		titleLabel.Text = if autoFollow then "Get ready..." else "Follow the flow!"
		local warmup = math.clamp((elapsed - alchemy.AutoFollowTime) / alchemy.WarmupTime, 0, 1)
		local pace = alchemy.WarmupStart + (1 - alchemy.WarmupStart) * warmup

		-- Flow: moves clockwise. Stronger pills pick a new target speed more often;
		-- the flow eases towards it instead of jumping.
		if pill.SpeedChangeTime and warmup >= 1 then
			nextSpeedChange -= dt
			if nextSpeedChange <= 0 then
				targetSpeed = randomIn(speedRange)
				nextSpeedChange = randomIn(pill.SpeedChangeTime)
			end
		end
		flowSpeed += (targetSpeed - flowSpeed) * math.min(alchemy.SpeedEasing * dt, 1)
		flowAngle = (flowAngle + flowSpeed * pace * dt) % 360

		-- Tab: pushed clockwise while holding, falls back counter-clockwise otherwise.
		if autoFollow then
			tabAngle = flowAngle
			tabSpeed = flowSpeed * pace -- so it carries on smoothly when the player takes over
		else
			local push = if holding then alchemy.HoldAcceleration else -alchemy.FallAcceleration
			local maxSpeed = alchemy.MaxTabSpeed * pace
			tabSpeed = math.clamp(tabSpeed + push * pace * dt, -maxSpeed, maxSpeed)
			tabAngle = (tabAngle + tabSpeed * dt) % 360
		end

		-- Bar.
		local onFlow = math.abs(angleDiff(tabAngle, flowAngle)) <= pill.FlowSize / 2
		if not autoFollow then
			progress += (if onFlow then alchemy.BarFill else -alchemy.BarDrain) * pace * dt
		end
		barFill.Size = UDim2.fromScale(1, math.clamp(progress, 0, 1))
		barFill.BackgroundColor3 = if onFlow then FLOW_COLOR else Color3.fromRGB(220, 90, 70)

		-- Ring dots.
		for index, dot in dots do
			local angle = (index - 1) * 360 / DOT_COUNT
			local inFlow = math.abs(angleDiff(angle, flowAngle)) <= pill.FlowSize / 2
			local inTab = math.abs(angleDiff(angle, tabAngle)) <= alchemy.TabSize / 2
			dot.BackgroundColor3 = if inTab and inFlow
				then ON_COLOR
				elseif inTab then TAB_COLOR
				elseif inFlow then FLOW_COLOR
				else OFF_COLOR
		end

		if progress >= 1 then
			stop(true)
		elseif progress <= 0 then
			stop(false)
		end
	end)
end

function BrewController.Init()
	buildPanel()
end

return BrewController
