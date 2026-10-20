--!strict
-- DevPanelController: a "DEV" button (Studio playtests only) with shortcuts for testing,
-- e.g. jump straight to QC9 or FE9 to try the breakthrough and rebirth without grinding.
-- The server ignores these commands outside Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local DevPanelController = {}

local COMMANDS = {
	{ "NextStage", "Next stage" },
	{ "ToQC9", "Go to QC9 (breakthrough ready)" },
	{ "ToFE9", "Go to FE9 (rebirth ready)" },
	{ "Stones", "+500 crystals" },
	{ "Cores", "+500 cores" },
	{ "Rebirths", "+1 rebirth" },
}

function DevPanelController.Init()
	if not RunService:IsStudio() then
		return
	end
	local devCommand = Remotes.Get("DevCommand")
	local screen = Ui.Screen("DevPanel", 20)

	local toggle = Ui.Button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 60),
		Size = UDim2.fromOffset(70, 40),
		Text = "DEV",
		BackgroundColor3 = Color3.fromRGB(200, 90, 30),
		Parent = screen,
	})
	local panel = Ui.New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 106),
		Size = UDim2.fromOffset(240, #COMMANDS * 46),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})
	Ui.New("UIListLayout", { Padding = UDim.new(0, 6), Parent = panel })
	for _, command in COMMANDS do
		local button = Ui.Button({
			Size = UDim2.new(1, 0, 0, 40),
			Text = command[2],
			BackgroundColor3 = Color3.fromRGB(60, 60, 70),
			Parent = panel,
		})
		button.Activated:Connect(function()
			devCommand:FireServer(command[1])
		end)
	end
	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
end

return DevPanelController
