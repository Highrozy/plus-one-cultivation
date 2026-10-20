--!strict
-- Formulas: every game-math calculation in one place, shared by server and client.
-- The server uses these for the real numbers; the client only uses them for display.

local Config = require(script.Parent.Config)

export type State = {
	Qi: number,
	Stage: number,
	Rebirths: number,
	Techniques: { [string]: number }, -- technique Id -> level
}

local Formulas = {}

-- Techniques and skills are both "upgrades" bought at the Pavilion, looked up by Id.
local techniqueById = {}
for _, technique in Config.Techniques do
	techniqueById[technique.Id] = technique
end
for _, skill in Config.Skills do
	techniqueById[skill.Id] = skill
end

function Formulas.GetTechnique(id: string)
	return techniqueById[id]
end

function Formulas.MaxStage(): number
	return #Config.Realms.StageQi
end

-- "Qi Condensation 3" etc.
function Formulas.StageName(stage: number): string
	local remaining = stage
	for _, realm in Config.Realms.List do
		if remaining <= realm.Stages then
			return `{realm.Name} {remaining}`
		end
		remaining -= realm.Stages
	end
	return "???"
end

function Formulas.StageMultiplier(stage: number): number
	local realms = Config.Realms
	local multiplier = realms.StageMultiplier ^ (stage - 1)
	if stage >= realms.MajorBreakthroughStage then
		multiplier *= realms.MajorBreakthroughMultiplier
	end
	return multiplier
end

function Formulas.RebirthMultiplier(rebirths: number): number
	return 1 + rebirths * Config.Rebirth.QiBonusPerRebirth
end

local function techniqueBonus(state: State, id: string): number
	return (state.Techniques[id] or 0) * techniqueById[id].EffectPerLevel
end

-- Multiplier shared by every qi source.
local function baseQi(state: State): number
	return Config.Click.BaseQi * Formulas.StageMultiplier(state.Stage) * Formulas.RebirthMultiplier(state.Rebirths)
end

function Formulas.QiPerClick(state: State): number
	return baseQi(state) * (1 + techniqueBonus(state, "ClickQi"))
end

function Formulas.TrainingQi(state: State, platformIndex: number): number
	local platform = Config.Training.Platforms[platformIndex]
	return baseQi(state) * platform.QiMultiplier * (1 + techniqueBonus(state, "TrainQi"))
end

-- Damage of a normal punch (Heavy Strike is applied on top by the server).
function Formulas.PunchDamage(state: State): number
	local combat = Config.Combat
	return (combat.BaseDamage + state.Qi * combat.QiToDamage) * (1 + techniqueBonus(state, "FistDamage"))
end

function Formulas.HeavyStrikeMultiplier(level: number): number
	local heavy = techniqueById.HeavyStrike
	return heavy.BaseMultiplier + level * heavy.EffectPerLevel
end

-- Damage of one hit from a skill at the given level (level 1 = just learned).
function Formulas.SkillDamage(state: State, id: string): number
	local skill = techniqueById[id]
	local level = math.max(state.Techniques[id] or 0, 1)
	return Formulas.PunchDamage(state) * (skill.DamageMultiplier + (level - 1) * skill.DamagePerLevel)
end

function Formulas.TechniqueCost(id: string, currentLevel: number): number
	local technique = techniqueById[id]
	return math.floor(technique.BaseCost * technique.CostGrowth ^ currentLevel)
end

return Formulas
