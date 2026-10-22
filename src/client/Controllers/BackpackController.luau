--!strict
-- BackpackController: a Backpack button on the right that opens a list of everything
-- in the player's backpack: pills (strongest first, failed ones greyed out) then cores
-- (rarest first). The furnace and the Sell tab are where backpack items get used.
-- Pills are eaten in the seclusion cave (SeclusionController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Ui = require(script.Parent.Ui)

local BackpackController = {}

local panel: Frame
local list: ScrollingFrame
local emptyLabel: TextLabel
-- Each row: its label, its text, and how many of the item the player has.
local rows: { { Label: TextLabel, Text: string, Count: (any) -> number } } = {}

local function refresh()
	local state = Ui.State()
	local any = false
	for _, row in rows do
		local count = row.Count(state)
		row.Label.Visible = count > 0
		row.Label.Text = `  {row.Text}  x{count}`
		any = any or count > 0
	end
	emptyLabel.Visible = not any
end

local function addRow(order: number, text: string, color: Color3, count: (any) -> number): TextLabel
	local label = Ui.Label({
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -8, 0, 40),
		LayoutOrder = order,
		Parent = list,
	})
	Ui.Corner(8).Parent = label
	table.insert(rows, { Label = label, Text = text, Count = count })
	return label
end

function BackpackController.Init()
	local screen = Ui.Screen("Backpack", 4)

	local openButton = Ui.Button({
		Text = Config.Names.Backpack,
		BackgroundColor3 = Color3.fromRGB(110, 80, 50),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0.5, 140),
		Size = UDim2.fromOffset(150, 56),
		Parent = screen,
	})

	panel = Ui.New("Frame", {
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BackgroundTransparency = 0.1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.9, 0.7),
		Parent = screen,
	}, {
		Ui.Corner(14),
		Ui.New("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2 }),
		Ui.New("UISizeConstraint", { MaxSize = Vector2.new(520, 440) }),
	})
	Ui.Label({
		Text = Config.Names.Backpack,
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
	list = Ui.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 56),
		Size = UDim2.new(1, -24, 1, -68),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	}, {
		Ui.New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	emptyLabel = Ui.Label({
		Text = "Empty. Bring cores back to the safe zone.",
		TextScaled = false,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Font = Enum.Font.Gotham,
		Size = UDim2.new(1, -8, 0, 30),
		LayoutOrder = 0,
		Parent = list,
	})

	-- Pills first (strongest first, failed ones after), then one row per core type and grade.
	local order = 0
	for _, failed in { false, true } do
		for tier = #Config.Pills, 1, -1 do
			order += 1
			local color = if failed then Config.FailedPillColor else Config.Pills[tier].Color
			local text = `{Formulas.PillName(tier, failed)}`
			if not failed then
				text ..= ` (+{Format.Number(Formulas.PillQi(tier, false))} {Config.Names.Qi})`
			end
			addRow(order, text, color, function(state)
				return if failed then state.FailedPills[tier] else state.Pills[tier]
			end)
		end
	end
	for _, id in Config.CoreOrder do
		for grade = #Config.CoreGrades, 1, -1 do
			order += 1
			addRow(order, Formulas.CoreName(id, grade), Config.CoreGrades[grade].Color, function(state)
				return state.Bag[id][grade]
			end)
		end
	end

	openButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	closeButton.Activated:Connect(function()
		panel.Visible = false
	end)
	Ui.OnStateChanged(refresh)
end

return BackpackController
