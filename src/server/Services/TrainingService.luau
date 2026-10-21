--!strict
-- TrainingService: training pads with a dummy to punch for qi.
-- Pads are parts tagged Config.TrainingPadTag with a number attribute "Tier".
-- CombatService calls TryPunchDummy on every punch; if the player is standing on
-- an unlocked pad, the punch hits that pad's dummy instead of a beast.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local RealmService = require(script.Parent.RealmService)

local TrainingService = {}

local DUMMY_SIZE = Vector3.new(2, 5, 2)
local DUMMY_COLOR = Color3.fromRGB(200, 160, 110)
local LOCKED_NOTICE_COOLDOWN = 3 -- seconds between "needs N rebirths" messages

local notify: RemoteEvent
local trainingQi: RemoteEvent
local lastLockedNotice: { [Player]: number } = {}

-- "1 rebirth", "3 rebirths"
local function rebirthsText(count: number): string
	return `{count} rebirth{if count == 1 then "" else "s"}`
end

local function tierOf(pad: BasePart): number?
	local tier = pad:GetAttribute("Tier")
	if typeof(tier) == "number" and Config.TrainingPads[tier] then
		return tier
	end
	return nil
end

-- The tagged pad this position is standing on (inside its outline, a little above its top).
local function padAt(position: Vector3): BasePart?
	for _, pad in CollectionService:GetTagged(Config.TrainingPadTag) do
		if pad:IsA("BasePart") and tierOf(pad) then
			local relative = pad.CFrame:PointToObjectSpace(position)
			local top = pad.Size.Y / 2
			if
				math.abs(relative.X) <= pad.Size.X / 2
				and math.abs(relative.Z) <= pad.Size.Z / 2
				and relative.Y >= top
				and relative.Y <= top + Config.TrainingStandHeight
			then
				return pad
			end
		end
	end
	return nil
end

local function addLabel(parent: BasePart, text: string, offset: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TrainingLabel"
	billboard.Size = UDim2.fromOffset(220, 50)
	billboard.StudsOffset = Vector3.new(0, offset, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
	billboard.Parent = parent
end

-- Give a new pad its dummy and its name label.
local function setUpPad(pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	local tier = tierOf(pad)
	if not tier then
		warn(
			`[TrainingService] {pad:GetFullName()} needs a number attribute "Tier" (1-{#Config.TrainingPads})`
		)
		return
	end
	local dummy = pad:FindFirstChild("TrainingDummy") :: BasePart?
	if not dummy then
		local part = Instance.new("Part")
		part.Name = "TrainingDummy"
		part.Size = DUMMY_SIZE
		part.Color = DUMMY_COLOR
		part.Anchored = true
		part.CFrame = pad.CFrame * CFrame.new(0, pad.Size.Y / 2 + DUMMY_SIZE.Y / 2, 0)
		part.Parent = pad
		dummy = part
	end
	local info = Config.TrainingPads[tier]
	local unlock = if info.Rebirths > 0 then `\n(needs {rebirthsText(info.Rebirths)})` else ""
	addLabel(dummy :: BasePart, `{info.Name}\nx{info.Multiplier} Qi{unlock}`, 4)
end

-- Quick flash so a hit is visible.
local function flash(dummy: BasePart)
	local color = dummy:GetAttribute("BaseColor") :: Color3?
	if not color then
		color = dummy.Color
		dummy:SetAttribute("BaseColor", color)
	end
	dummy.Color = Color3.new(1, 1, 1)
	TweenService:Create(dummy, TweenInfo.new(0.2), { Color = color }):Play()
end

-- Punch the dummy of the pad the player stands on, if it's unlocked.
-- Returns true if it punched (the caller has already checked the punch timer).
function TrainingService.TryPunchDummy(player: Player, root: BasePart): boolean
	local data = PlayerData.Get(player)
	local pad = padAt(root.Position)
	if not data or not pad then
		return false
	end
	local tier = tierOf(pad) :: number
	if not Formulas.TrainingUnlocked(data, tier) then
		local now = os.clock()
		if now - (lastLockedNotice[player] or 0) >= LOCKED_NOTICE_COOLDOWN then
			lastLockedNotice[player] = now
			notify:FireClient(player, `Needs {rebirthsText(Config.TrainingPads[tier].Rebirths)}`)
		end
		return false
	end
	local amount = Formulas.TrainingQi(data, tier)
	RealmService.AddQi(player, amount)
	trainingQi:FireClient(player, amount)
	local dummy = pad:FindFirstChild("TrainingDummy")
	if dummy and dummy:IsA("BasePart") then
		flash(dummy)
	end
	return true
end

function TrainingService.Init()
	notify = Remotes.Get("Notify")
	trainingQi = Remotes.Get("TrainingQi")

	for _, pad in CollectionService:GetTagged(Config.TrainingPadTag) do
		setUpPad(pad)
	end
	CollectionService:GetInstanceAddedSignal(Config.TrainingPadTag):Connect(setUpPad)

	Players.PlayerRemoving:Connect(function(player)
		lastLockedNotice[player] = nil
	end)
end

return TrainingService
