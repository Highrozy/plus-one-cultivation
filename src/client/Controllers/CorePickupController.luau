--!strict
-- CorePickupController: hides the pickup prompt on other players' beast cores, and shows
-- "Pockets full" on your own cores when you can't carry more. The server still checks both.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Ui = require(script.Parent.Ui)

local CorePickupController = {}

local CORE_TAG = "BeastCore"

local function promptOf(core: Instance): ProximityPrompt?
	return core:FindFirstChildOfClass("ProximityPrompt")
		or core:WaitForChild("ProximityPrompt", 5) :: ProximityPrompt?
end

local function update(core: Instance)
	local prompt = promptOf(core)
	if not prompt then
		return
	end
	if core:GetAttribute("Owner") ~= Players.LocalPlayer.UserId then
		prompt.Enabled = false
		return
	end
	local state = Ui.State()
	local full = state.BeastCores >= Formulas.CoreCap(state)
	prompt.ActionText = if full then "Pockets full" else "Pick up"
end

function CorePickupController.Init()
	CollectionService:GetInstanceAddedSignal(CORE_TAG):Connect(function(core)
		task.spawn(update, core)
	end)
	Ui.OnStateChanged(function()
		for _, core in CollectionService:GetTagged(CORE_TAG) do
			task.spawn(update, core)
		end
	end)
end

return CorePickupController
