--!strict
-- QiPopupController: shows "+5 Qi" at a random spot near the middle of the screen,
-- then floats it up and fades it out. InputController calls Show() on every tap,
-- and the server sends one for every training dummy punch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local QiPopupController = {}

local screen: ScreenGui? = nil

function QiPopupController.Show(amount: number)
	if not screen then
		screen = Ui.Screen("QiPopups", 5)
	end
	local popup = Config.QiPopup
	local x = 0.5 + (math.random() * 2 - 1) * popup.SpreadX
	local y = 0.5 + (math.random() * 2 - 1) * popup.SpreadY

	local label = Ui.Label({
		Text = `+{Format.Number(amount)} {Config.Names.Qi}`,
		TextColor3 = popup.Color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(0.2, 0.06),
		Rotation = math.random(-8, 8),
		Parent = screen,
	})
	local scale = Ui.New("UIScale", { Scale = 0.5, Parent = label })

	-- Pop in quickly, then drift up and fade.
	TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	local fade = TweenService:Create(
		label,
		TweenInfo.new(popup.Lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Position = UDim2.fromScale(x, y - popup.RiseDistance),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)
	fade:Play()
	fade.Completed:Once(function()
		label:Destroy()
	end)
end

function QiPopupController.Init()
	-- Punching a training dummy gives qi from the server, so the popup comes from there.
	Remotes.Get("TrainingQi").OnClientEvent:Connect(QiPopupController.Show)
end

return QiPopupController
