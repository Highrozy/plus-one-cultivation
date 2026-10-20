--!strict
-- TrainingService: standing on a training platform auto-punches its dummy for qi.
-- Locked platforms (not enough rebirths) give nothing and show a message.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local RealmService = require(script.Parent.RealmService)

local TrainingService = {}

type Platform = { Index: number, Pad: BasePart, Dummy: Model }

local platforms: { Platform } = {}
local lastLockedNotice: { [Player]: number } = {}

-- Which platform (if any) the character is standing on.
local function platformUnder(rootPart: BasePart): Platform?
	for _, platform in platforms do
		local pad = platform.Pad
		local offset = pad.CFrame:PointToObjectSpace(rootPart.Position)
		if math.abs(offset.X) <= pad.Size.X / 2 and math.abs(offset.Z) <= pad.Size.Z / 2 and offset.Y > 0 and offset.Y < 8 then
			return platform
		end
	end
	return nil
end

local function trainTick(punchFx: RemoteEvent, floatText: RemoteEvent, notify: RemoteEvent)
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player)
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local platform = rootPart and platformUnder(rootPart)
		local index = 0

		if data and platform then
			local config = Config.Training.Platforms[platform.Index]
			if data.Rebirths >= config.RebirthsRequired then
				index = platform.Index
				local qi = Formulas.TrainingQi(data, platform.Index)
				RealmService.AddQi(player, qi)
				punchFx:FireAllClients(player)
				local head = platform.Dummy:FindFirstChild("Head") :: BasePart
				floatText:FireClient(player, head.Position + Vector3.new(0, 2, 0), `+{Format.Number(qi)} Qi`, "Qi")
			elseif os.clock() - (lastLockedNotice[player] or 0) > 3 then
				lastLockedNotice[player] = os.clock()
				notify:FireClient(player, `{config.Name} needs {config.RebirthsRequired} rebirth(s)!`)
			end
		end

		player:SetAttribute("TrainingPlatform", index)
	end
end

function TrainingService.Init()
	-- MapBuilder has already built the platforms.
	for _, model in (Workspace:WaitForChild("Map"):WaitForChild("Training") :: Folder):GetChildren() do
		local pad = model:FindFirstChild("Pad") :: BasePart
		table.insert(platforms, {
			Index = pad:GetAttribute("PlatformIndex") :: number,
			Pad = pad,
			Dummy = model:FindFirstChild("Dummy") :: Model,
		})
	end

	local punchFx = Remotes.Get("PunchFx")
	local floatText = Remotes.Get("FloatText")
	local notify = Remotes.Get("Notify")

	task.spawn(function()
		while true do
			task.wait(1 / Config.Training.PunchesPerSecond)
			trainTick(punchFx, floatText, notify)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastLockedNotice[player] = nil
	end)
end

return TrainingService
