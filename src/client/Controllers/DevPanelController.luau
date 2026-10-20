--!strict
-- DevPanelController: Studio-only buttons for skipping ahead while testing.
-- Not shown in the live game (and the server ignores these commands there).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local DevPanelController = {}

local BUTTONS = {
	{ Text = "Next Stage", Command = "NextStage" },
	{ Text = "Reset", Command = "Reset" },
}

function DevPanelController.Init()
	if not RunService:IsStudio() then
		return
	end
	local devCommand = Remotes.Get("DevCommand")
	local screen = Ui.Screen("DevPanel", 20)

	local panel = Ui.New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(130, #BUTTONS * 44 + 24),
		Parent = screen,
	}, {
		Ui.New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Ui.Label({ Text = "DEV", Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0, Parent = panel })

	for index, info in BUTTONS do
		local button = Ui.Button({
			Text = info.Text,
			LayoutOrder = index,
			BackgroundColor3 = Color3.fromRGB(90, 60, 140),
			Size = UDim2.new(1, 0, 0, 38),
			Parent = panel,
		})
		button.Activated:Connect(function()
			devCommand:FireServer(info.Command)
		end)
	end
end

return DevPanelController
