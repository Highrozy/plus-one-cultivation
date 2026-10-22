--!strict
-- Formulas: every game-math calculation in one place, shared by server and client.
-- The server uses these for the real numbers; the client only uses them for display.

local Config = require(script.Parent.Config)

export type State = {
	Qi: number,
	Stage: number,
	Manuals: { [string]: boolean }, -- owned manual ids
	Upgrades: { [string]: number }, -- upgrade id -> level
	Rebirths: number,
	RebirthBonus: number, -- total qi-per-tap bonus from rebirths (1 = +100%)
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
	return Config.Click.BaseQi * Formulas.StageMultiplier(state.Stage) * boost * (1 + state.RebirthBonus)
end

-- Qi per punch on a training dummy of this tier.
function Formulas.TrainingQi(state: State, tier: number): number
	return Formulas.QiPerClick(state) * Config.TrainingPads[tier].Multiplier
end

function Formulas.TrainingUnlocked(state: State, tier: number): boolean
	return state.Rebirths >= Config.TrainingPads[tier].Rebirths
end

-- Spirit stones needed for the next rebirth.
function Formulas.RebirthCost(state: State): number
	local rebirth = Config.Rebirth
	return math.floor(rebirth.BaseCost * rebirth.CostGrowth ^ state.Rebirths)
end

-- Bonus a rebirth right now would add (0.5 = +50% qi per tap).
function Formulas.RebirthGain(state: State): number
	local rebirth = Config.Rebirth
	return state.Stage * rebirth.BonusPerStage * rebirth.BonusDecay ^ state.Rebirths
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

function Formulas.BeastMaxHealth(info: Config.BeastInfo): number
	local zone = Config.ZoneHealth
	return zone.BeastBaseHealth * zone.HealthGrowth ^ (info.Zone - 1) * info.HealthScale
end

-- Total luck for a core grade roll (0.25 = +25%), from the Luck upgrade plus the beast's bonus.
function Formulas.Luck(state: State, beastBonus: number?): number
	return Formulas.UpgradeLevel(state, "Luck") * Config.Upgrades.Luck.PerLevel + (beastBonus or 0)
end

-- Chance of each grade (same order as Config.CoreGrades), adding up to 1.
function Formulas.GradeChances(luck: number): { number }
	local weights = {}
	local total = 0
	for index, grade in Config.CoreGrades do
		local weight = grade.Weight * (1 + luck) ^ (index - 1)
		weights[index] = weight
		total += weight
	end
	for index, weight in weights do
		weights[index] = weight / total
	end
	return weights
end

-- Picks a grade index at random using GradeChances.
function Formulas.RollGrade(luck: number): number
	local roll = math.random()
	for index, chance in Formulas.GradeChances(luck) do
		roll -= chance
		if roll <= 0 then
			return index
		end
	end
	return 1
end

-- Spirit stones for selling one core of this type and grade.
function Formulas.CoreSellPrice(coreId: string, grade: number): number
	return math.floor(Config.Cores[coreId].SellPrice * Config.CoreGrades[grade].PriceMultiplier)
end

-- "S-grade Wolf Core"
function Formulas.CoreName(coreId: string, grade: number): string
	return `{Config.CoreGrades[grade].Name}-grade {Config.Cores[coreId].Name}`
end

-- Furnace ingredients: one entry per core kind put in.
export type CoreStack = { Core: string, Grade: number, Count: number }

-- Total essence of a furnace load (cores add their sell price, stones add 1 per StonesPerEssence).
function Formulas.Essence(cores: { CoreStack }, stones: number): number
	local total = stones / Config.Alchemy.StonesPerEssence
	for _, stack in cores do
		total += Formulas.CoreSellPrice(stack.Core, stack.Grade) * stack.Count
	end
	return total
end

-- Which pill (index in Config.Pills) this much essence makes.
function Formulas.PillTier(essence: number): number
	local tier = 1
	for index, pill in Config.Pills do
		if essence >= pill.MinEssence then
			tier = index
		end
	end
	return tier
end

-- Chance of a real pill after winning the minigame.
function Formulas.PillSuccessChance(state: State, tier: number): number
	local chance = Config.Pills[tier].SuccessCap + Formulas.Luck(state) * Config.Alchemy.LuckToSuccess
	return math.min(chance, 1)
end

function Formulas.PillQi(tier: number, failed: boolean): number
	local qi = Config.Pills[tier].Qi
	return if failed then math.floor(qi * Config.Alchemy.FailedFraction) else qi
end

-- Seconds to absorb one pill in the seclusion cave.
function Formulas.PillAbsorbTime(tier: number, failed: boolean): number
	return if failed then Config.Seclusion.FailedAbsorbTime else Config.Pills[tier].AbsorbTime
end

-- Qi per second from just meditating in the seclusion cave.
function Formulas.MeditationQi(state: State): number
	return Formulas.QiPerClick(state) * Config.Seclusion.PassiveTaps
end

function Formulas.PillSellPrice(tier: number, failed: boolean): number
	local price = Config.Pills[tier].SellPrice
	return if failed then math.max(1, math.floor(price * Config.Alchemy.FailedFraction)) else price
end

-- Failed pills don't say what they were meant to be.
function Formulas.PillName(tier: number, failed: boolean): string
	if failed then
		return "Failed Pill"
	end
	local pill = Config.Pills[tier]
	return `{pill.Name} ({pill.Rarity})`
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
