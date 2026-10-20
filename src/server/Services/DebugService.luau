--!strict
-- DebugService: Studio-only testing shortcuts (never active in a live server).
--   * The in-game DEV panel (DevPanelController) sends DevCommand(name).
--   * Test scripts can call ServerStorage.DebugCommand:Invoke(player, name, amount).
-- Commands: "Qi", "Stones", "Cores", "Rebirths" (add amount), "NextStage", "ToQC9", "ToFE9",
-- "Get" (returns a copy of the data).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local RealmService = require(script.Parent.RealmService)

local DebugService = {}

local STAGE_QI = Config.Realms.StageQi

local function run(player: Player, name: string, amount: number?)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	local function qiUpTo(target: number)
		if data.Qi < target then
			RealmService.AddQi(player, target - data.Qi)
		end
	end

	if name == "Qi" then
		RealmService.AddQi(player, amount or 0)
	elseif name == "Stones" then
		data.Stones += amount or 0
	elseif name == "Cores" then
		data.Cores += amount or 0
	elseif name == "Rebirths" then
		data.Rebirths += amount or 0
	elseif name == "NextStage" then
		local nextQi = STAGE_QI[data.Stage + 1]
		if nextQi then
			qiUpTo(nextQi)
		end
	elseif name == "ToQC9" then
		qiUpTo(STAGE_QI[Config.Realms.MajorBreakthroughStage]) -- also enough to break through
	elseif name == "ToFE9" then
		data.Stage = math.max(data.Stage, Config.Realms.MajorBreakthroughStage)
		qiUpTo(STAGE_QI[#STAGE_QI])
	end
	PlayerData.Sync(player)
	return table.clone(data)
end

function DebugService.Init()
	if not RunService:IsStudio() then
		return
	end

	local command = Instance.new("BindableFunction")
	command.Name = "DebugCommand"
	command.OnInvoke = run
	command.Parent = ServerStorage

	local amounts = { Stones = 500, Cores = 500, Rebirths = 1 }
	Remotes.Get("DevCommand").OnServerEvent:Connect(function(player, name)
		if typeof(name) == "string" and Players:FindFirstChild(player.Name) then
			run(player, name, amounts[name])
		end
	end)
end

return DebugService
