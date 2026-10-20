--!strict
-- BreakthroughController: when the player's stage goes up, flashes a banner in the
-- top middle of the screen. Reaching a new realm gets a bigger gold banner.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Ui = require(script.Parent.Ui)

local BreakthroughController = {}

local STAGE_COLOR = Color3.fromRGB(255, 255, 255)
local REALM_COLOR = Color3.fromRGB(255, 210, 80)

function BreakthroughController.Init()
	local player = Players.LocalPlayer
	local screen = Ui.Screen("Breakthrough", 10)
	local lastStage = Ui.State().Stage
	local current: Frame? = nil

	player:GetAttributeChangedSignal("Stage"):Connect(function()
		local stage = Ui.State().Stage
		local wentUp = stage > lastStage
		lastStage = stage
		if not wentUp then
			return -- e.g. the DEV panel's Reset
		end

		if current then
			current:Destroy()
		end
		local newRealm = Formulas.IsNewRealm(stage)
		local color = if newRealm then REALM_COLOR else STAGE_COLOR

		local banner = Ui.New("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.22),
			Size = if newRealm then UDim2.fromScale(0.7, 0.16) else UDim2.fromScale(0.5, 0.11),
			Parent = screen,
		})
		current = banner
		local title = Ui.Label({
			Text = if newRealm then "REALM BREAKTHROUGH!" else "Breakthrough!",
			TextColor3 = color,
			Size = UDim2.fromScale(1, 0.55),
			Parent = banner,
		})
		local subtitle = Ui.Label({
			Text = Formulas.StageName(stage),
			TextColor3 = color,
			Position = UDim2.fromScale(0, 0.58),
			Size = UDim2.fromScale(1, 0.42),
			Parent = banner,
		})
		local scale = Ui.New("UIScale", { Scale = 0.3, Parent = banner })

		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()

		task.delay(if newRealm then 2.5 else 1.5, function()
			if current ~= banner then
				return
			end
			local fadeInfo = TweenInfo.new(0.4)
			for _, label in { title, subtitle } do
				TweenService:Create(label, fadeInfo, { TextTransparency = 1, TextStrokeTransparency = 1 })
					:Play()
			end
			task.delay(0.4, function()
				banner:Destroy()
			end)
		end)
	end)
end

return BreakthroughController
