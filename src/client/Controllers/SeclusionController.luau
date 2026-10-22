--!strict
-- SeclusionController: meditating in the seclusion cave (rules in Config.Seclusion).
-- Stepping onto a seclusion pad asks the server to start; the server floats the character.
-- This side does the rest: a sitting pose (placeholder for the cross-legged float), a camera
-- facing the character, the pill list on the left with Consume buttons, the absorb bar,
-- and particles flowing into the dantian. Leave (or dying) ends it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local QiPopupController = require(script.Parent.QiPopupController)
local Ui = require(script.Parent.Ui)

local SeclusionController = {}

local CHECK_INTERVAL = 0.2 -- seconds between "am I on a pad?" checks
local ON_COLOR = Color3.fromRGB(60, 140, 70)
local OFF_COLOR = Color3.fromRGB(80, 80, 90)
local PASSIVE_COLOR = Color3.fromRGB(220, 230, 255)
local AURA_SIZE = 9 -- studs across the ball the energy flows in from
local DANTIAN_DROP = 0.8 -- studs below the root part where the energy gathers

local player = Players.LocalPlayer
local remote: RemoteEvent
local panel: Frame
local absorbFrame: Frame
local absorbLabel: TextLabel
local absorbFill: Frame
local queueFrame: Frame
local queueLabel: TextLabel
local queueList: ScrollingFrame
local refreshers: { () -> () } = {}

local meditating = false
local waitingForServer = false
local mustStepOff = false -- true after leaving, until the player walks off the pad
local absorbing: { Started: number, Duration: number }? = nil

-- Energy effect: an invisible ball around the character; particles start on its surface
-- and flow inward to the center (the dantian). Only this player sees it for now.
local aura: Part
local passiveEmitter: ParticleEmitter
local absorbEmitter: ParticleEmitter
local auraLight: PointLight

local function refresh()
	for _, update in refreshers do
		update()
	end
end

local function getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function buildAura()
	aura = Ui.New("Part", {
		Name = "SeclusionAura",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * AURA_SIZE,
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	local function emitter(color: Color3, rate: number, size: number): ParticleEmitter
		return Ui.New("ParticleEmitter", {
			Color = ColorSequence.new(color),
			Rate = rate,
			Enabled = false,
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			Speed = NumberRange.new(AURA_SIZE / 2 / 0.6),
			Lifetime = NumberRange.new(0.6),
			Size = NumberSequence.new(size, 0),
			Transparency = NumberSequence.new(0.2, 0.6),
			LightEmission = 1,
			Parent = aura,
		})
	end
	passiveEmitter = emitter(PASSIVE_COLOR, 8, 0.25)
	absorbEmitter = emitter(Color3.new(1, 1, 1), 80, 0.4)
	auraLight = Ui.New("PointLight", { Range = 10, Brightness = 2, Enabled = false, Parent = aura })
end

local function showAbsorbEffect(color: Color3?)
	absorbEmitter.Enabled = color ~= nil
	auraLight.Enabled = color ~= nil
	if color then
		absorbEmitter.Color = ColorSequence.new(color)
		auraLight.Color = color
	end
end

-- Camera in front of the character, looking back at them, nudged left so the
-- character sits to the right of the pill list. Also keeps the aura on the dantian.
local function followCharacter()
	local root = getRoot()
	if not root then
		return
	end
	aura.CFrame = CFrame.new(root.Position - Vector3.new(0, DANTIAN_DROP, 0))
	local settings = Config.Seclusion
	local look = root.CFrame.LookVector
	local eye = root.Position + look * settings.CameraDistance + Vector3.new(0, 1.5, 0)
	local view = CFrame.lookAt(eye, root.Position)
	local camera = workspace.CurrentCamera
	camera.CFrame = view - view.RightVector * settings.CameraSideShift

	-- Absorb bar
	if absorbing then
		local fraction = math.clamp((os.clock() - absorbing.Started) / absorbing.Duration, 0, 1)
		absorbFill.Size = UDim2.fromScale(fraction, 1)
	end
end

-- Other screens that would sit on top of the pill list are hidden while meditating.
local HIDDEN_SCREENS = { "DevPanel", "Backpack", "Rebirth" }

local function showOtherScreens(show: boolean)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	for _, name in HIDDEN_SCREENS do
		local screen = playerGui and playerGui:FindFirstChild(name)
		if screen and screen:IsA("ScreenGui") then
			screen.Enabled = show
		end
	end
end

local function startMeditating()
	meditating = true
	waitingForServer = false
	local humanoid = getHumanoid()
	if humanoid then
		humanoid.Sit = true -- placeholder pose until the cross-legged animation exists
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	aura.Parent = workspace
	passiveEmitter.Enabled = true
	RunService:BindToRenderStep("SeclusionCamera", Enum.RenderPriority.Camera.Value + 1, followCharacter)
	panel.Visible = true
	showOtherScreens(false)
	refresh()
end

local function stopMeditating()
	meditating = false
	waitingForServer = false
	mustStepOff = true
	absorbing = nil
	RunService:UnbindFromRenderStep("SeclusionCamera")
	local humanoid = getHumanoid()
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid.Sit = false
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
	passiveEmitter.Enabled = false
	showAbsorbEffect(nil)
	aura.Parent = nil
	panel.Visible = false
	absorbFrame.Visible = false
	queueFrame.Visible = false
	showOtherScreens(true)
end

-- Redraw the queue panel: one row per waiting pill (next one at the top), each with an X
-- that takes that pill back into the backpack.
local function showQueue(queue: { { Tier: number, Failed: boolean } })
	for _, child in queueList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	queueFrame.Visible = #queue > 0
	queueLabel.Text = `Queue ({#queue}/{Config.Seclusion.MaxQueue})`
	for index, pill in queue do
		local row = Ui.New("Frame", {
			BackgroundColor3 = Color3.fromRGB(40, 40, 50),
			Size = UDim2.new(1, -8, 0, 40),
			LayoutOrder = index,
			Parent = queueList,
		}, { Ui.Corner(8) })
		Ui.Label({
			Text = `{index}. {Formulas.PillName(pill.Tier, pill.Failed)}`,
			TextColor3 = if pill.Failed then Config.FailedPillColor else Config.Pills[pill.Tier].Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false, -- same size on every row; long names wrap onto a second line
			TextSize = 15,
			TextWrapped = true,
			Position = UDim2.fromOffset(8, 2),
			Size = UDim2.new(1, -58, 1, -4),
			Parent = row,
		})
		local remove = Ui.Button({
			Text = "X",
			BackgroundColor3 = Color3.fromRGB(160, 50, 50),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -4, 0.5, 0),
			Size = UDim2.fromOffset(40, 32),
			Parent = row,
		})
		remove.Activated:Connect(function()
			remote:FireServer("Unqueue", index)
		end)
	end
end

-- One row per pill kind the player has: name, qi and absorb time, count, Consume.
local function addPillRow(list: ScrollingFrame, order: number, tier: number, failed: boolean)
	local row = Ui.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		Size = UDim2.new(1, -8, 0, 56),
		LayoutOrder = order,
		Parent = list,
	}, { Ui.Corner(8) })
	local nameLabel = Ui.Label({
		TextColor3 = if failed then Config.FailedPillColor else Config.Pills[tier].Color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -120, 0, 26),
		Parent = row,
	})
	local seconds = Formulas.PillAbsorbTime(tier, failed)
	Ui.Label({
		Text = `+{Format.Number(Formulas.PillQi(tier, failed))} {Config.Names.Qi} over {seconds}s`,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(8, 30),
		Size = UDim2.new(1, -120, 0, 20),
		Parent = row,
	})
	local consume = Ui.Button({
		Text = "Consume",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(104, 40),
		Parent = row,
	})
	consume.Activated:Connect(function()
		if waitingForServer then
			return
		end
		waitingForServer = true
		remote:FireServer("Consume", { Tier = tier, Failed = failed })
		task.delay(1, function()
			waitingForServer = false -- the server said no
		end)
	end)

	table.insert(refreshers, function()
		local state = Ui.State()
		local count = if failed then state.FailedPills[tier] else state.Pills[tier]
		row.Visible = count > 0
		nameLabel.Text = `{Formulas.PillName(tier, failed)}  x{count}`
		consume.Text = if absorbing then "Queue" else "Consume"
		consume.BackgroundColor3 = if absorbing then OFF_COLOR else ON_COLOR
	end)
end

local function buildUi()
	local screen = Ui.Screen("Seclusion", 5)
	panel = Ui.New("Frame", {
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BackgroundTransparency = 0.1,
		Position = UDim2.fromScale(0.02, 0.1),
		Size = UDim2.fromScale(0.4, 0.8),
		Parent = screen,
	}, {
		Ui.Corner(14),
		Ui.New("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2 }),
		Ui.New("UISizeConstraint", { MaxSize = Vector2.new(420, 560) }),
	})
	Ui.Label({
		Text = "Seclusion",
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 36),
		Parent = panel,
	})
	local passiveLabel = Ui.Label({
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = PASSIVE_COLOR,
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(12, 46),
		Size = UDim2.new(1, -24, 0, 22),
		Parent = panel,
	})
	local emptyLabel = Ui.Label({
		Text = "No pills. Refine some at the Alchemy Furnace.",
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(12, 80),
		Size = UDim2.new(1, -24, 0, 26),
		Parent = panel,
	})
	local list = Ui.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 76),
		Size = UDim2.new(1, -24, 1, -152),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	}, {
		Ui.New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	-- Strongest first, failed ones after.
	local order = 0
	for _, failed in { false, true } do
		for tier = #Config.Pills, 1, -1 do
			order += 1
			addPillRow(list, order, tier, failed)
		end
	end

	local leaveButton = Ui.Button({
		Text = "Leave",
		BackgroundColor3 = Color3.fromRGB(160, 50, 50),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -24, 0, 56),
		Parent = panel,
	})
	leaveButton.Activated:Connect(function()
		remote:FireServer("Leave")
	end)

	-- Absorb bar, under the character.
	absorbFrame = Ui.New("Frame", {
		Visible = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.66, 0.92),
		Size = UDim2.fromScale(0.4, 0.1),
		Parent = screen,
	}, { Ui.New("UISizeConstraint", { MaxSize = Vector2.new(420, 80) }) })
	absorbLabel = Ui.Label({ Size = UDim2.fromScale(1, 0.5), Parent = absorbFrame })
	local track = Ui.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		Position = UDim2.fromScale(0, 0.55),
		Size = UDim2.fromScale(1, 0.4),
		Parent = absorbFrame,
	}, { Ui.Corner(8) })
	absorbFill = Ui.New("Frame", {
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Ui.Corner(8) })

	-- Queue panel, right of the character: one row per waiting pill, top to bottom.
	-- Rows keep their size; past what fits, the list scrolls.
	queueFrame = Ui.New("Frame", {
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BackgroundTransparency = 0.1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0.08, 0),
		Size = UDim2.fromScale(0.22, 0.4),
		Parent = screen,
	}, {
		Ui.Corner(14),
		Ui.New("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2 }),
		Ui.New("UISizeConstraint", { MinSize = Vector2.new(200, 220), MaxSize = Vector2.new(300, 400) }),
	})
	queueLabel = Ui.Label({
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 28),
		Parent = queueFrame,
	})
	queueList = Ui.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 40),
		Size = UDim2.new(1, -16, 1, -94),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = queueFrame,
	}, {
		Ui.New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local clearButton = Ui.Button({
		Text = "Remove All",
		BackgroundColor3 = Color3.fromRGB(160, 50, 50),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 42),
		Parent = queueFrame,
	})
	clearButton.Activated:Connect(function()
		remote:FireServer("Unqueue", "All")
	end)

	table.insert(refreshers, function()
		local state = Ui.State()
		local any = false
		for tier in Config.Pills do
			any = any or state.Pills[tier] > 0 or state.FailedPills[tier] > 0
		end
		emptyLabel.Visible = not any
		passiveLabel.Text = `Meditating: +{Format.Number(Formulas.MeditationQi(state))} {Config.Names.Qi}/s`
	end)
end

function SeclusionController.Init()
	remote = Remotes.Get("Seclusion")
	buildAura()
	buildUi()
	Ui.OnStateChanged(refresh)

	remote.OnClientEvent:Connect(function(action: string, ...)
		if action == "Entered" then
			startMeditating()
		elseif action == "Left" then
			stopMeditating()
		elseif action == "Qi" then
			local amount = ...
			QiPopupController.Show(amount)
		elseif action == "Absorb" then
			local tier, failed, duration = ...
			waitingForServer = false
			absorbing = { Started = os.clock(), Duration = duration }
			local color = if failed then Config.FailedPillColor else Config.Pills[tier].Color
			absorbLabel.Text = `Absorbing {Formulas.PillName(tier, failed)}...`
			absorbFill.BackgroundColor3 = color
			absorbFill.Size = UDim2.fromScale(0, 1)
			absorbFrame.Visible = true
			showAbsorbEffect(color)
			refresh()
		elseif action == "Queue" then
			local queue = ...
			waitingForServer = false
			showQueue(queue)
		elseif action == "AbsorbEnd" then
			absorbing = nil
			absorbFrame.Visible = false
			showAbsorbEffect(nil)
			refresh()
		end
	end)

	-- A new body after dying is never meditating (the server ends it too).
	player.CharacterAdded:Connect(function()
		if meditating then
			stopMeditating()
		end
	end)

	-- Ask to start while standing on a pad (asking again if the server said no, e.g. it
	-- hadn't seen the player arrive yet). After leaving, the player has to step off
	-- and back on to start again.
	task.spawn(function()
		while true do
			local pad = Ui.PadUnderPlayer(Config.SeclusionPadTag)
			if not pad then
				mustStepOff = false
			elseif not meditating and not waitingForServer and not mustStepOff then
				waitingForServer = true
				remote:FireServer("Enter")
				task.delay(2, function()
					if not meditating then
						waitingForServer = false
					end
				end)
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return SeclusionController
