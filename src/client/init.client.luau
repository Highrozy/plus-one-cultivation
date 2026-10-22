--!strict
-- Client entry point: starts every UI/input controller in order.
-- Each controller is a ModuleScript in Controllers/ with one job and an Init() function.

local Controllers = script.Controllers

local ORDER = {
	"InputController",
	"QiPopupController",
	"HudController",
	"BreakthroughController",
	"ShopController",
	"BackpackController",
	"BrewController",
	"FurnaceController",
	"RebirthController",
	"CorePickupController",
	"NotifyController",
	"DevPanelController",
}

for _, name in ORDER do
	local controller = require(Controllers:WaitForChild(name)) :: any
	controller.Init()
end
