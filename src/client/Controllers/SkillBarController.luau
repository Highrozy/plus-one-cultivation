--!strict
-- SkillBarController: the skill buttons (bottom right) with cooldown timers.
-- Keyboard: the key in Config.Skills (Q / R / F). Phones: tap the buttons.
-- Skills you haven't learned show as locked; learn them at the Technique Pavilion.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local SkillBarController = {}

local BUTTON_SIZE = 76

function SkillBarController.Init()
	local screen = Ui.Screen("SkillBar", 1)
	local useSkill = Remotes.Get("UseSkill")

	local bar = Ui.New("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -150), -- above the phone jump button
		Size = UDim2.fromOffset((BUTTON_SIZE + 8) * #Config.Skills, BUTTON_SIZE),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Ui.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		Parent = bar,
	})

	local readyAt: { [string]: number } = {}
	local buttons = {}

	local function tryUse(id: string)
		local level = Ui.State().Techniques[id] or 0
		if level < 1 then
			return
		end
		if os.clock() < (readyAt[id] or 0) then
			return
		end
		useSkill:FireServer(id)
	end

	for index, skill in Config.Skills do
		local button = Ui.Button({
			LayoutOrder = index,
			Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
			BackgroundColor3 = Color3.fromRGB(40, 90, 130),
			Text = "",
			Parent = bar,
		})
		local nameLabel = Ui.Label({
			Size = UDim2.fromScale(1, 0.62),
			Text = skill.Name,
			TextWrapped = true,
			Parent = button,
		})
		local keyLabel = Ui.Label({
			Position = UDim2.fromScale(0, 0.64),
			Size = UDim2.fromScale(1, 0.36),
			Text = `[{skill.Key}]`,
			TextColor3 = Color3.fromRGB(255, 230, 140),
			Parent = button,
		})
		-- Dark overlay that shrinks as the cooldown runs out
		local cover = Ui.New("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = button,
		})
		Ui.Corner(12).Parent = cover
		local timer = Ui.Label({ Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 4, Parent = button })

		button.Activated:Connect(function()
			tryUse(skill.Id)
		end)
		buttons[skill.Id] = { skill = skill, button = button, name = nameLabel, key = keyLabel, cover = cover, timer = timer }
	end

	-- Start the cooldown display when the server confirms we used a skill.
	Remotes.Get("SkillFx").OnClientEvent:Connect(function(player: Player, id: string)
		local entry = buttons[id]
		if player == game:GetService("Players").LocalPlayer and entry then
			readyAt[id] = os.clock() + entry.skill.Cooldown
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		for _, skill in Config.Skills do
			if input.KeyCode == Enum.KeyCode[skill.Key] then
				tryUse(skill.Id)
			end
		end
	end)

	-- Locked/unlocked look
	Ui.OnStateChanged(function()
		local state = Ui.State()
		for id, entry in buttons do
			local learned = (state.Techniques[id] or 0) >= 1
			entry.button.BackgroundColor3 = if learned then Color3.fromRGB(40, 90, 130) else Color3.fromRGB(70, 70, 75)
			entry.key.Text = if learned then `[{entry.skill.Key}]` else "Locked"
		end
	end)

	-- Cooldown overlays
	task.spawn(function()
		while true do
			task.wait(0.05)
			local now = os.clock()
			for id, entry in buttons do
				local left = (readyAt[id] or 0) - now
				if left > 0 then
					entry.cover.Size = UDim2.fromScale(1, left / entry.skill.Cooldown)
					entry.timer.Text = string.format("%.1f", left)
				else
					entry.cover.Size = UDim2.fromScale(1, 0)
					entry.timer.Text = ""
				end
			end
		end
	end)
end

return SkillBarController
