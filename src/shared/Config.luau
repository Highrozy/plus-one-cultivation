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
	SpiritStones: number, -- given straight to the killer
	BeastCores: number, -- dropped on the ground as pickups
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
		BeastCores = 1,
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
		BeastCores = 3,
	},
} :: { [string]: BeastInfo }

-- Order of the DEV panel "Spawn" buttons.
Config.BeastOrder = { "Hare", "Boar" }

--------------------------------------------------------------------------
-- Loot. Beast cores drop as glowing balls; only the killer can pick them up.
--------------------------------------------------------------------------
Config.Loot = {
	CoreColor = Color3.fromRGB(170, 80, 255),
	CoreSize = 1.2,
	CoreLifetime = 30, -- seconds before an uncollected core disappears
	CoreScatter = 3, -- studs the cores spread out around the beast
}

return Config
