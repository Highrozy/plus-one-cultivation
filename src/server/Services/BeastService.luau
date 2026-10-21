--!strict
-- BeastService: spawns beasts, runs their simple AI and tracks their health.
-- Beasts wander near home, chase players who come close (or hit them), hit back,
-- and walk home if they're pulled too far away.
-- Beasts come from parts tagged Config.BeastSpawnTag (respawn after death)
-- or from the DEV panel (no respawn). Also labels zone signs (Config.ZoneSignTag).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local LootService = require(script.Parent.LootService)

export type Beast = {
	Id: string,
	Info: Config.BeastInfo,
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Fill: Frame,
	MaxHealth: number,
	Health: number,
	Home: Vector3,
	Marker: BasePart?,
	Target: Player?,
	Returning: boolean,
	Dead: boolean,
	LastAttack: number,
	NextWander: number,
}

local BeastService = {}

local AI_INTERVAL = 0.2 -- seconds between AI updates
local HIP_HEIGHT = 1 -- studs between the ground and the bottom of the root part
local FALL_LIMIT = 50 -- a beast this far below its home fell out of the world

local beasts: { Beast } = {}
local folder: Folder

-- Distance on the ground (ignores height).
local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Roughly how far the beast's edge is from its center.
local function radiusOf(info: Config.BeastInfo): number
	return math.max(info.Size.X, info.Size.Z) / 2
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function buildModel(info: Config.BeastInfo): (Model, BasePart, Humanoid, Frame)
	local model = Instance.new("Model")
	model.Name = info.Name

	-- Invisible root that hovers HIP_HEIGHT above the ground (the humanoid needs that gap
	-- to detect the floor), with the visible body welded under it reaching the ground.
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = info.Size - Vector3.new(0, HIP_HEIGHT, 0)
	root.Transparency = 1
	root.Parent = model
	model.PrimaryPart = root

	local function addPart(name: string, size: Vector3, color: Color3, offset: CFrame)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.Massless = true
		part.CFrame = root.CFrame * offset
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	addPart("Body", info.Size, info.Color, CFrame.new(0, -HIP_HEIGHT / 2, 0))
	-- A smaller block in front so you can tell which way it faces.
	local headSize = Vector3.new(info.Size.X * 0.6, info.Size.Y * 0.6, info.Size.X * 0.6)
	local headColor = info.Color:Lerp(Color3.new(0, 0, 0), 0.25)
	addPart("Head", headSize, headColor, CFrame.new(0, info.Size.Y * 0.2, -(info.Size.Z + headSize.Z) / 2))

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15 -- with R15, HipHeight = gap under the root
	humanoid.HipHeight = HIP_HEIGHT
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = info.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model

	-- Name and health bar above the beast.
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 40)
	billboard.StudsOffset = Vector3.new(0, info.Size.Y / 2 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 100
	billboard.Parent = root

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 0.5)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Text = if info.Boss then `BOSS: {info.Name}` else info.Name
	nameLabel.Parent = billboard

	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	bar.BorderSizePixel = 0
	bar.Position = UDim2.fromScale(0, 0.6)
	bar.Size = UDim2.fromScale(1, 0.35)
	bar.Parent = billboard

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = bar

	return model, root, humanoid, fill
end

-- Floating damage number that rises and fades (stays even if the beast dies).
local function showDamage(position: Vector3, amount: number)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position + Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1)
	attachment.Parent = workspace.Terrain

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(80, 30)
	billboard.AlwaysOnTop = true
	billboard.Adornee = attachment
	billboard.Parent = attachment

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 80)
	label.TextStrokeTransparency = 0.3
	label.Text = `-{Format.Number(amount)}`
	label.Parent = billboard

	local info = TweenInfo.new(0.7)
	TweenService:Create(billboard, info, { StudsOffset = Vector3.new(0, 2, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(attachment, 0.8)
end

function BeastService.Spawn(id: string, position: Vector3, marker: BasePart?): Beast?
	local info = Config.Beasts[id]
	if not info then
		warn(`[BeastService] Unknown beast id "{id}"`)
		return nil
	end
	local model, root, humanoid, fill = buildModel(info)
	model:PivotTo(CFrame.new(position + Vector3.new(0, (info.Size.Y + HIP_HEIGHT) / 2, 0)))
	model.Parent = folder
	root:SetNetworkOwner(nil) -- the server moves beasts, so players can't fling them

	local beast: Beast = {
		Id = id,
		Info = info,
		Model = model,
		Root = root,
		Humanoid = humanoid,
		Fill = fill,
		MaxHealth = Formulas.BeastMaxHealth(info),
		Health = Formulas.BeastMaxHealth(info),
		Home = position,
		Marker = marker,
		Target = nil,
		Returning = false,
		Dead = false,
		LastAttack = 0,
		NextWander = 0,
	}
	table.insert(beasts, beast)
	return beast
end

-- The living beast whose edge is closest to `position`, if any is within `range`.
function BeastService.FindNearest(position: Vector3, range: number): Beast?
	local best: Beast? = nil
	local bestDistance = range
	for _, beast in beasts do
		local distance = flatDistance(position, beast.Root.Position) - radiusOf(beast.Info)
		if not beast.Dead and distance <= bestDistance then
			best = beast
			bestDistance = distance
		end
	end
	return best
end

local function updateBar(beast: Beast)
	beast.Fill.Size = UDim2.fromScale(math.clamp(beast.Health / beast.MaxHealth, 0, 1), 1)
end

-- Takes a beast out of the world. Marker beasts come back after the respawn time.
local function remove(beast: Beast)
	beast.Dead = true
	local index = table.find(beasts, beast)
	if index then
		table.remove(beasts, index)
	end
	beast.Model:Destroy()

	local marker = beast.Marker
	if marker then
		task.delay(beast.Info.RespawnTime or Config.BeastRespawnTime, function()
			if marker:IsDescendantOf(workspace) then
				BeastService.Spawn(beast.Id, marker.Position, marker)
			end
		end)
	end
end

local function kill(beast: Beast, killer: Player)
	local ground = beast.Root.Position - Vector3.new(0, (beast.Info.Size.Y + HIP_HEIGHT) / 2, 0)
	LootService.Drop(killer, beast.Info, ground)
	remove(beast)
end

function BeastService.Damage(beast: Beast, amount: number, attacker: Player)
	if beast.Dead then
		return
	end
	beast.Health -= amount
	updateBar(beast)
	showDamage(beast.Root.Position + Vector3.new(0, beast.Info.Size.Y / 2 + 1, 0), amount)
	if not beast.Returning then
		beast.Target = attacker -- hitting a beast makes it fight back
	end
	if beast.Health <= 0 then
		kill(beast, attacker)
	end
end

-- Removes every beast (DEV panel). Marker beasts come back after the respawn time.
function BeastService.ClearAll()
	for _, beast in table.clone(beasts) do
		remove(beast)
	end
end

local function nearestPlayer(position: Vector3, range: number): Player?
	local best: Player? = nil
	local bestDistance = range
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player)
		local distance = root and flatDistance(position, root.Position)
		if distance and distance <= bestDistance then
			best = player
			bestDistance = distance
		end
	end
	return best
end

local function think(beast: Beast, now: number)
	local info = beast.Info
	local position = beast.Root.Position
	local humanoid = beast.Humanoid

	if not beast.Model:IsDescendantOf(workspace) or position.Y < beast.Home.Y - FALL_LIMIT then
		remove(beast)
		return
	end

	if flatDistance(position, beast.Home) > info.LeashRange then
		beast.Target = nil
		beast.Returning = true
	end

	if beast.Returning then
		humanoid:MoveTo(beast.Home)
		if flatDistance(position, beast.Home) < 3 then
			beast.Returning = false
			beast.Health = beast.MaxHealth -- heals up once it's back home
			updateBar(beast)
		end
		return
	end

	local targetRoot = beast.Target and aliveRoot(beast.Target)
	if not targetRoot then
		beast.Target = nearestPlayer(position, info.AggroRange)
		targetRoot = beast.Target and aliveRoot(beast.Target)
	end

	if targetRoot then
		local distance = flatDistance(position, targetRoot.Position) - radiusOf(info)
		if distance <= info.AttackRange then
			humanoid:MoveTo(position) -- stand still and hit
			if now - beast.LastAttack >= info.AttackCooldown then
				beast.LastAttack = now
				local targetHumanoid = (targetRoot.Parent :: Instance):FindFirstChildOfClass("Humanoid")
				if targetHumanoid then
					targetHumanoid:TakeDamage(info.Damage)
				end
			end
		else
			humanoid:MoveTo(targetRoot.Position)
		end
	elseif now >= beast.NextWander then
		beast.NextWander = now + 3 + math.random() * 3
		local angle = math.random() * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.random() * info.WanderRadius
		humanoid:MoveTo(beast.Home + offset)
	end
end

local function watchMarker(marker: Instance)
	if not marker:IsA("BasePart") then
		return
	end
	local id = marker:GetAttribute("Beast")
	if typeof(id) ~= "string" then
		warn(`[BeastService] {marker:GetFullName()} needs a text attribute "Beast"`)
		return
	end
	BeastService.Spawn(id, marker.Position, marker)
end

-- Zone name and recommended qi floating over each zone sign.
local function labelZoneSign(sign: Instance)
	local zone = sign:GetAttribute("Zone")
	local info = typeof(zone) == "number" and Config.Zones[zone]
	if not sign:IsA("BasePart") or not info then
		warn(`[BeastService] {sign:GetFullName()} needs a number attribute "Zone" (1-{#Config.Zones})`)
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(260, 60)
	billboard.StudsOffset = Vector3.new(0, sign.Size.Y / 2 + 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 200
	billboard.Parent = sign

	local lines = { info.Name, `Recommended {Config.Names.Qi}: {Format.Number(info.RecommendedQi)}` }
	for index, text in lines do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, (index - 1) * 0.5)
		label.Size = UDim2.fromScale(1, 0.5)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = if index == 1 then Color3.new(1, 1, 1) else Color3.fromRGB(120, 220, 255)
		label.TextStrokeTransparency = 0.3
		label.Text = text
		label.Parent = billboard
	end
end

function BeastService.Init()
	for _, sign in CollectionService:GetTagged(Config.ZoneSignTag) do
		labelZoneSign(sign)
	end
	CollectionService:GetInstanceAddedSignal(Config.ZoneSignTag):Connect(labelZoneSign)

	folder = Instance.new("Folder")
	folder.Name = "Beasts"
	folder.Parent = workspace

	for _, marker in CollectionService:GetTagged(Config.BeastSpawnTag) do
		watchMarker(marker)
	end
	CollectionService:GetInstanceAddedSignal(Config.BeastSpawnTag):Connect(watchMarker)

	task.spawn(function()
		while true do
			task.wait(AI_INTERVAL)
			local now = os.clock()
			for _, beast in table.clone(beasts) do
				if not beast.Dead then
					think(beast, now)
				end
			end
		end
	end)
end

return BeastService
