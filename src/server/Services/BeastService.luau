--!strict
-- BeastService: spawns spirit beasts in each hunting tier, tracks their health,
-- updates health bars, and respawns them after they die.
-- Beasts never fight back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local BeastService = {}

export type Beast = {
	Tier: number,
	Model: Model,
	Body: BasePart,
	Radius: number, -- rough size, so punch range is measured to the beast's edge
	Health: number,
	MaxHealth: number,
	Alive: boolean,
	Bar: Frame,
	Label: TextLabel,
}

local beasts: { Beast } = {}
local folder: Folder

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function updateBar(beast: Beast)
	beast.Bar.Size = UDim2.fromScale(math.clamp(beast.Health / beast.MaxHealth, 0, 1), 1)
	beast.Label.Text = `{Format.Number(math.ceil(math.max(beast.Health, 0)))} / {Format.Number(beast.MaxHealth)}`
end

local function buildBeast(tier: number, position: Vector3, facing: Vector3): Beast
	local config = Config.Beasts[tier]
	local size = config.Size
	local model = Instance.new("Model")
	model.Name = config.Name

	-- Greybox body + head, standing on the zone floor and facing `facing`
	local base = CFrame.lookAt(position, position + facing)
	local body = makePart("Body", size, base * CFrame.new(0, size.Y / 2, 0), config.Color, model)
	local headSize = Vector3.new(size.X * 0.6, size.Y * 0.4, size.X * 0.6)
	makePart(
		"Head",
		headSize,
		base * CFrame.new(0, size.Y * 0.75, -size.Z / 2 - headSize.Z / 2 + 0.2),
		config.Color:Lerp(Color3.new(0, 0, 0), 0.2),
		model
	)
	model.PrimaryPart = body

	-- Name + health bar floating above
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 3, 0)
	gui.MaxDistance = 120
	gui.Parent = body

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.TextScaled = true
	nameLabel.Text = config.Name
	nameLabel.Parent = gui

	local back = Instance.new("Frame")
	back.Position = UDim2.fromScale(0, 0.55)
	back.Size = UDim2.fromScale(1, 0.45)
	back.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	back.BorderSizePixel = 0
	back.Parent = gui

	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	bar.BorderSizePixel = 0
	bar.Parent = back

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.ZIndex = 2
	label.Parent = back

	model.Parent = folder

	local beast: Beast = {
		Tier = tier,
		Model = model,
		Body = body,
		Radius = math.max(size.X, size.Z) / 2,
		Health = config.MaxHealth,
		MaxHealth = config.MaxHealth,
		Alive = true,
		Bar = bar,
		Label = label,
	}
	updateBar(beast)
	return beast
end

-- Nearest living beast whose edge is within `range` studs of `position`.
function BeastService.FindNearest(position: Vector3, range: number): Beast?
	local best: Beast? = nil
	local bestDistance = range
	for _, beast in beasts do
		if beast.Alive then
			local distance = (beast.Body.Position - position).Magnitude - beast.Radius
			if distance <= bestDistance then
				best = beast
				bestDistance = distance
			end
		end
	end
	return best
end

-- Every living beast whose edge is within `radius` studs of `position` (flat, ignoring height).
function BeastService.InRadius(position: Vector3, radius: number): { Beast }
	local found = {}
	for _, beast in beasts do
		local offset = beast.Body.Position - position
		if beast.Alive and Vector3.new(offset.X, 0, offset.Z).Magnitude - beast.Radius <= radius then
			table.insert(found, beast)
		end
	end
	return found
end

-- Every living beast touching the flat strip from `from` to `to` that is `halfWidth` wide on each side.
function BeastService.InPath(from: Vector3, to: Vector3, halfWidth: number): { Beast }
	local a = Vector3.new(from.X, 0, from.Z)
	local b = Vector3.new(to.X, 0, to.Z)
	local length = (b - a).Magnitude
	local direction = if length > 0 then (b - a) / length else Vector3.zero
	local found = {}
	for _, beast in beasts do
		if beast.Alive then
			local p = Vector3.new(beast.Body.Position.X, 0, beast.Body.Position.Z)
			local along = math.clamp((p - a):Dot(direction), 0, length)
			local closest = a + direction * along
			if (p - closest).Magnitude - beast.Radius <= halfWidth then
				table.insert(found, beast)
			end
		end
	end
	return found
end

-- Deal damage. Returns true if this hit killed the beast.
function BeastService.Damage(beast: Beast, amount: number): boolean
	if not beast.Alive then
		return false
	end
	beast.Health -= amount
	updateBar(beast)

	-- Quick white hit flash
	local body = beast.Body
	body.Color = Color3.new(1, 1, 1)
	task.delay(0.08, function()
		body.Color = Config.Beasts[beast.Tier].Color
	end)

	if beast.Health > 0 then
		return false
	end

	beast.Alive = false
	beast.Model.Parent = nil
	task.delay(Config.Beasts[beast.Tier].RespawnTime, function()
		beast.Health = beast.MaxHealth
		beast.Alive = true
		updateBar(beast)
		beast.Model.Parent = folder
	end)
	return true
end

function BeastService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Beasts"
	folder.Parent = Workspace

	local hunting = Workspace:WaitForChild("Map"):WaitForChild("HuntingGround")
	local width = Config.Map.HuntingGround.Width
	for tier, config in Config.Beasts do
		local zone = hunting:WaitForChild("Tier" .. tier):WaitForChild("Zone") :: BasePart
		local zoneConfig = Config.Map.HuntingGround.Tiers[tier]
		local random = Random.new(tier) -- same layout every server start
		local top = zone.Position.Y + zone.Size.Y / 2
		for _ = 1, config.Count do
			local x = random:NextNumber(zoneConfig.StartX + 10, zoneConfig.EndX - 6)
			local z = zone.Position.Z + random:NextNumber(-width / 2 + 6, width / 2 - 6)
			local facing = Vector3.new(-1, 0, random:NextNumber(-0.5, 0.5)) -- roughly toward the hub
			table.insert(beasts, buildBeast(tier, Vector3.new(x, top, z), facing))
		end
	end
end

return BeastService
