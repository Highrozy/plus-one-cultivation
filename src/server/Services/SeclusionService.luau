--!strict
-- SeclusionService: meditating on a seclusion pad (see Config.Seclusion for the rules).
-- "Enter" (standing on a pad) floats the character above it and starts the passive qi
-- trickle. "Consume" takes one pill and absorbs its qi bit by bit over its absorb time;
-- while one is absorbing, more pills wait in a queue (up to Config.Seclusion.MaxQueue).
-- "Unqueue" takes one queued pill (or "All") back into the backpack.
-- "Leave" (or dying) ends it: qi the current pill hasn't given yet is lost, and queued
-- pills go back into the backpack.
-- While meditating the player has the "Meditating" attribute, which turns off taps and punches.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local RealmService = require(script.Parent.RealmService)

local SeclusionService = {}

local TICK = 0.25 -- seconds between absorb steps
local PAD_HEIGHT = 6 -- studs above a pad's top that still count as standing on it

type Absorb =
	{ Tier: number, Failed: boolean, Total: number, Given: number, Started: number, Duration: number }
type QueuedPill = { Tier: number, Failed: boolean }
type Session = { Pad: BasePart, Root: BasePart, Absorb: Absorb?, Queue: { QueuedPill }, Passive: number }

local sessions: { [Player]: Session } = {}
local remote: RemoteEvent
local notify: RemoteEvent

-- Name label floating over each seclusion pad.
local function labelPad(pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SeclusionLabel"
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "Seclusion"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
	billboard.Parent = pad
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return root
end

local function padUnder(root: BasePart): BasePart?
	for _, pad in CollectionService:GetTagged(Config.SeclusionPadTag) do
		if pad:IsA("BasePart") then
			local localPos = pad.CFrame:PointToObjectSpace(root.Position)
			local half = pad.Size / 2
			if
				math.abs(localPos.X) <= half.X + 2
				and math.abs(localPos.Z) <= half.Z + 2
				and localPos.Y >= -half.Y
				and localPos.Y <= half.Y + PAD_HEIGHT
			then
				return pad
			end
		end
	end
	return nil
end

-- Give the qi absorbed since the last step.
local function stepAbsorb(player: Player, absorb: Absorb)
	local fraction = math.clamp((os.clock() - absorb.Started) / absorb.Duration, 0, 1)
	local due = math.floor(absorb.Total * fraction)
	if due > absorb.Given then
		RealmService.AddQi(player, due - absorb.Given)
		absorb.Given = due
	end
end

local function leave(player: Player, why: string?)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	player:SetAttribute("Meditating", nil)

	local absorb = session.Absorb
	if absorb then
		stepAbsorb(player, absorb)
		local lost = absorb.Total - absorb.Given
		if lost > 0 then
			notify:FireClient(player, `You left early: {Format.Number(lost)} {Config.Names.Qi} lost`)
		end
	end
	-- Pills still waiting in the queue go back into the backpack.
	local data = PlayerData.Get(player)
	if data and #session.Queue > 0 then
		for _, pill in session.Queue do
			PlayerData.AddPills(data, pill.Tier, pill.Failed, 1)
		end
		PlayerData.Sync(player)
	end

	-- Put the character down in front of the pad (only if it's still the same body).
	local root = session.Root
	if root.Parent and root.Parent == player.Character then
		root.Anchored = false
		local pad = session.Pad
		local top = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
		local spot = top + pad.CFrame.LookVector * (pad.Size.Z / 2 + 4) + Vector3.new(0, 3, 0)
		root.CFrame = CFrame.lookAt(spot, spot + pad.CFrame.LookVector)
	end
	remote:FireClient(player, "Left", why)
end

local function enter(player: Player)
	if sessions[player] then
		return
	end
	local root = aliveRoot(player)
	local pad = root and padUnder(root)
	if not root or not pad then
		return
	end
	sessions[player] = { Pad = pad, Root = root, Absorb = nil, Queue = {}, Passive = 0 }
	player:SetAttribute("Meditating", true)

	-- Float above the pad's center, facing out of the cave.
	local spot = pad.Position + Vector3.new(0, pad.Size.Y / 2 + Config.Seclusion.FloatHeight, 0)
	local look = pad.CFrame.LookVector * Vector3.new(1, 0, 1)
	root.Anchored = true
	root.CFrame = CFrame.lookAt(spot, spot + look)
	remote:FireClient(player, "Entered")
end

local function startAbsorb(player: Player, session: Session, tier: number, failed: boolean)
	local duration = Formulas.PillAbsorbTime(tier, failed)
	session.Absorb = {
		Tier = tier,
		Failed = failed,
		Total = Formulas.PillQi(tier, failed),
		Given = 0,
		Started = os.clock(),
		Duration = duration,
	}
	remote:FireClient(player, "Absorb", tier, failed, duration)
end

local function consume(player: Player, data: PlayerData.Data, which: any)
	local session = sessions[player]
	if not session then
		return
	end
	if typeof(which) ~= "table" or typeof(which.Tier) ~= "number" or not Config.Pills[which.Tier] then
		return
	end
	local tier = which.Tier :: number
	local failed = which.Failed == true
	local pills = if failed then data.FailedPills else data.Pills
	if (pills[tier] or 0) <= 0 then
		return
	end
	if session.Absorb and #session.Queue >= Config.Seclusion.MaxQueue then
		notify:FireClient(player, `The queue is full ({Config.Seclusion.MaxQueue} pills)`)
		return
	end
	PlayerData.AddPills(data, tier, failed, -1)
	PlayerData.Sync(player)

	if session.Absorb then
		table.insert(session.Queue, { Tier = tier, Failed = failed })
		remote:FireClient(player, "Queue", session.Queue)
	else
		startAbsorb(player, session, tier, failed)
	end
end

-- Take one queued pill (by its place in the queue), or all of them, back into the backpack.
local function unqueue(player: Player, data: PlayerData.Data, index: any)
	local session = sessions[player]
	if not session then
		return
	end
	local removed: { QueuedPill } = {}
	if index == "All" then
		removed = session.Queue
		session.Queue = {}
	elseif typeof(index) == "number" and session.Queue[index] then
		table.insert(removed, table.remove(session.Queue, index) :: QueuedPill)
	end
	if #removed == 0 then
		return
	end
	for _, pill in removed do
		PlayerData.AddPills(data, pill.Tier, pill.Failed, 1)
	end
	PlayerData.Sync(player)
	remote:FireClient(player, "Queue", session.Queue)
end

local function tick(dt: number)
	for player, session in sessions do
		local data = PlayerData.Get(player)
		if not data or aliveRoot(player) ~= session.Root then
			leave(player)
			continue
		end
		local absorb = session.Absorb
		if absorb then
			stepAbsorb(player, absorb)
			if absorb.Given >= absorb.Total or os.clock() - absorb.Started >= absorb.Duration then
				session.Absorb = nil
				notify:FireClient(player, `Absorbed {Format.Number(absorb.Total)} {Config.Names.Qi}`)
				local nextPill = table.remove(session.Queue, 1)
				if nextPill then
					startAbsorb(player, session, nextPill.Tier, nextPill.Failed)
					remote:FireClient(player, "Queue", session.Queue)
				else
					remote:FireClient(player, "AbsorbEnd")
				end
			end
		end
		-- Passive qi, handed out once per second.
		session.Passive += dt
		if session.Passive >= 1 then
			session.Passive -= 1
			local amount = Formulas.MeditationQi(data)
			RealmService.AddQi(player, amount)
			remote:FireClient(player, "Qi", amount)
		end
	end
end

function SeclusionService.Init()
	remote = Remotes.Get("Seclusion")
	notify = Remotes.Get("Notify")

	for _, pad in CollectionService:GetTagged(Config.SeclusionPadTag) do
		labelPad(pad)
	end
	CollectionService:GetInstanceAddedSignal(Config.SeclusionPadTag):Connect(labelPad)

	remote.OnServerEvent:Connect(function(player, action, arg)
		local data = PlayerData.Get(player)
		if not data then
			return
		end
		if action == "Enter" then
			enter(player)
		elseif action == "Leave" then
			leave(player)
		elseif action == "Consume" then
			consume(player, data, arg)
		elseif action == "Unqueue" then
			unqueue(player, data, arg)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)

	task.spawn(function()
		while true do
			tick(task.wait(TICK))
		end
	end)
end

return SeclusionService
