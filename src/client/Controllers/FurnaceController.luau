--!strict
-- FurnaceController: the alchemy furnace menu, open while the player stands on a furnace pad.
-- Pick up to Config.Alchemy.MaxCoreKinds kinds of core from the backpack (any amount of
-- each), drag the stone slider, and press Refine. The server checks everything, takes the
-- ingredients and answers with BrewStart(tier), which starts the minigame (BrewController).
-- The menu shows the total essence but not which pill it makes: players find that out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BrewController = require(script.Parent.BrewController)
local Ui = require(script.Parent.Ui)

local FurnaceController = {}

local CHECK_INTERVAL = 0.2 -- seconds between "am I on a pad?" checks
local ON_COLOR = Color3.fromRGB(60, 140, 70)
local OFF_COLOR = Color3.fromRGB(80, 80, 90)

local furnaceRemote: RemoteEvent
local panel: Frame
local refreshers: { () -> () } = {}

-- What the player has put in so far: "<core id>_<grade>" -> count, and stones.
local chosen: { [string]: number } = {}
local stoneFraction = 0 -- slider position, 0..1 of the stones the player has
local waitingForServer = false

local function refresh()
	for _, update in refreshers do
		update()
	end
end

local function chosenKinds(): number
	local kinds = 0
	for _, count in chosen do
		if count > 0 then
			kinds += 1
		end
	end
	return kinds
end

local function chosenStones(): number
	return math.floor(stoneFraction * Ui.State().SpiritStones)
end

-- The furnace load as the server expects it.
local function buildLoad(): { Cores: { Formulas.CoreStack }, Stones: number }
	local cores = {}
	for _, id in Config.CoreOrder do
		for grade in Config.CoreGrades do
			local count = chosen[`{id}_{grade}`] or 0
			if count > 0 then
				table.insert(cores, { Core = id, Grade = grade, Count = count })
			end
		end
	end
	return { Cores = cores, Stones = chosenStones() }
end

local function reset()
	chosen = {}
	stoneFraction = 0
	refresh()
end

local function smallButton(text: string, color: Color3, parent: Instance): TextButton
	return Ui.Button({
		Text = text,
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(44, 36),
		Parent = parent,
	})
end

-- One row per core type and grade in the backpack: name, how many are in, - + All.
local function addCoreRow(list: ScrollingFrame, order: number, id: string, grade: number)
	local key = `{id}_{grade}`
	local row = Ui.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		Size = UDim2.new(1, -8, 0, 48),
		LayoutOrder = order,
		Parent = list,
	}, { Ui.Corner(8) })
	local label = Ui.Label({
		TextColor3 = Config.CoreGrades[grade].Color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -170, 1, -12),
		Parent = row,
	})
	local buttons = Ui.New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(152, 36),
		Parent = row,
	}, {
		Ui.New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local minus = smallButton("-", OFF_COLOR, buttons)
	local plus = smallButton("+", ON_COLOR, buttons)
	local all = smallButton("All", ON_COLOR, buttons)
	minus.LayoutOrder, plus.LayoutOrder, all.LayoutOrder = 1, 2, 3

	local function owned(): number
		return Ui.State().Bag[id][grade]
	end
	-- A new kind can only go in while fewer than MaxCoreKinds kinds are in.
	local function canAddKind(): boolean
		return (chosen[key] or 0) > 0 or chosenKinds() < Config.Alchemy.MaxCoreKinds
	end
	local function set(count: number)
		chosen[key] = math.clamp(count, 0, owned())
		refresh()
	end
	minus.Activated:Connect(function()
		set((chosen[key] or 0) - 1)
	end)
	plus.Activated:Connect(function()
		if canAddKind() then
			set((chosen[key] or 0) + 1)
		end
	end)
	all.Activated:Connect(function()
		if canAddKind() then
			set(owned())
		end
	end)

	table.insert(refreshers, function()
		local have = owned()
		chosen[key] = math.min(chosen[key] or 0, have)
		row.Visible = have > 0
		label.Text = `{Formulas.CoreName(id, grade)}: {chosen[key]}/{have}`
		local addColor = if canAddKind() then ON_COLOR else OFF_COLOR
		plus.BackgroundColor3 = addColor
		all.BackgroundColor3 = addColor
	end)
end

-- A plain drag slider for how many of the player's spirit stones go in.
local function buildStoneSlider(parent: Frame)
	local label = Ui.Label({
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 12, 1, -138),
		Size = UDim2.new(1, -24, 0, 24),
		Parent = parent,
	})
	local track = Ui.New("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		Position = UDim2.new(0, 12, 1, -108),
		Size = UDim2.new(1, -24, 0, 28),
		Parent = parent,
	}, { Ui.Corner(8) })
	local fill = Ui.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(120, 200, 255),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Ui.Corner(8) })

	local dragging = false
	local function setFromX(x: number)
		stoneFraction = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		refresh()
	end
	local function isPointer(input: InputObject): boolean
		local kind = input.UserInputType
		return kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
	end
	track.InputBegan:Connect(function(input)
		if isPointer(input) then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		local kind = input.UserInputType
		if dragging and (kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isPointer(input) then
			dragging = false
		end
	end)

	table.insert(refreshers, function()
		fill.Size = UDim2.fromScale(stoneFraction, 1)
		label.Text = `{Config.Names.SpiritStones}: {Format.Number(chosenStones())}`
	end)
end

local function buildPanel()
	local screen = Ui.Screen("Furnace", 5)
	panel = Ui.New("Frame", {
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BackgroundTransparency = 0.1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.9, 0.8),
		Parent = screen,
	}, {
		Ui.Corner(14),
		Ui.New("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2 }),
		Ui.New("UISizeConstraint", { MaxSize = Vector2.new(520, 520) }),
	})
	Ui.Label({
		Text = "Alchemy Furnace",
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -80, 0, 36),
		Parent = panel,
	})
	local closeButton = Ui.Button({
		Text = "X",
		BackgroundColor3 = Color3.fromRGB(160, 50, 50),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(48, 40),
		Parent = panel,
	})
	closeButton.Activated:Connect(function()
		panel.Visible = false
	end)

	local kindsLabel = Ui.Label({
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(12, 48),
		Size = UDim2.new(1, -24, 0, 22),
		Parent = panel,
	})
	local emptyLabel = Ui.Label({
		Text = `No {Config.Names.BeastCores} in your {Config.Names.Backpack}`,
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
		Size = UDim2.new(1, -24, 1, -224),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	}, {
		Ui.New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local order = 0
	for _, id in Config.CoreOrder do
		for grade = #Config.CoreGrades, 1, -1 do
			order += 1
			addCoreRow(list, order, id, grade)
		end
	end

	buildStoneSlider(panel)

	local essenceLabel = Ui.Label({
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 220, 120),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -14),
		Size = UDim2.new(0.5, -12, 0, 30),
		Parent = panel,
	})
	local refineButton = Ui.Button({
		Text = "Refine",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -10),
		Size = UDim2.new(0.45, 0, 0, 56),
		Parent = panel,
	})
	refineButton.Activated:Connect(function()
		local load = buildLoad()
		if #load.Cores == 0 or waitingForServer then
			return
		end
		waitingForServer = true
		furnaceRemote:FireServer("Refine", load)
		task.delay(3, function()
			waitingForServer = false -- the server said no (it sends a message why)
		end)
	end)

	table.insert(refreshers, function()
		local load = buildLoad()
		local essence = Formulas.Essence(load.Cores, load.Stones)
		kindsLabel.Text = `Core kinds: {chosenKinds()}/{Config.Alchemy.MaxCoreKinds}`
		essenceLabel.Text = `Essence: {Format.Number(math.floor(essence))}`
		refineButton.BackgroundColor3 = if #load.Cores > 0 then ON_COLOR else OFF_COLOR
		emptyLabel.Visible = Ui.State().BagCores == 0
	end)
end

function FurnaceController.Init()
	furnaceRemote = Remotes.Get("Furnace")
	buildPanel()
	Ui.OnStateChanged(refresh)

	Remotes.Get("BrewStart").OnClientEvent:Connect(function(tier: number)
		waitingForServer = false
		panel.Visible = false
		reset()
		BrewController.Start(tier, function(won)
			furnaceRemote:FireServer("Finish", won)
			panel.Visible = Ui.PadUnderPlayer(Config.FurnacePadTag) ~= nil
		end)
	end)

	-- Open on stepping onto a pad, close on walking off. After X, stay closed until the
	-- player steps off and back on.
	local currentPad: BasePart? = nil
	task.spawn(function()
		while true do
			local pad = Ui.PadUnderPlayer(Config.FurnacePadTag)
			if pad ~= currentPad then
				currentPad = pad
				panel.Visible = pad ~= nil
				if pad then
					reset()
				end
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return FurnaceController
