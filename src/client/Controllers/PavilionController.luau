--!strict
-- PavilionController: the Technique Pavilion menu. Opens from the ProximityPrompt
-- on the lectern, lists the 4 techniques with level, effect and cost, and sends
-- "buy technique X" to the server. Closes when you walk away.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local PavilionController = {}

local CLOSE_DISTANCE = 22

-- Short description of what a technique does at a given level.
local function effectText(technique, level: number): string
	if technique.Id == "HeavyStrike" then
		if level == 0 then
			return "Not learned"
		end
		return `Every {technique.EveryNthPunch}th punch x{Formulas.HeavyStrikeMultiplier(level)} damage`
	end
	local percent = math.floor(level * technique.EffectPerLevel * 100 + 0.5)
	local what = ({
		ClickQi = "qi per tap",
		TrainQi = "training qi",
		FistDamage = "punch damage",
	})[technique.Id] or ""
	return `+{percent}% {what}`
end

function PavilionController.Init()
	local screen = Ui.Screen("Pavilion", 5)
	local buy = Remotes.Get("BuyTechnique")

	local panel = Ui.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.86),
		BackgroundColor3 = Color3.fromRGB(35, 30, 30),
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = screen,
	})
	Ui.Corner(14).Parent = panel
	Ui.New("UISizeConstraint", { MaxSize = Vector2.new(560, 560), Parent = panel })
	Ui.New("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		Parent = panel,
	})

	Ui.Label({ Size = UDim2.new(1, -60, 0, 40), Text = Config.Names.Pavilion, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	local closeButton = Ui.Button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(50, 50),
		Text = "X",
		BackgroundColor3 = Color3.fromRGB(170, 50, 50),
		Parent = panel,
	})
	local walletLabel = Ui.Label({
		Position = UDim2.new(0, 0, 0, 44),
		Size = UDim2.new(1, -60, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(220, 220, 220),
		Parent = panel,
	})

	local list = Ui.New("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 76),
		Size = UDim2.new(1, 0, 1, -76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})
	Ui.New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	-- One header per technique kind, then a row per technique
	local rows: { { technique: any, info: TextLabel, button: TextButton } } = {}
	local order = 0
	local headers = {
		Cultivation = `Cultivation Techniques (cost {Config.Names.Stones})`,
		Fist = `Fist Techniques (cost {Config.Names.Cores})`,
	}
	for _, kind in { "Cultivation", "Fist" } do
		order += 1
		Ui.Label({
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 28),
			Text = headers[kind],
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if kind == "Cultivation" then Color3.fromRGB(120, 210, 255) else Color3.fromRGB(255, 130, 110),
			Parent = list,
		})
		for _, technique in Config.Techniques do
			if technique.Kind == kind then
				order += 1
				local row = Ui.New("Frame", {
					LayoutOrder = order,
					Size = UDim2.new(1, -8, 0, 84),
					BackgroundColor3 = Color3.fromRGB(60, 52, 50),
					Parent = list,
				})
				Ui.Corner(10).Parent = row
				Ui.Label({
					Position = UDim2.fromOffset(10, 6),
					Size = UDim2.new(1, -170, 0, 32),
					Text = technique.Name,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = row,
				})
				local info = Ui.Label({
					Position = UDim2.fromOffset(10, 42),
					Size = UDim2.new(1, -170, 0, 34),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Color3.fromRGB(210, 210, 210),
					Font = Enum.Font.Gotham,
					Parent = row,
				})
				local button = Ui.Button({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(150, 64),
					Parent = row,
				})
				button.Activated:Connect(function()
					buy:FireServer(technique.Id)
				end)
				table.insert(rows, { technique = technique, info = info, button = button })
			end
		end
	end

	local function refresh()
		local state = Ui.State()
		walletLabel.Text = `{Config.Names.Stones}: {Format.Number(state.Stones)}   ·   {Config.Names.Cores}: {Format.Number(state.Cores)}`
		for _, row in rows do
			local technique = row.technique
			local level = state.Techniques[technique.Id] or 0
			if level >= technique.MaxLevel then
				row.info.Text = `Lv {level} (MAX)\n{effectText(technique, level)}`
				row.button.Text = "MAX"
				row.button.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
			else
				local cost = Formulas.TechniqueCost(technique.Id, level)
				local balance = if technique.Currency == "Stones" then state.Stones else state.Cores
				row.info.Text = `Lv {level} → {level + 1}\n{effectText(technique, level)} → {effectText(technique, level + 1)}`
				row.button.Text = `Buy\n{Format.Number(cost)} {if technique.Currency == "Stones" then "crystals" else "cores"}`
				row.button.BackgroundColor3 = if balance >= cost then Color3.fromRGB(60, 160, 70) else Color3.fromRGB(100, 90, 90)
			end
		end
	end
	Ui.OnStateChanged(refresh)

	local lectern: BasePart? = nil
	local function close()
		panel.Visible = false
	end
	closeButton.Activated:Connect(close)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "PavilionPrompt" then
			lectern = prompt.Parent :: BasePart
			refresh()
			panel.Visible = true
		end
	end)

	-- Close the menu when the player walks away
	task.spawn(function()
		while true do
			task.wait(0.5)
			if panel.Visible and lectern then
				local character = Players.LocalPlayer.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not rootPart or (rootPart.Position - lectern.Position).Magnitude > CLOSE_DISTANCE then
					close()
				end
			end
		end
	end)
end

return PavilionController
