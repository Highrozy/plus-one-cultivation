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
	DamagePerQi = 1, -- punch damage = the player's qi x this
}

--------------------------------------------------------------------------
-- Beasts. Placeholder practice beasts: plain blocks, numbers will change.
-- Spawn markers: any part tagged "BeastSpawn" with a text attribute "Beast"
-- set to one of the ids below (e.g. "Hare") spawns that beast and respawns it.
--------------------------------------------------------------------------
Config.BeastSpawnTag = "BeastSpawn"
Config.BeastRespawnTime = 5 -- seconds after a marker's beast dies

export type BeastInfo = {
	Name: string,
	Color: Color3,
	Size: Vector3,
	MaxHealth: number,
	WalkSpeed: number,
	Damage: number, -- per hit on the player
	AttackCooldown: number, -- seconds between hits
	AttackRange: number, -- studs from the beast's edge to the player
	AggroRange: number, -- starts chasing players this close
	LeashRange: number, -- gives up and walks home past this distance from home
	WanderRadius: number,
	SpiritStones: number, -- given straight to the killer (every beast also drops 1 core)
}

Config.Beasts = {
	Hare = {
		Name = "Practice Hare",
		Color = Color3.fromRGB(230, 230, 220),
		Size = Vector3.new(2, 2, 3),
		MaxHealth = 10,
		WalkSpeed = 12,
		Damage = 5,
		AttackCooldown = 1.5,
		AttackRange = 3,
		AggroRange = 20,
		LeashRange = 50,
		WanderRadius = 12,
		SpiritStones = 1,
	},
	Boar = {
		Name = "Practice Boar",
		Color = Color3.fromRGB(120, 80, 60),
		Size = Vector3.new(4, 4, 6),
		MaxHealth = 60,
		WalkSpeed = 10,
		Damage = 15,
		AttackCooldown = 2,
		AttackRange = 3,
		AggroRange = 25,
		LeashRange = 50,
		WanderRadius = 12,
		SpiritStones = 5,
	},
} :: { [string]: BeastInfo }

-- Order of the DEV panel "Spawn" buttons.
Config.BeastOrder = { "Hare", "Boar" }

--------------------------------------------------------------------------
-- Loot. Every beast drops exactly one beast core as a pickup; only the killer can pick it up,
-- by holding the pickup key (E on PC, a button on phones).
-- Cores use the "BeastCoreModel" mesh in ServerStorage if it exists, else a plain ball.
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

Config.CoreSellPrice = 2 -- spirit stones per beast core

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
		Description = "Coming soon",
		BaseCost = 0,
		CostGrowth = 1,
		MaxLevel = 0,
		PerLevel = 0,
		ComingSoon = true,
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
