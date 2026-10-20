--!strict
-- Formulas: every game-math calculation in one place, shared by server and client.
-- The server uses these for the real numbers; the client only uses them for display.

local Config = require(script.Parent.Config)

export type State = {
	Qi: number,
	Stage: number,
	Manuals: { [string]: boolean }, -- owned manual ids
	Upgrades: { [string]: number }, -- upgrade id -> level
}

local Formulas = {}

function Formulas.MaxStage(): number
	return #Config.Realms.StageQi
end

-- Which realm a stage is in, and the stage number inside that realm.
function Formulas.RealmOf(stage: number): (number, number)
	local remaining = stage
	for index, realm in Config.Realms.List do
		if remaining <= realm.Stages then
			return index, remaining
		end
		remaining -= realm.Stages
	end
	return #Config.Realms.List, remaining
end

-- "Qi Condensation 3" etc.
function Formulas.StageName(stage: number): string
	local realmIndex, inRealm = Formulas.RealmOf(stage)
	return `{Config.Realms.List[realmIndex].Name} {inRealm}`
end

-- True if this stage is the first stage of a realm (a major breakthrough).
function Formulas.IsNewRealm(stage: number): boolean
	local _, inRealm = Formulas.RealmOf(stage)
	return stage > 1 and inRealm == 1
end

function Formulas.StageMultiplier(stage: number): number
	local realms = Config.Realms
	local multiplier = realms.StageMultiplier ^ (stage - 1)
	local realmIndex = Formulas.RealmOf(stage)
	return multiplier * realms.MajorRealmMultiplier ^ (realmIndex - 1)
end

function Formulas.UpgradeLevel(state: State, id: string): number
	return state.Upgrades[id] or 0
end

-- Spirit stones for the next level of an upgrade, or nil if maxed / coming soon.
function Formulas.UpgradeCost(state: State, id: string): number?
	local info = Config.Upgrades[id]
	local level = Formulas.UpgradeLevel(state, id)
	if not info or info.ComingSoon or level >= info.MaxLevel then
		return nil
	end
	return math.floor(info.BaseCost * info.CostGrowth ^ level)
end

function Formulas.QiPerClick(state: State): number
	local boost = 1 + Formulas.UpgradeLevel(state, "TrainingBoost") * Config.Upgrades.TrainingBoost.PerLevel
	return Config.Click.BaseQi * Formulas.StageMultiplier(state.Stage) * boost
end

-- Total bonus damage percent from owned foundation manuals (they add together: 5 + 25 = 30%).
function Formulas.FoundationPercent(state: State): number
	local total = 0
	for id in state.Manuals do
		local info = Config.Manuals[id]
		total += if info then info.BonusDamagePercent or 0 else 0
	end
	return total
end

function Formulas.PunchDamage(state: State): number
	return state.Qi * Config.Combat.DamagePerQi * (1 + Formulas.FoundationPercent(state) / 100)
end

-- How many beast cores the player can carry.
function Formulas.CoreCap(state: State): number
	return Config.Loot.CoreCap + Formulas.UpgradeLevel(state, "Pockets") * Config.Upgrades.Pockets.PerLevel
end

function Formulas.MaxHealth(stage: number): number
	return math.floor(Config.Player.BaseHealth * Formulas.StageMultiplier(stage))
end

-- Total qi needed for the next stage, or nil at the final stage.
function Formulas.NextStageQi(stage: number): number?
	return Config.Realms.StageQi[stage + 1]
end

return Formulas
