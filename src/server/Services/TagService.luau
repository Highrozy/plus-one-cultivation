--!strict
-- TagService: the overhead tag on every player showing realm + stage + rebirths,
-- so everyone in the lobby can see who is ahead.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)

local TagService = {}

local function tagText(player: Player): (string, string)
	local stage = player:GetAttribute("Stage") :: number? or 1
	local rebirths = player:GetAttribute("Rebirths") :: number? or 0
	return Formulas.StageName(stage), `Rebirths: {rebirths}`
end

local function addTag(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10) :: BasePart?
	if not head then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "RealmTag"
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.MaxDistance = 80
	gui.Parent = head

	local realm = Instance.new("TextLabel")
	realm.Size = UDim2.fromScale(1, 0.6)
	realm.BackgroundTransparency = 1
	realm.TextColor3 = Color3.fromRGB(255, 225, 120)
	realm.TextStrokeTransparency = 0.2
	realm.TextScaled = true
	realm.Font = Enum.Font.GothamBold
	realm.Parent = gui

	local rebirths = Instance.new("TextLabel")
	rebirths.Position = UDim2.fromScale(0, 0.6)
	rebirths.Size = UDim2.fromScale(1, 0.4)
	rebirths.BackgroundTransparency = 1
	rebirths.TextColor3 = Color3.fromRGB(200, 170, 255)
	rebirths.TextStrokeTransparency = 0.2
	rebirths.TextScaled = true
	rebirths.Parent = gui

	local function refresh()
		realm.Text, rebirths.Text = tagText(player)
	end
	refresh()
	local a = player:GetAttributeChangedSignal("Stage"):Connect(refresh)
	local b = player:GetAttributeChangedSignal("Rebirths"):Connect(refresh)
	gui.Destroying:Connect(function()
		a:Disconnect()
		b:Disconnect()
	end)
end

function TagService.Init()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			addTag(player, character)
		end)
		if player.Character then
			task.spawn(addTag, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return TagService
