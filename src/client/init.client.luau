--!strict
-- Client entry point: starts every UI/input controller in order.
-- Each controller is a ModuleScript in Controllers/ with one job and an Init() function.

local Controllers = script.Controllers

local ORDER = {
	"InputController",
	"AnimController",
	"FloatTextController",
	"LootFxController",
	"HudController",
	"PavilionController",
	"SkillFxController",
	"SkillBarController",
	"TribulationController",
	"DevPanelController",
}

for _, name in ORDER do
	local controller = require(Controllers:WaitForChild(name)) :: any
	controller.Init()
end
