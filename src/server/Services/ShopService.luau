--!strict
-- ShopService: buying manuals and upgrades, and selling beast cores, for spirit stones.
-- Shops are parts tagged Config.ShopPadTag with a "Shop" attribute ("Manuals" or "Upgrades").
-- The client opens the menu when the player stands on a pad; the server only checks that
-- the player is near a pad of the right shop and can afford it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local ShopService = {}

local notify: RemoteEvent

-- True if the player is standing near a pad for this shop.
local function isNearShop(player: Player, shop: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, pad in CollectionService:GetTagged(Config.ShopPadTag) do
		if pad:IsA("BasePart") and pad:GetAttribute("Shop") == shop then
			local distance = (pad.Position - root.Position) * Vector3.new(1, 0, 1)
			if distance.Magnitude <= Config.ShopRange + math.max(pad.Size.X, pad.Size.Z) / 2 then
				return true
			end
		end
	end
	return false
end

local function spend(player: Player, data: PlayerData.Data, price: number): boolean
	if data.SpiritStones < price then
		notify:FireClient(player, `Not enough {Config.Names.SpiritStones}`)
		return false
	end
	data.SpiritStones -= price
	return true
end

-- action -> { shop the player must be at, handler }
local ACTIONS: { [string]: { Shop: string, Run: (Player, PlayerData.Data, any) -> () } } = {
	BuyManual = {
		Shop = "Manuals",
		Run = function(player, data, id)
			local info = Config.Manuals[id]
			if not info or data.Manuals[id] or not spend(player, data, info.Price) then
				return
			end
			data.Manuals[id] = true
			notify:FireClient(player, `Learned {info.Name}`)
		end,
	},
	-- Sells from the backpack only (pockets are emptied into it at a safe zone).
	-- which: "All" sells every core, or { Core = id, Grade = n } sells all cores of that type and grade
	SellCores = {
		Shop = "Manuals",
		Run = function(player, data, which)
			local earned = 0
			for id, grades in data.Bag do
				for grade, count in grades do
					local picked = which == "All"
						or typeof(which) == "table" and which.Core == id and which.Grade == grade
					if picked and count > 0 then
						earned += count * Formulas.CoreSellPrice(id, grade)
						PlayerData.AddBagCores(data, id, grade, -count)
					end
				end
			end
			if earned == 0 then
				notify:FireClient(player, `No {Config.Names.BeastCores} in your {Config.Names.Backpack}`)
				return
			end
			data.SpiritStones += earned
			notify:FireClient(player, `Sold for {earned} {Config.Names.SpiritStones}`)
		end,
	},
	BuyUpgrade = {
		Shop = "Upgrades",
		Run = function(player, data, id)
			if typeof(id) ~= "string" then
				return
			end
			local cost = Formulas.UpgradeCost(data, id)
			if not cost or not spend(player, data, cost) then
				return
			end
			data.Upgrades[id] = Formulas.UpgradeLevel(data, id) + 1
		end,
	},
}

-- Name label floating over each shop pad, so any map's pads are easy to find.
local function labelPad(pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	local shop = pad:GetAttribute("Shop")
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ShopLabel"
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = Config.ShopNames[shop] or "Shop"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
	billboard.Parent = pad
end

function ShopService.Init()
	notify = Remotes.Get("Notify")

	for _, pad in CollectionService:GetTagged(Config.ShopPadTag) do
		labelPad(pad)
	end
	CollectionService:GetInstanceAddedSignal(Config.ShopPadTag):Connect(labelPad)

	Remotes.Get("Shop").OnServerEvent:Connect(function(player, action, arg)
		local data = PlayerData.Get(player)
		local entry = ACTIONS[action]
		if not data or not entry or not isNearShop(player, entry.Shop) then
			return
		end
		entry.Run(player, data, arg)
		PlayerData.Sync(player)
	end)
end

return ShopService
