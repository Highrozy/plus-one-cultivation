--!strict
-- Config: every tunable number and display name lives here.
-- Change values here, not inside the services.

local Config = {}

--------------------------------------------------------------------------
-- Names (rename anything here later)
--------------------------------------------------------------------------
Config.Names = {
	Qi = "Qi",
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

return Config
