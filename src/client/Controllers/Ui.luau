--!strict
-- Ui: tiny helpers for building greybox UI in code.

local Players = game:GetService("Players")

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

-- Shake the camera for `time` seconds (runs right after Roblox moves the camera each frame).
local shakeCount = 0
function Ui.ShakeCamera(strength: number, time: number)
	local RunService = game:GetService("RunService")
	shakeCount += 1
	local name = "CameraShake" .. shakeCount
	local start = os.clock()
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local elapsed = os.clock() - start
		if elapsed >= time then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local amount = strength * (1 - elapsed / time)
		local camera = workspace.CurrentCamera
		camera.CFrame *= CFrame.new((math.random() - 0.5) * amount, (math.random() - 0.5) * amount, 0)
	end)
end

-- Read the player's game state from the attributes the server sets.
function Ui.State()
	local player = Players.LocalPlayer
	local techniques = {}
	for name, value in player:GetAttributes() do
		local id = string.match(name, "^Tech_(.+)$")
		if id then
			techniques[id] = value
		end
	end
	return {
		Qi = player:GetAttribute("Qi") or 0,
		Stage = player:GetAttribute("Stage") or 1,
		Stones = player:GetAttribute("Stones") or 0,
		Cores = player:GetAttribute("Cores") or 0,
		Rebirths = player:GetAttribute("Rebirths") or 0,
		TrainingPlatform = player:GetAttribute("TrainingPlatform") or 0,
		Techniques = techniques,
	}
end

-- Call `callback` now and whenever any of the player's attributes change.
function Ui.OnStateChanged(callback: () -> ())
	Players.LocalPlayer.AttributeChanged:Connect(callback)
	callback()
end

return Ui
