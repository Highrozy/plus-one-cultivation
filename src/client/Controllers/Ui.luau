--!strict
-- Ui: tiny helpers for building greybox UI in code.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Ui = {}

local PAD_HEIGHT = 6 -- studs above a pad that still count as standing on it

-- Create an instance, set its properties, and parent any children.
function Ui.New(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Ui.Corner(radius: number?): UICorner
	return Ui.New("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Ui.Screen(name: string, displayOrder: number?): ScreenGui
	return Ui.New("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = displayOrder or 0,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
end

-- Plain text label with sensible defaults (transparent background, scaled text).
function Ui.Label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Ui.New("TextLabel", defaults)
end

-- Big chunky button, sized for phones.
function Ui.Button(props: { [string]: any }): TextButton
	local defaults = {
		AutoButtonColor = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.5,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		BorderSizePixel = 0,
	}
	for key, value in props do
		defaults[key] = value
	end
	local button = Ui.New("TextButton", defaults)
	Ui.Corner(12).Parent = button
	Ui.New("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = button,
	})
	return button
end

-- Read the player's game state from the attributes the server sets.
function Ui.State()
	local player = Players.LocalPlayer
	local manuals = {}
	for id in Config.Manuals do
		if player:GetAttribute(`Manual_{id}`) then
			manuals[id] = true
		end
	end
	local upgrades = {}
	for id in Config.Upgrades do
		upgrades[id] = player:GetAttribute(`Upgrade_{id}`) or 0
	end
	local cores = {}
	local bag = {}
	for id in Config.Cores do
		cores[id] = {}
		bag[id] = {}
		for grade in Config.CoreGrades do
			cores[id][grade] = player:GetAttribute(`Core_{id}_{grade}`) or 0
			bag[id][grade] = player:GetAttribute(`Bag_{id}_{grade}`) or 0
		end
	end
	local pills = {}
	local failedPills = {}
	for tier in Config.Pills do
		pills[tier] = player:GetAttribute(`Pill_{tier}`) or 0
		failedPills[tier] = player:GetAttribute(`FailedPill_{tier}`) or 0
	end
	return {
		Qi = player:GetAttribute("Qi") or 0,
		Stage = player:GetAttribute("Stage") or 1,
		SpiritStones = player:GetAttribute("SpiritStones") or 0,
		BeastCores = player:GetAttribute("BeastCores") or 0,
		Cores = cores,
		BagCores = player:GetAttribute("BagCores") or 0,
		Bag = bag,
		Pills = pills,
		FailedPills = failedPills,
		Manuals = manuals,
		Upgrades = upgrades,
		Rebirths = player:GetAttribute("Rebirths") or 0,
		RebirthBonus = player:GetAttribute("RebirthBonus") or 0,
	}
end

-- The part with this tag the player is standing on, if any.
function Ui.PadUnderPlayer(tag: string): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	for _, pad in CollectionService:GetTagged(tag) do
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

-- Call `callback` now and whenever any of the player's attributes change.
function Ui.OnStateChanged(callback: () -> ())
	Players.LocalPlayer.AttributeChanged:Connect(callback)
	callback()
end

return Ui
