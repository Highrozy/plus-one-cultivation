--!strict
-- SafeZoneService: while a player stands inside any part tagged Config.SafeZoneTag,
-- everything in their pockets moves into their backpack (no cap).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local SafeZoneService = {}

local CHECK_INTERVAL = 0.5 -- seconds between checks

-- True if the player's character is inside any safe zone part.
local function isInSafeZone(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, zone in CollectionService:GetTagged(Config.SafeZoneTag) do
		if zone:IsA("BasePart") then
			local localPos = zone.CFrame:PointToObjectSpace(root.Position)
			local half = zone.Size / 2
			if
				math.abs(localPos.X) <= half.X
				and math.abs(localPos.Z) <= half.Z
				and localPos.Y >= -half.Y
				and localPos.Y <= half.Y + Config.SafeZoneHeight
			then
				return true
			end
		end
	end
	return false
end

function SafeZoneService.Init()
	local notify = Remotes.Get("Notify")
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local data = PlayerData.Get(player)
				if data and data.BeastCores > 0 and isInSafeZone(player) then
					local moved = PlayerData.EmptyPockets(data)
					PlayerData.Sync(player)
					notify:FireClient(
						player,
						`Stored {moved} {Config.Names.BeastCores} in your {Config.Names.Backpack}`
					)
				end
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return SafeZoneService
