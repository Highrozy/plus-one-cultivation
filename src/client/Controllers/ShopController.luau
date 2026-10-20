--!strict
-- ShopController: opens the shop menu while the player stands on a shop pad and closes it
-- when they walk off. Buttons only send "buy X" / "sell X"; the server checks everything.
-- Manual Shop has Buy and Sell tabs; Upgrade Shop has one list.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local ShopController = {}

local CHECK_INTERVAL = 0.2 -- seconds between "am I on a pad?" checks
local PAD_HEIGHT = 6 -- studs above a pad that still count as standing on it

local BUY_COLOR = Color3.fromRGB(60, 140, 70)
local OFF_COLOR = Color3.fromRGB(80, 80, 90)
local TAB_ON = Color3.fromRGB(70, 90, 150)

local shopRemote: RemoteEvent
local panel: Frame
local title: TextLabel
local tabs: Frame
local list: ScrollingFrame

local openShop: string? = nil
local tab = "Buy"
local refreshers: { () -> () } = {}

-- The pad the player is standing on, if any.
local function padUnderPlayer(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	for _, pad in CollectionService:GetTagged(Config.ShopPadTag) do
		if pad:IsA("BasePart") then
			local localPos = pad.CFrame:PointToObjectSpace(root.Position)
			local half = pad.Size / 2
			if
				math.abs(localPos.X) <= half.X + 1
				and math.abs(localPos.Z) <= half.Z + 1
				and localPos.Y >= -half.Y
				and localPos.Y <= half.Y + PAD_HEIGHT
			then
				return pad
			end
		end
	end
	return nil
end

local function refresh()
	for _, update in refreshers do
		update()
	end
end

-- One row: name + detail text on the left, a button on the right.
-- update() returns the detail text, button text and whether the button is usable.
local function addRow(order: number, name: string, onClick: () -> (), update: () -> (string, string, boolean))
	local row = Ui.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		Size = UDim2.new(1, -8, 0, 64),
		LayoutOrder = order,
		Parent = list,
	}, { Ui.Corner(10) })
	Ui.Label({
		Text = name,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(0.62, -10, 0, 26),
		Parent = row,
	})
	local detail = Ui.Label({
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(10, 34),
		Size = UDim2.new(0.62, -10, 0, 22),
		Parent = row,
	})
	local button = Ui.Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0.38, -8, 0, 48),
		Parent = row,
	})
	local usable = false
	button.Activated:Connect(function()
		if usable then
			onClick()
		end
	end)
	table.insert(refreshers, function()
		local detailText, buttonText, canUse = update()
		detail.Text = detailText
		button.Text = buttonText
		usable = canUse
		button.BackgroundColor3 = if canUse then BUY_COLOR else OFF_COLOR
	end)
end

local function buildManualsBuy()
	for index, id in Config.ManualOrder do
		local info = Config.Manuals[id]
		addRow(index, info.Name, function()
			shopRemote:FireServer("BuyManual", id)
		end, function()
			if Ui.State().Manuals[id] then
				return info.Description, "Owned", false
			end
			return info.Description, `{Format.Number(info.Price)} Stones`, true
		end)
	end
end

local function buildManualsSell()
	local price = Config.CoreSellPrice
	addRow(1, `Sell 1 {Config.Names.BeastCores}`, function()
		shopRemote:FireServer("SellCores", 1)
	end, function()
		local state = Ui.State()
		return `You have {state.BeastCores}/{Formulas.CoreCap(state)}`,
			`+{price} Stones`,
			state.BeastCores > 0
	end)
	addRow(2, `Sell all {Config.Names.BeastCores}`, function()
		shopRemote:FireServer("SellCores", "All")
	end, function()
		local cores = Ui.State().BeastCores
		return `{price} Stones each`, `+{Format.Number(cores * price)} Stones`, cores > 0
	end)
end

local function buildUpgrades()
	for index, id in Config.UpgradeOrder do
		local info = Config.Upgrades[id]
		addRow(index, info.Name, function()
			shopRemote:FireServer("BuyUpgrade", id)
		end, function()
			if info.ComingSoon then
				return info.Description, "Coming soon", false
			end
			local state = Ui.State()
			local level = Formulas.UpgradeLevel(state, id)
			local detailText = `Lv {level}/{info.MaxLevel}: {info.Description}`
			local cost = Formulas.UpgradeCost(state, id)
			if not cost then
				return detailText, "MAX", false
			end
			return detailText, `{Format.Number(cost)} Stones`, true
		end)
	end
end

-- Rebuild the list for the open shop and tab.
local function rebuild()
	refreshers = {}
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	tabs.Visible = openShop == "Manuals"
	for _, button in tabs:GetChildren() do
		if button:IsA("TextButton") then
			button.BackgroundColor3 = if button.Name == tab then TAB_ON else OFF_COLOR
		end
	end
	if openShop == "Manuals" then
		if tab == "Buy" then
			buildManualsBuy()
		else
			buildManualsSell()
		end
	elseif openShop == "Upgrades" then
		buildUpgrades()
	end
	refresh()
end

local function open(shop: string)
	openShop = shop
	tab = "Buy"
	title.Text = Config.ShopNames[shop] or "Shop"
	panel.Visible = true
	rebuild()
end

local function close()
	openShop = nil
	panel.Visible = false
end

local function buildPanel()
	local screen = Ui.Screen("Shop", 5)
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
	title = Ui.Label({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -80, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
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
	closeButton.Activated:Connect(close)

	tabs = Ui.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.new(1, -24, 0, 40),
		Parent = panel,
	}, {
		Ui.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	for _, name in { "Buy", "Sell" } do
		local button = Ui.Button({
			Name = name,
			Text = name,
			Size = UDim2.new(0.5, -4, 1, 0),
			Parent = tabs,
		})
		button.Activated:Connect(function()
			tab = name
			rebuild()
		end)
	end

	list = Ui.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 100),
		Size = UDim2.new(1, -24, 1, -112),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = panel,
	}, {
		Ui.New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end

function ShopController.Init()
	shopRemote = Remotes.Get("Shop")
	buildPanel()
	Ui.OnStateChanged(refresh)

	-- Open on stepping onto a pad, close on walking off. After X, stay closed until the
	-- player steps off and back on.
	local currentPad: BasePart? = nil
	task.spawn(function()
		while true do
			local pad = padUnderPlayer()
			if pad ~= currentPad then
				currentPad = pad
				local shop = pad and pad:GetAttribute("Shop")
				if typeof(shop) == "string" and Config.ShopNames[shop] then
					open(shop)
				else
					close()
				end
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return ShopController
