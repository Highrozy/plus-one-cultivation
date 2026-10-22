--!strict
-- AlchemyService: refining pills at a furnace pad (see Config.Alchemy for the rules).
-- "Refine" checks the ingredients, takes them out of the backpack and tells the client to
-- start the brewing minigame. "Finish" ends that brew: a won minigame rolls the pill's
-- success chance, anything else gives a failed pill.
-- The minigame itself runs on the client; the server only checks it took a believable time.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local AlchemyService = {}

local notify: RemoteEvent

-- The brew each player is in the middle of: the pill tier and when it started.
local brewing: { [Player]: { Tier: number, Started: number } } = {}

-- Name label floating over each furnace pad.
local function labelPad(pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FurnaceLabel"
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "Alchemy Furnace"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
	billboard.Parent = pad
end

local function isNearFurnace(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, pad in CollectionService:GetTagged(Config.FurnacePadTag) do
		if pad:IsA("BasePart") then
			local distance = (pad.Position - root.Position) * Vector3.new(1, 0, 1)
			if distance.Magnitude <= Config.FurnaceRange + math.max(pad.Size.X, pad.Size.Z) / 2 then
				return true
			end
		end
	end
	return false
end

local function isWholeNumber(value: any, min: number): boolean
	return typeof(value) == "number" and value == math.floor(value) and value >= min and value < math.huge
end

-- Turns what the client sent into a clean ingredient list, or nil if anything is wrong
-- (unknown cores, more kinds than allowed, the same kind twice, not enough in the backpack).
local function readIngredients(data: PlayerData.Data, load: any): ({ Formulas.CoreStack }?, number)
	if typeof(load) ~= "table" or typeof(load.Cores) ~= "table" or not isWholeNumber(load.Stones, 0) then
		return nil, 0
	end
	local stones = load.Stones :: number
	if stones > data.SpiritStones or #load.Cores < 1 or #load.Cores > Config.Alchemy.MaxCoreKinds then
		return nil, 0
	end
	local cores: { Formulas.CoreStack } = {}
	local seen: { [string]: boolean } = {}
	for _, stack in load.Cores do
		if typeof(stack) ~= "table" then
			return nil, 0
		end
		local id, grade, count = stack.Core, stack.Grade, stack.Count
		if typeof(id) ~= "string" or not Config.Cores[id] then
			return nil, 0
		end
		if not isWholeNumber(grade, 1) or grade > #Config.CoreGrades or not isWholeNumber(count, 1) then
			return nil, 0
		end
		local key = `{id}_{grade}`
		local owned = (data.Bag[id] or {})[grade] or 0
		if seen[key] or count > owned then
			return nil, 0
		end
		seen[key] = true
		table.insert(cores, { Core = id, Grade = grade, Count = count })
	end
	return cores, stones
end

local function finish(player: Player, data: PlayerData.Data, won: any)
	local brew = brewing[player]
	if not brew then
		return
	end
	brewing[player] = nil
	local fairWin = won == true and os.clock() - brew.Started >= Config.Alchemy.MinBrewTime
	local success = fairWin and math.random() < Formulas.PillSuccessChance(data, brew.Tier)
	PlayerData.AddPills(data, brew.Tier, not success, 1)
	PlayerData.Sync(player)
	if success then
		notify:FireClient(player, `Success! {Formulas.PillName(brew.Tier, false)}`)
	elseif fairWin then
		notify:FireClient(player, "The pill cracked at the last moment... Failed Pill")
	else
		notify:FireClient(player, "The flow broke... Failed Pill")
	end
end

local function refine(player: Player, data: PlayerData.Data, load: any)
	local old = brewing[player]
	if old and os.clock() - old.Started > Config.Alchemy.MaxBrewTime then
		finish(player, data, false) -- the client never reported back; that brew failed
	end
	if brewing[player] or not isNearFurnace(player) then
		return
	end
	local cores, stones = readIngredients(data, load)
	if not cores then
		notify:FireClient(player, "Those ingredients aren't in your backpack")
		return
	end
	for _, stack in cores do
		PlayerData.AddBagCores(data, stack.Core, stack.Grade, -stack.Count)
	end
	data.SpiritStones -= stones
	PlayerData.Sync(player)

	local tier = Formulas.PillTier(Formulas.Essence(cores, stones))
	brewing[player] = { Tier = tier, Started = os.clock() }
	Remotes.Get("BrewStart"):FireClient(player, tier)
end

function AlchemyService.Init()
	notify = Remotes.Get("Notify")

	for _, pad in CollectionService:GetTagged(Config.FurnacePadTag) do
		labelPad(pad)
	end
	CollectionService:GetInstanceAddedSignal(Config.FurnacePadTag):Connect(labelPad)

	Remotes.Get("Furnace").OnServerEvent:Connect(function(player, action, arg)
		local data = PlayerData.Get(player)
		if not data then
			return
		end
		if action == "Refine" then
			refine(player, data, arg)
		elseif action == "Finish" then
			finish(player, data, arg)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		brewing[player] = nil
	end)
end

return AlchemyService
