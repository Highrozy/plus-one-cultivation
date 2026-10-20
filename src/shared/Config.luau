--!strict
-- Config: every tunable number and display name lives here.
-- Change values here, not inside the services.

local Config = {}

--------------------------------------------------------------------------
-- Names (rename anything here later)
--------------------------------------------------------------------------
Config.Names = {
	Pavilion = "Technique Pavilion",
	HuntingGround = "Hunting Ground",
	Tiers = { "Forest Edge", "Deep Woods", "Beast Den" },
}

--------------------------------------------------------------------------
-- Training platforms (spirit veins). Standing on one auto-punches its dummy
-- for qi. Better platforms unlock with rebirths. Order = left to right.
--------------------------------------------------------------------------
Config.Training = {
	Platforms = {
		{ Name = "Low-Grade Spirit Vein", QiMultiplier = 1.5, RebirthsRequired = 0, Color = Color3.fromRGB(120, 200, 120) },
		{ Name = "Mid-Grade Spirit Vein", QiMultiplier = 2, RebirthsRequired = 1, Color = Color3.fromRGB(90, 170, 230) },
		{ Name = "High-Grade Spirit Vein", QiMultiplier = 4, RebirthsRequired = 2, Color = Color3.fromRGB(170, 110, 230) },
		{ Name = "Peak-Grade Spirit Vein", QiMultiplier = 6, RebirthsRequired = 3, Color = Color3.fromRGB(240, 190, 60) },
	},
}

--------------------------------------------------------------------------
-- Map (greybox)
-- A circular hub with spawn in the middle. Angles are measured around the
-- hub: 0 = the gate to the hunting ground (+X), 90 = +Z, 180 = back (-X).
--------------------------------------------------------------------------
Config.Map = {
	Hub = {
		Center = Vector3.new(-100, 0, 0),
		Radius = 60,
		FloorColor = Color3.fromRGB(165, 165, 175),
		WallHeight = 14,
		WallColor = Color3.fromRGB(110, 110, 125),
		GateWidth = 20,
	},

	Spawn = {
		Size = Vector3.new(14, 1, 14),
		Color = Color3.fromRGB(230, 230, 230),
	},

	TrainingRow = {
		RingRadius = 44, -- distance from hub center to each platform
		Angles = { 140, 165, 195, 220 }, -- one per platform, in Config.Training order
		PlatformSize = 12,
	},

	Pavilion = {
		Angle = 90,
		RingRadius = 40,
		Size = 22, -- square platform side length
		Height = 12,
		FloorColor = Color3.fromRGB(150, 110, 80),
		PillarColor = Color3.fromRGB(170, 40, 40),
		RoofColor = Color3.fromRGB(60, 60, 70),
	},

	HuntingGround = {
		Width = 70, -- Z width of every tier zone
		PathColor = Color3.fromRGB(170, 150, 110),
		Tiers = { -- X ranges, just outside the hub gate
			{ StartX = -30, EndX = 30, Color = Color3.fromRGB(90, 170, 80) },
			{ StartX = 36, EndX = 96, Color = Color3.fromRGB(200, 160, 50) },
			{ StartX = 102, EndX = 162, Color = Color3.fromRGB(150, 50, 60) },
		},
	},
}

return Config
