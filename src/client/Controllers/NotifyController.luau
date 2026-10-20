--!strict
-- NotifyController: short messages from the server ("Not enough Spirit Stones")
-- shown near the top of the screen for a couple of seconds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local NotifyController = {}

function NotifyController.Init()
	local screen = Ui.Screen("Notify", 10)
	local label = Ui.Label({
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.new(0.8, 0, 0, 34),
		Parent = screen,
	})
	local shownAt = 0
	Remotes.Get("Notify").OnClientEvent:Connect(function(message: string)
		label.Text = message
		label.Visible = true
		local now = os.clock()
		shownAt = now
		task.delay(Config.Notify.Lifetime, function()
			if shownAt == now then
				label.Visible = false
			end
		end)
	end)
end

return NotifyController
