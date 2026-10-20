--!strict
-- TechniqueService: the Technique Pavilion. Adds the ProximityPrompt that opens
-- the menu, and handles "buy technique X" requests (validating cost and distance).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local TechniqueService = {}

local MAX_BUY_DISTANCE = 30 -- must be standing at the pavilion to buy

function TechniqueService.Init()
	local lectern = Workspace:WaitForChild("Map"):WaitForChild("Pavilion"):WaitForChild("Lectern") :: BasePart

	-- The client opens the menu when this prompt is triggered.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PavilionPrompt"
	prompt.ActionText = "Learn Techniques"
	prompt.ObjectText = Config.Names.Pavilion
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = lectern

	local notify = Remotes.Get("Notify")

	Remotes.Get("BuyTechnique").OnServerEvent:Connect(function(player, id)
		local data = PlayerData.Get(player)
		local technique = typeof(id) == "string" and Formulas.GetTechnique(id)
		if not data or not technique then
			return
		end

		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not rootPart or (rootPart.Position - lectern.Position).Magnitude > MAX_BUY_DISTANCE then
			return
		end

		local level = data.Techniques[id] or 0
		if level >= technique.MaxLevel then
			notify:FireClient(player, `{technique.Name} is already max level!`)
			return
		end

		local cost = Formulas.TechniqueCost(id, level)
		local currency = technique.Currency -- "Stones" or "Cores"
		local balance = if currency == "Stones" then data.Stones else data.Cores
		if balance < cost then
			notify:FireClient(player, `Not enough {Config.Names[currency]}!`)
			return
		end

		if currency == "Stones" then
			data.Stones -= cost
		else
			data.Cores -= cost
		end
		data.Techniques[id] = level + 1
		PlayerData.Sync(player)
	end)
end

return TechniqueService
