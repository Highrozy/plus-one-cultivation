--!strict
-- MapBuilder: builds the whole greybox map from Config when the server starts.
-- The map lives in code (and git), not in the place file.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local MAP = Config.Map
local HUB = MAP.Hub
local NAMES = Config.Names
local FLOOR_TOP = 0 -- top surface of the baseplate
local SLAB = 0.4 -- thickness of floor slabs laid on the baseplate

local function makePart(props: { [string]: any }, parent: Instance): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- Point on the hub's ring at `angle` degrees and `radius` studs from the center.
local function hubPoint(angle: number, radius: number, height: number): Vector3
	local a = math.rad(angle)
	return HUB.Center + Vector3.new(math.cos(a) * radius, height, math.sin(a) * radius)
end

-- A CFrame at a ring point whose front face looks at the hub center.
local function facingCenter(angle: number, radius: number, height: number): CFrame
	local position = hubPoint(angle, radius, height)
	return CFrame.lookAt(position, Vector3.new(HUB.Center.X, height, HUB.Center.Z))
end

-- A board with big text on its front face.
local function makeSign(text: string, cframe: CFrame, size: Vector3, parent: Instance): Part
	local board = makePart({
		Name = "Sign",
		Size = size,
		CFrame = cframe,
		Color = Color3.fromRGB(45, 35, 30),
	}, parent)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = text
	label.Parent = gui

	return board
end

local function buildHub(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Hub"
	folder.Parent = map

	-- Round floor (a cylinder lying flat)
	makePart({
		Name = "Floor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(SLAB, HUB.Radius * 2, HUB.Radius * 2),
		CFrame = CFrame.new(HUB.Center + Vector3.new(0, SLAB / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = HUB.FloorColor,
	}, folder)

	-- Ring wall made of short straight segments, with a gap for the gate at angle 0
	local segments = 48
	local segmentLength = 2 * math.pi * HUB.Radius / segments + 0.5
	local gateHalfAngle = math.deg((HUB.GateWidth / 2) / HUB.Radius)
	for i = 0, segments - 1 do
		local angle = (i + 0.5) * 360 / segments
		local fromGate = math.min(angle, 360 - angle) - 180 / segments -- angle of the segment's nearest edge
		if fromGate > gateHalfAngle then
			makePart({
				Name = "Wall",
				Size = Vector3.new(segmentLength, HUB.WallHeight, 2),
				CFrame = facingCenter(angle, HUB.Radius + 1, FLOOR_TOP + HUB.WallHeight / 2),
				Color = HUB.WallColor,
			}, folder)
		end
	end

	-- Gate towers and sign
	for _, side in { -1, 1 } do
		makePart({
			Name = "GateTower",
			Size = Vector3.new(5, HUB.WallHeight + 6, 5),
			Position = HUB.Center + Vector3.new(HUB.Radius + 1, FLOOR_TOP + (HUB.WallHeight + 6) / 2, side * (HUB.GateWidth / 2 + 2.5)),
			Color = HUB.WallColor:Lerp(Color3.new(0, 0, 0), 0.25),
		}, folder)
	end
	local signPosition = HUB.Center + Vector3.new(HUB.Radius + 1, FLOOR_TOP + HUB.WallHeight + 2, 0)
	makeSign(
		`{NAMES.HuntingGround} →`,
		CFrame.lookAt(signPosition, signPosition - Vector3.new(1, 0, 0)), -- readable from inside the hub
		Vector3.new(HUB.GateWidth, 4, 0.5),
		folder
	)

	-- Spawn pad in the middle
	local cfg = MAP.Spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = cfg.Size
	spawn.Position = HUB.Center + Vector3.new(0, SLAB + cfg.Size.Y / 2, 0)
	spawn.Color = cfg.Color
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0 -- no spawn forcefield
	spawn.Parent = folder
end

-- A grey practice dummy: body, head and a base.
local function makeDummy(cframe: CFrame, parent: Instance): Model
	local dummy = Instance.new("Model")
	dummy.Name = "Dummy"

	local grey = Color3.fromRGB(140, 120, 95)
	makePart({ Name = "Base", Size = Vector3.new(3, 1, 3), CFrame = cframe * CFrame.new(0, 0.5, 0), Color = grey }, dummy)
	local body = makePart({ Name = "Body", Size = Vector3.new(3, 4, 1.5), CFrame = cframe * CFrame.new(0, 3, 0), Color = grey }, dummy)
	makePart({ Name = "Head", Size = Vector3.new(2, 2, 2), CFrame = cframe * CFrame.new(0, 6, 0), Color = grey }, dummy)
	dummy.PrimaryPart = body

	dummy.Parent = parent
	return dummy
end

local function buildTrainingPlatforms(map: Folder)
	local row = MAP.TrainingRow
	local folder = Instance.new("Folder")
	folder.Name = "Training"
	folder.Parent = map

	for index, platform in Config.Training.Platforms do
		local angle = row.Angles[index]
		local model = Instance.new("Model")
		model.Name = "Platform" .. index

		-- The pad you stand on. TrainingService (build step 2) reads these attributes.
		local base = facingCenter(angle, row.RingRadius, FLOOR_TOP)
		local pad = makePart({
			Name = "Pad",
			Size = Vector3.new(row.PlatformSize, 1, row.PlatformSize),
			CFrame = base * CFrame.new(0, 0.5, 0),
			Color = platform.Color,
			Material = Enum.Material.Neon,
			Transparency = 0.2,
		}, model)
		pad:SetAttribute("PlatformIndex", index)
		model.PrimaryPart = pad

		-- Dummy at the back edge of the pad, facing the player
		local dummyCFrame = base * CFrame.new(0, 1, row.PlatformSize / 2 - 2) * CFrame.Angles(0, math.rad(180), 0)
		makeDummy(dummyCFrame, model)

		-- Sign above the dummy: name, multiplier and rebirth requirement
		local rebirthText = platform.RebirthsRequired == 0 and "Free" or `Needs {platform.RebirthsRequired} Rebirth`
		makeSign(
			`{platform.Name}\nx{platform.QiMultiplier} Qi\n{rebirthText}`,
			base * CFrame.new(0, 11, row.PlatformSize / 2),
			Vector3.new(row.PlatformSize, 5, 0.5),
			model
		)

		model.Parent = folder
	end
end

local function buildPavilion(map: Folder)
	local cfg = MAP.Pavilion
	local folder = Instance.new("Folder")
	folder.Name = "Pavilion"
	folder.Parent = map

	local base = facingCenter(cfg.Angle, cfg.RingRadius, FLOOR_TOP)
	local half = cfg.Size / 2

	makePart({
		Name = "Floor",
		Size = Vector3.new(cfg.Size, 1, cfg.Size),
		CFrame = base * CFrame.new(0, 0.5, 0),
		Color = cfg.FloorColor,
	}, folder)

	-- Four corner pillars
	for _, dx in { -1, 1 } do
		for _, dz in { -1, 1 } do
			makePart({
				Name = "Pillar",
				Size = Vector3.new(2, cfg.Height, 2),
				CFrame = base * CFrame.new(dx * (half - 2), cfg.Height / 2, dz * (half - 2)),
				Color = cfg.PillarColor,
			}, folder)
		end
	end

	-- Roof with a smaller top tier
	makePart({
		Name = "Roof",
		Size = Vector3.new(cfg.Size + 4, 1.5, cfg.Size + 4),
		CFrame = base * CFrame.new(0, cfg.Height + 0.75, 0),
		Color = cfg.RoofColor,
	}, folder)
	makePart({
		Name = "RoofTop",
		Size = Vector3.new(cfg.Size * 0.6, 3, cfg.Size * 0.6),
		CFrame = base * CFrame.new(0, cfg.Height + 3, 0),
		Color = cfg.RoofColor,
	}, folder)

	-- Lectern in the middle. The technique menu prompt goes here in build step 6.
	makePart({
		Name = "Lectern",
		Size = Vector3.new(3, 4, 3),
		CFrame = base * CFrame.new(0, 3, 0),
		Color = Color3.fromRGB(220, 190, 90),
	}, folder)

	-- Sign hanging under the front edge of the roof, facing the hub center
	makeSign(NAMES.Pavilion, base * CFrame.new(0, cfg.Height - 1.5, -half - 2.1), Vector3.new(cfg.Size - 4, 3, 0.5), folder)
end

local function buildHuntingGround(map: Folder)
	local cfg = MAP.HuntingGround
	local folder = Instance.new("Folder")
	folder.Name = "HuntingGround"
	folder.Parent = map

	-- Short path from the hub gate to Tier 1
	local pathStart = HUB.Center.X + HUB.Radius
	local pathEnd = cfg.Tiers[1].StartX
	makePart({
		Name = "Path",
		Size = Vector3.new(pathEnd - pathStart, SLAB, HUB.GateWidth),
		Position = Vector3.new((pathStart + pathEnd) / 2, FLOOR_TOP + SLAB / 2, HUB.Center.Z),
		Color = cfg.PathColor,
	}, folder)

	for index, tier in cfg.Tiers do
		local tierFolder = Instance.new("Folder")
		tierFolder.Name = "Tier" .. index
		tierFolder.Parent = folder

		local length = tier.EndX - tier.StartX
		local zone = makePart({
			Name = "Zone",
			Size = Vector3.new(length, SLAB, cfg.Width),
			Position = Vector3.new(tier.StartX + length / 2, FLOOR_TOP + SLAB / 2, HUB.Center.Z),
			Color = tier.Color,
		}, tierFolder)
		zone:SetAttribute("Tier", index)

		-- Gateway at the entrance of each tier: two posts, a beam and a sign
		local dark = tier.Color:Lerp(Color3.new(0, 0, 0), 0.4)
		local halfGate = 8
		for _, dz in { -1, 1 } do
			makePart({
				Name = "GatePost",
				Size = Vector3.new(2, 12, 2),
				Position = Vector3.new(tier.StartX, FLOOR_TOP + 6, HUB.Center.Z + dz * halfGate),
				Color = dark,
			}, tierFolder)
		end
		makePart({
			Name = "GateBeam",
			Size = Vector3.new(2, 2, halfGate * 2 + 2),
			Position = Vector3.new(tier.StartX, FLOOR_TOP + 13, HUB.Center.Z),
			Color = dark,
		}, tierFolder)

		local signPosition = Vector3.new(tier.StartX - 1.1, FLOOR_TOP + 16, HUB.Center.Z)
		makeSign(
			`Tier {index}: {NAMES.Tiers[index]}`,
			CFrame.lookAt(signPosition, signPosition - Vector3.new(1, 0, 0)), -- faces players walking out of the hub
			Vector3.new(halfGate * 2 + 2, 4, 0.5),
			tierFolder
		)
	end
end

function MapBuilder.Init()
	-- Rebuild from scratch so the map always matches the code.
	local old = Workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end

	-- Remove any spawn that came with the place template; ours is the only one.
	for _, item in Workspace:GetDescendants() do
		if item:IsA("SpawnLocation") then
			item:Destroy()
		end
	end

	local map = Instance.new("Folder")
	map.Name = "Map"

	buildHub(map)
	buildTrainingPlatforms(map)
	buildPavilion(map)
	buildHuntingGround(map)

	map.Parent = Workspace
end

return MapBuilder
