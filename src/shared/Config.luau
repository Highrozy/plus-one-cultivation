--!strict
-- Config: every tunable number and display name lives here.
-- Change values here, not inside the services.

local Config = {}

--------------------------------------------------------------------------
-- Names (rename anything here later)
--------------------------------------------------------------------------
Config.Names = {
	Qi = "Qi",
	Stones = "Spirit Crystals",
	Cores = "Beast Cores",
	Pavilion = "Technique Pavilion",
	HuntingGround = "Hunting Ground",
	Tiers = { "Forest Edge", "Deep Woods", "Beast Den" },
}

--------------------------------------------------------------------------
-- Clicking / tapping
--------------------------------------------------------------------------
Config.Click = {
	MaxPerSecond = 5, -- server ignores taps beyond this (basic auto-clicker guard)
	BaseQi = 1, -- qi per tap before any multipliers
}

--------------------------------------------------------------------------
-- Realms. StageQi[i] = total qi needed to reach stage i.
-- Stages 1-9 = Qi Condensation 1-9, stages 10-18 = Foundation Establishment 1-9.
-- Stage 9 -> 10 is the major breakthrough (needs the button press).
--------------------------------------------------------------------------
Config.Realms = {
	List = {
		{ Name = "Qi Condensation", Stages = 9 },
		{ Name = "Foundation Establishment", Stages = 9 },
	},
	StageQi = {
		0, 250, 650, 1300, 2350, 4000, 6700, 11000, 18000, -- Qi Condensation 1-9
		29000, 47000, 73000, 111000, 166000, 245000, 360000, 530000, 770000, -- Foundation Establishment 1-9
	},
	StageMultiplier = 1.25, -- every stage-up multiplies qi gain by this
	MajorBreakthroughStage = 10, -- first stage of the second realm
	MajorBreakthroughMultiplier = 3, -- extra one-time multiplier from the major breakthrough
}

--------------------------------------------------------------------------
-- Rebirth (unlocks at the final stage)
--------------------------------------------------------------------------
Config.Rebirth = {
	QiBonusPerRebirth = 0.5, -- each rebirth adds +50% to all qi gain, forever
}

--------------------------------------------------------------------------
-- Training platforms (spirit veins). Standing on one auto-punches its dummy:
-- each auto-punch gives (tap qi x platform multiplier). Better platforms
-- unlock with rebirths. Order = left to right in the hub.
--------------------------------------------------------------------------
Config.Training = {
	PunchesPerSecond = 2,
	Platforms = {
		{ Name = "Low-Grade Spirit Vein", QiMultiplier = 1.5, RebirthsRequired = 0, Color = Color3.fromRGB(120, 200, 120) },
		{ Name = "Mid-Grade Spirit Vein", QiMultiplier = 2, RebirthsRequired = 1, Color = Color3.fromRGB(90, 170, 230) },
		{ Name = "High-Grade Spirit Vein", QiMultiplier = 4, RebirthsRequired = 2, Color = Color3.fromRGB(170, 110, 230) },
		{ Name = "Peak-Grade Spirit Vein", QiMultiplier = 6, RebirthsRequired = 3, Color = Color3.fromRGB(240, 190, 60) },
	},
}

--------------------------------------------------------------------------
-- Combat. Damage per punch = (BaseDamage + qi x QiToDamage) x fist bonuses.
--------------------------------------------------------------------------
Config.Combat = {
	BaseDamage = 10,
	QiToDamage = 1,
	PunchRange = 8, -- studs from your character to the edge of a beast
	AutoPunchInterval = 0.5, -- seconds between auto-combat punches when a beast is in range
}

--------------------------------------------------------------------------
-- Spirit beasts, one entry per hunting tier
--------------------------------------------------------------------------
Config.Beasts = {
	{
		Name = "Spirit Hare",
		MaxHealth = 60,
		Stones = 1,
		Cores = 1,
		Count = 6,
		RespawnTime = 4,
		Size = Vector3.new(3, 3, 4),
		Color = Color3.fromRGB(235, 235, 220),
	},
	{
		Name = "Iron-Hide Boar",
		MaxHealth = 6000,
		Stones = 8,
		Cores = 6,
		Count = 5,
		RespawnTime = 6,
		Size = Vector3.new(5, 5, 7),
		Color = Color3.fromRGB(110, 80, 60),
	},
	{
		Name = "Thunder Ape",
		MaxHealth = 250000,
		Stones = 60,
		Cores = 40,
		Count = 4,
		RespawnTime = 8,
		Size = Vector3.new(7, 10, 6),
		Color = Color3.fromRGB(60, 60, 90),
	},
}

--------------------------------------------------------------------------
-- Techniques (Technique Pavilion). Cost of the next level = BaseCost x CostGrowth^level.
-- Currency: "Stones" or "Cores".
--------------------------------------------------------------------------
Config.Techniques = {
	{
		Id = "ClickQi",
		Name = "Flowing Meridian Art",
		Kind = "Cultivation",
		Currency = "Stones",
		BaseCost = 5,
		CostGrowth = 1.5,
		MaxLevel = 25,
		EffectPerLevel = 0.25, -- +25% tap qi per level
	},
	{
		Id = "TrainQi",
		Name = "Still Lake Meditation",
		Kind = "Cultivation",
		Currency = "Stones",
		BaseCost = 8,
		CostGrowth = 1.5,
		MaxLevel = 25,
		EffectPerLevel = 0.25, -- +25% training platform qi per level
	},
	{
		Id = "FistDamage",
		Name = "Iron Bone Fist",
		Kind = "Fist",
		Currency = "Cores",
		BaseCost = 5,
		CostGrowth = 1.5,
		MaxLevel = 25,
		EffectPerLevel = 0.2, -- +20% punch damage per level
	},
	{
		Id = "HeavyStrike",
		Name = "Mountain-Splitting Strike",
		Kind = "Fist",
		Currency = "Cores",
		BaseCost = 15,
		CostGrowth = 1.6,
		MaxLevel = 25,
		EveryNthPunch = 5,
		BaseMultiplier = 2, -- every Nth punch deals x(BaseMultiplier + level) damage
		EffectPerLevel = 1,
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
