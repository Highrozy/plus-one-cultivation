--!strict
-- Ui: tiny helpers for building greybox UI in code.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Ui = {}

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
	return {
		Qi = player:GetAttribute("Qi") or 0,
		Stage = player:GetAttribute("Stage") or 1,
		SpiritStones = player:GetAttribute("SpiritStones") or 0,
		BeastCores = player:GetAttribute("BeastCores") or 0,
		Manuals = manuals,
		Upgrades = upgrades,
		Rebirths = player:GetAttribute("Rebirths") or 0,
		RebirthBonus = player:GetAttribute("RebirthBonus") or 0,
	}
end

-- Call `callback` now and whenever any of the player's attributes change.
function Ui.OnStateChanged(callback: () -> ())
	Players.LocalPlayer.AttributeChanged:Connect(callback)
	callback()
end

return Ui
