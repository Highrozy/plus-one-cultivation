--!strict
-- Config: every tunable number and display name lives here.
-- Change values here, not inside the services.

local Config = {}

--------------------------------------------------------------------------
-- Names (rename anything here later)
--------------------------------------------------------------------------
Config.Names = {
	Qi = "Qi",
	SpiritStones = "Spirit Stones",
	BeastCores = "Beast Cores",
	Backpack = "Backpack",
}

--------------------------------------------------------------------------
-- Clicking / tapping
--------------------------------------------------------------------------
Config.Click = {
	MaxPerSecond = 6, -- taps beyond this are ignored (basic auto-clicker guard)
	BaseQi = 1, -- qi per tap before any multipliers
}

--------------------------------------------------------------------------
-- Qi popups: "+5 Qi" appears at a random spot near the middle of the screen on every tap.
--------------------------------------------------------------------------
Config.QiPopup = {
	SpreadX = 0.18, -- how far from the center it can appear, as a fraction of screen width
	SpreadY = 0.15, -- same, as a fraction of screen height
	RiseDistance = 0.08, -- how far it floats up, as a fraction of screen height
	Lifetime = 0.8, -- seconds before it has faded out
	Color = Color3.fromRGB(120, 220, 255),
}

--------------------------------------------------------------------------
-- Realms. StageQi[i] = total qi needed to reach stage i.
-- Stages 1-9 = Qi Condensation 1-9, stages 10-18 = Foundation Establishment 1-9.
-- Every breakthrough is automatic as soon as the player has enough qi.
--------------------------------------------------------------------------
Config.Realms = {
	List = {
		{ Name = "Qi Condensation", Stages = 9 },
		{ Name = "Foundation Establishment", Stages = 9 },
	},
	-- stylua: ignore
	StageQi = {
		0, 250, 650, 1300, 2350, 4000, 6700, 11000, 18000, -- Qi Condensation 1-9
		29000, 47000, 73000, 111000, 166000, 245000, 360000, 530000, 770000, -- Foundation Establishment 1-9
	},
	StageMultiplier = 1.25, -- every stage-up multiplies qi per tap by this
	MajorRealmMultiplier = 3, -- extra one-time multiplier for reaching a new realm (FE1)
}

--------------------------------------------------------------------------
-- Player health. Max health grows with the same stage multiplier as qi per tap.
--------------------------------------------------------------------------
Config.Player = {
	BaseHealth = 100,
}

--------------------------------------------------------------------------
-- Combat. Tapping and auto-punch share one punch timer, so punches never go
-- faster than PunchesPerSecond either way.
--------------------------------------------------------------------------
Config.Combat = {
	PunchesPerSecond = 2,
	AutoPunch = true, -- punch the nearest beast in range without tapping
	PunchRange = 7, -- studs from the player to the beast's edge
	DamagePerQi = 1, -- punch damage = the player's total qi x this
}

--------------------------------------------------------------------------
-- Zones. Zone 1, 2, 3... each get tougher. A beast's max health is
-- BeastBaseHealth x HealthGrowth ^ (zone - 1) x its own HealthScale.
-- No gates: anyone can walk in, the beasts' damage is what stops you.
-- Any part tagged "ZoneSign" with a number attribute "Zone" shows that zone's name and
-- recommended qi above it. RecommendedQi is a hand-set guide for now.
--------------------------------------------------------------------------
Config.ZoneSignTag = "ZoneSign"

Config.ZoneHealth = {
	BeastBaseHealth = 300, -- a normal Zone 1 beast
	HealthGrowth = 10, -- every zone multiplies beast health by this
}

export type ZoneInfo = {
	Name: string,
	RecommendedQi: number,
}

Config.Zones = {
	{ Name = "Zone 1: Qi Wolf Den", RecommendedQi = 300 },
	{ Name = "Zone 2: Greater Wolf Hollow", RecommendedQi = 3000 },
	{ Name = "Zone 3: Wolf King's Lair", RecommendedQi = 30000 },
} :: { ZoneInfo }

--------------------------------------------------------------------------
-- Beasts. Plain blocks for now; looks come later.
-- Spawn markers: any part tagged "BeastSpawn" with a text attribute "Beast"
-- set to one of the ids below (e.g. "QiWolf") spawns that beast and respawns it.
--------------------------------------------------------------------------
Config.BeastSpawnTag = "BeastSpawn"
Config.BeastRespawnTime = 5 -- seconds after a marker's beast dies (unless the beast sets its own)

export type BeastInfo = {
	Name: string,
	Zone: number, -- which entry of Config.Zones it lives in (sets its health)
	HealthScale: number, -- x the zone's beast health (bosses are tougher)
	Color: Color3,
	Size: Vector3,
	WalkSpeed: number,
	Damage: number, -- per hit on the player
	AttackCooldown: number, -- seconds between hits
	AttackRange: number, -- studs from the beast's edge to the player
	AggroRange: number, -- starts chasing players this close
	LeashRange: number, -- gives up and walks home past this distance from home
	WanderRadius: number,
	SpiritStones: number, -- given straight to the killer
	Core: string, -- core type it drops (an id in Config.Cores); every beast drops exactly 1
	LuckBonus: number?, -- extra luck for its core's grade roll (0.15 = +15%)
	RespawnTime: number?, -- seconds, instead of Config.BeastRespawnTime
	Boss: boolean?, -- adds "BOSS" to its name
}

Config.Beasts = {
	QiWolf = {
		Name = "Qi Wolf",
		Zone = 1,
		HealthScale = 1,
		Color = Color3.fromRGB(110, 110, 125),
		Size = Vector3.new(2, 2.5, 4),
		WalkSpeed = 14,
		Damage = 8,
		AttackCooldown = 1.2,
		AttackRange = 3,
		AggroRange = 22,
		LeashRange = 50,
		WanderRadius = 12,
		SpiritStones = 3,
		Core = "WolfCore",
	},
	GreaterQiWolf = {
		Name = "Greater Qi Wolf",
		Zone = 2,
		HealthScale = 1,
		Color = Color3.fromRGB(70, 70, 90),
		Size = Vector3.new(3, 3.5, 5.5),
		WalkSpeed = 15,
		Damage = 40,
		AttackCooldown = 1.2,
		AttackRange = 3,
		AggroRange = 25,
		LeashRange = 55,
		WanderRadius = 12,
		SpiritStones = 15,
		Core = "GreaterWolfCore",
	},
	WolfKing = {
		Name = "Wolf King",
		Zone = 3,
		HealthScale = 3,
		Color = Color3.fromRGB(40, 40, 60),
		Size = Vector3.new(5, 5, 8),
		WalkSpeed = 13,
		Damage = 150,
		AttackCooldown = 1.5,
		AttackRange = 4,
		AggroRange = 30,
		LeashRange = 60,
		WanderRadius = 8,
		SpiritStones = 60,
		Core = "WolfKingCore",
		LuckBonus = 0.15,
		RespawnTime = 30,
		Boss = true,
	},
} :: { [string]: BeastInfo }

-- Order of the DEV panel "Spawn" buttons.
Config.BeastOrder = { "QiWolf", "GreaterQiWolf", "WolfKing" }

--------------------------------------------------------------------------
-- Beast cores. Each core type has a base sell price. Every dropped core rolls a grade,
-- and the grade multiplies the price. Grades go from F (common) to SSS (very rare).
-- Chance of a grade = its Weight / all weights. Luck makes higher grades likelier:
-- grade number n (F = 0, E = 1, ... SSS = 8) gets its weight x (1 + luck) ^ n.
--------------------------------------------------------------------------
export type CoreInfo = {
	Name: string,
	SellPrice: number, -- spirit stones for an F-grade core
}

Config.Cores = {
	WolfCore = { Name = "Wolf Core", SellPrice = 2 },
	GreaterWolfCore = { Name = "Greater Wolf Core", SellPrice = 10 },
	WolfKingCore = { Name = "Wolf King Core", SellPrice = 50 },
} :: { [string]: CoreInfo }

-- Order core types appear in the Sell tab.
Config.CoreOrder = { "WolfCore", "GreaterWolfCore", "WolfKingCore" }

export type GradeInfo = {
	Name: string,
	Weight: number, -- chance before luck (weights don't need to add up to 100)
	PriceMultiplier: number,
	Color: Color3,
}

-- From most common to rarest.
Config.CoreGrades = {
	{ Name = "F", Weight = 40, PriceMultiplier = 1, Color = Color3.fromRGB(150, 150, 150) },
	{ Name = "E", Weight = 25, PriceMultiplier = 1.5, Color = Color3.fromRGB(220, 220, 220) },
	{ Name = "D", Weight = 15, PriceMultiplier = 2, Color = Color3.fromRGB(120, 220, 120) },
	{ Name = "C", Weight = 10, PriceMultiplier = 3, Color = Color3.fromRGB(80, 200, 255) },
	{ Name = "B", Weight = 5, PriceMultiplier = 5, Color = Color3.fromRGB(80, 120, 255) },
	{ Name = "A", Weight = 3, PriceMultiplier = 8, Color = Color3.fromRGB(180, 80, 255) },
	{ Name = "S", Weight = 1.5, PriceMultiplier = 15, Color = Color3.fromRGB(255, 200, 50) },
	{ Name = "SS", Weight = 0.4, PriceMultiplier = 40, Color = Color3.fromRGB(255, 120, 40) },
	{ Name = "SSS", Weight = 0.1, PriceMultiplier = 100, Color = Color3.fromRGB(255, 50, 80) },
} :: { GradeInfo }

Config.RareGrade = 6 -- index in CoreGrades (6 = A); picking up this grade or higher gets a "Rare!" message

--------------------------------------------------------------------------
-- Loot. Every beast drops exactly one beast core as a pickup; only the killer can pick it up,
-- by holding the pickup key (E on PC, a button on phones).
-- Cores use the "BeastCoreModel" mesh in ServerStorage if it exists, else a plain ball,
-- colored by grade.
-- Players can carry CoreCap cores (more with the Pockets upgrade). Spirit stones have no cap.
--------------------------------------------------------------------------
Config.Loot = {
	CoreColor = Color3.fromRGB(170, 80, 255),
	CoreSize = 1.2,
	CoreLifetime = 30, -- seconds before an uncollected core disappears
	CoreHoldDuration = 0.5, -- seconds to hold the pickup key
	CoreCap = 5, -- cores a player can carry before upgrades
}

--------------------------------------------------------------------------
-- Safe zone and backpack. Standing inside any part tagged "SafeZone" (a big
-- see-through box around spawn) moves everything in the player's pockets into
-- their backpack, which has no cap. Selling and the alchemy furnace only use the backpack.
--------------------------------------------------------------------------
Config.SafeZoneTag = "SafeZone"
Config.SafeZoneHeight = 20 -- studs above a zone part's top that still count as inside

--------------------------------------------------------------------------
-- Shops. Any part tagged "ShopPad" with a text attribute "Shop" set to
-- "Manuals" or "Upgrades" opens that shop while a player stands on it.
--------------------------------------------------------------------------
Config.ShopPadTag = "ShopPad"
Config.ShopRange = 12 -- studs from a pad's center where buying still works (server check)

Config.ShopNames = {
	Manuals = "Manual Shop",
	Upgrades = "Upgrade Shop",
}

-- Basic manuals, bought once each with spirit stones.
-- Kind "Foundation" raises punch damage by BonusDamagePercent (5 = +5%).
-- Several foundation manuals add together (+5% and +25% = +30%).
-- Kinds "Skill" and "Technique" are placeholders for now: buying one only marks it owned.
export type ManualInfo = {
	Name: string,
	Kind: string,
	Price: number,
	Description: string,
	BonusDamagePercent: number?,
}

Config.Manuals = {
	FistFoundation = {
		Name = "Basic Fist Foundation",
		Kind = "Foundation",
		Price = 10,
		Description = "+5% punch damage",
		BonusDamagePercent = 5,
	},
	StoneFistFoundation = {
		Name = "Stone Fist Foundation",
		Kind = "Foundation",
		Price = 50,
		Description = "+25% punch damage",
		BonusDamagePercent = 25,
	},
	PalmStrike = {
		Name = "Basic Palm Strike",
		Kind = "Skill",
		Price = 25,
		Description = "Skill (placeholder, does nothing yet)",
	},
	BreathingTechnique = {
		Name = "Basic Breathing Technique",
		Kind = "Technique",
		Price = 25,
		Description = "Technique (placeholder, does nothing yet)",
	},
} :: { [string]: ManualInfo }

-- Order manuals appear in the Buy tab.
Config.ManualOrder = { "FistFoundation", "StoneFistFoundation", "PalmStrike", "BreathingTechnique" }

-- Levelled upgrades. Cost of the next level = BaseCost x CostGrowth ^ (current level).
-- ComingSoon upgrades are shown greyed out and can't be bought.
export type UpgradeInfo = {
	Name: string,
	Description: string,
	BaseCost: number,
	CostGrowth: number,
	MaxLevel: number,
	PerLevel: number,
	ComingSoon: boolean?,
}

Config.Upgrades = {
	Pockets = {
		Name = "Bigger Pockets",
		Description = "+2 beast cores you can carry",
		BaseCost = 10,
		CostGrowth = 1.6,
		MaxLevel = 10,
		PerLevel = 2, -- extra core cap per level
	},
	TrainingBoost = {
		Name = "Training Boost",
		Description = "+10% qi per tap",
		BaseCost = 15,
		CostGrowth = 1.6,
		MaxLevel = 20,
		PerLevel = 0.1, -- extra qi-per-tap multiplier per level
	},
	Luck = {
		Name = "Luck",
		Description = "+2% luck for better core grades",
		BaseCost = 20,
		CostGrowth = 1.7,
		MaxLevel = 10,
		PerLevel = 0.02, -- extra luck per level (see Config.CoreGrades)
	},
} :: { [string]: UpgradeInfo }

Config.UpgradeOrder = { "Pockets", "TrainingBoost", "Luck" }

--------------------------------------------------------------------------
-- Training pads. Any part tagged "TrainingPad" with a number attribute "Tier"
-- (1 = the first entry below) gets a training dummy in its middle (a child part
-- named "TrainingDummy" is used if the map already has one, else a plain block).
-- While a player stands on an unlocked pad, their punches (tap or auto) hit the
-- dummy instead of beasts, giving qi per tap x Multiplier per punch.
-- Any number of players can share a pad.
--------------------------------------------------------------------------
Config.TrainingPadTag = "TrainingPad"
Config.TrainingStandHeight = 6 -- studs above a pad's top that still count as standing on it

export type TrainingPadInfo = {
	Name: string,
	Multiplier: number, -- x qi per tap, per punch
	Rebirths: number, -- rebirths needed to use it
}

Config.TrainingPads = {
	{ Name = "Training Pad I", Multiplier = 1.5, Rebirths = 0 },
	{ Name = "Training Pad II", Multiplier = 2, Rebirths = 1 },
	{ Name = "Training Pad III", Multiplier = 4, Rebirths = 2 },
	{ Name = "Training Pad IV", Multiplier = 6, Rebirths = 3 },
} :: { TrainingPadInfo }

--------------------------------------------------------------------------
-- Rebirth. Spend spirit stones to reset qi and stage (stones, cores, manuals and
-- upgrades are kept) for a permanent qi-per-tap bonus.
-- Cost of the next rebirth = BaseCost x CostGrowth ^ (rebirths done).
-- Bonus gained = stage reached x BonusPerStage x BonusDecay ^ (rebirths done),
-- so each rebirth is worth less per stage than the one before.
-- Bonuses add together: +100% then +85% = +185% (x2.85 qi per tap).
--------------------------------------------------------------------------
Config.Rebirth = {
	BaseCost = 100,
	CostGrowth = 2.5,
	BonusPerStage = 0.1, -- +10% qi per tap per stage reached, on the first rebirth
	BonusDecay = 0.85, -- each rebirth makes the next one worth 15% less per stage
}

-- Short messages (e.g. "Not enough Spirit Stones") near the top of the screen.
Config.Notify = {
	Lifetime = 2, -- seconds on screen
}

return Config
