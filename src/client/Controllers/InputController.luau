--!strict
-- InputController: a click or tap anywhere (not on a button) sends "I clicked"
-- and shows a "+qi" popup right away, so tapping feels instant.
-- Throttled here too, so taps the server would ignore aren't sent (or shown) at all.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local QiPopupController = require(script.Parent.QiPopupController)
local Ui = require(script.Parent.Ui)

local InputController = {}

function InputController.Init()
	local click = Remotes.Get("Click")
	local recent: { number } = {}

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or Players.LocalPlayer:GetAttribute("Meditating") then
			return -- tapped a button, the thumbstick, chat, etc. (or meditating: no taps)
		end
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end

		local now = os.clock()
		while recent[1] and now - recent[1] >= 1 do
			table.remove(recent, 1)
		end
		if #recent >= Config.Click.MaxPerSecond then
			return
		end
		table.insert(recent, now)
		click:FireServer()
		QiPopupController.Show(Formulas.QiPerClick(Ui.State()))
	end)
end

return InputController
