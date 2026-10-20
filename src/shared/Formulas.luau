--!strict
-- Formulas: every game-math calculation in one place, shared by server and client.
-- The server uses these for the real numbers; the client only uses them for display.

local Config = require(script.Parent.Config)

export type State = {
	Qi: number,
	Stage: number,
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

function Formulas.QiPerClick(state: State): number
	return Config.Click.BaseQi * Formulas.StageMultiplier(state.Stage)
end

-- Total qi needed for the next stage, or nil at the final stage.
function Formulas.NextStageQi(stage: number): number?
	return Config.Realms.StageQi[stage + 1]
end

return Formulas
