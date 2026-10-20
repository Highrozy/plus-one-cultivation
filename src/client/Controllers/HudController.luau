--!strict
-- HudController: the always-on screen UI.
--   Top: realm + stage, qi bar toward the next stage, qi per tap / damage.
--   Left: spirit crystals, beast cores, rebirths.
--   Bottom: training status, Breakthrough button (QC9), Rebirth button (final stage).
--   Popups: stage-up, breakthrough, rebirth, and server messages.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local HudController = {}

local STAGE_QI = Config.Realms.StageQi
local MAJOR = Config.Realms.MajorBreakthroughStage
local MAX_STAGE = #STAGE_QI

local screen: ScreenGui

local function playSound(id: string, volume: number)
	local sound = Ui.New("Sound", { SoundId = id, Volume = volume, Parent = SoundService })
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

--------------------------------------------------------------------------
-- Popups
--------------------------------------------------------------------------
local function popup(text: string, color: Color3, big: boolean)
	local label = Ui.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.new(0.9, 0, 0, if big then 90 else 60),
		Text = text,
		TextColor3 = color,
		TextStrokeTransparency = 0,
		ZIndex = 10,
		Parent = screen,
	})
	Ui.New("UISizeConstraint", { MaxSize = Vector2.new(800, math.huge), Parent = label })

	-- Screen flash
	local flash = Ui.New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = if big then 0.3 else 0.7,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = screen,
	})
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()

	task.delay(1.4, function()
		local fade = TweenInfo.new(0.5)
		TweenService:Create(label, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.5)
		label:Destroy()
		flash:Destroy()
	end)
end

local function toast(text: string)
	local label = Ui.Label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140),
		Size = UDim2.new(0.8, 0, 0, 36),
		BackgroundTransparency = 0.3,
		BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		Text = text,
		ZIndex = 8,
		Parent = screen,
	})
	Ui.Corner(8).Parent = label
	Ui.New("UISizeConstraint", { MaxSize = Vector2.new(500, math.huge), Parent = label })
	task.delay(2, function()
		label:Destroy()
	end)
end

--------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------
function HudController.Init()
	screen = Ui.Screen("Hud")

	-- Top center: realm, qi bar, stats
	local top = Ui.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(0.6, 0, 0, 100),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Ui.New("UISizeConstraint", { MinSize = Vector2.new(300, 0), MaxSize = Vector2.new(480, math.huge), Parent = top })

	local realmLabel = Ui.Label({ Size = UDim2.new(1, 0, 0, 34), TextColor3 = Color3.fromRGB(255, 225, 120), Parent = top })

	local barBack = Ui.New("Frame", {
		Position = UDim2.new(0, 0, 0, 38),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BorderSizePixel = 0,
		Parent = top,
	})
	Ui.Corner(8).Parent = barBack
	local barFill = Ui.New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(80, 190, 255),
		BorderSizePixel = 0,
		Parent = barBack,
	})
	Ui.Corner(8).Parent = barFill
	local barText = Ui.Label({ Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = barBack })

	local statsLabel = Ui.Label({
		Position = UDim2.new(0, 0, 0, 72),
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = Color3.fromRGB(210, 210, 220),
		Parent = top,
	})

	-- "+12 Qi" next to the bar whenever qi goes up
	local gainLabel = Ui.Label({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 8, 0, 53),
		Size = UDim2.fromOffset(110, 26),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(120, 220, 255),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = top,
	})

	-- Left: currencies
	local left = Ui.New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(230, 132),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Ui.New("UIListLayout", { Padding = UDim.new(0, 6), Parent = left })
	local function currencyRow(color: Color3): TextLabel
		local row = Ui.Label({
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 0.25,
			BackgroundColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = left,
		})
		Ui.Corner(8).Parent = row
		Ui.New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = row })
		return row
	end
	local stonesLabel = currencyRow(Color3.fromRGB(30, 110, 160))
	local coresLabel = currencyRow(Color3.fromRGB(150, 40, 40))
	local rebirthsLabel = currencyRow(Color3.fromRGB(100, 60, 150))

	-- Bottom center: training status + big action buttons
	local trainingLabel = Ui.Label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.new(0.7, 0, 0, 30),
		TextColor3 = Color3.fromRGB(150, 255, 150),
		Parent = screen,
	})

	local breakthroughButton = Ui.Button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(320, 80),
		BackgroundColor3 = Color3.fromRGB(240, 180, 40),
		Visible = false,
		Parent = screen,
	})
	local glow = Ui.New("UIStroke", { Thickness = 4, Color = Color3.fromRGB(255, 255, 180), Parent = breakthroughButton })

	local rebirthButton = Ui.Button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(320, 80),
		BackgroundColor3 = Color3.fromRGB(150, 70, 220),
		Visible = false,
		Parent = screen,
	})

	-- Pulse the breakthrough glow
	task.spawn(function()
		while true do
			TweenService:Create(glow, TweenInfo.new(0.6), { Thickness = 10, Transparency = 0.5 }):Play()
			task.wait(0.6)
			TweenService:Create(glow, TweenInfo.new(0.6), { Thickness = 3, Transparency = 0 }):Play()
			task.wait(0.6)
		end
	end)

	breakthroughButton.Activated:Connect(function()
		Remotes.Get("Breakthrough"):FireServer()
	end)

	-- Rebirth needs a second tap to confirm, so it can't happen by accident.
	local confirmUntil = 0
	local refresh: () -> ()
	rebirthButton.Activated:Connect(function()
		if os.clock() < confirmUntil then
			confirmUntil = 0
			Remotes.Get("Rebirth"):FireServer()
		else
			confirmUntil = os.clock() + 3
			refresh()
			task.delay(3, refresh)
		end
	end)

	--------------------------------------------------------------------------
	-- Update everything from the player's attributes
	--------------------------------------------------------------------------
	local lastQi = 0
	local lastStage = 1
	local lastRebirths = 0

	refresh = function()
		local state = Ui.State()
		local stage = state.Stage

		realmLabel.Text = Formulas.StageName(stage)

		-- Progress bar toward the next stage
		if stage >= MAX_STAGE then
			barFill.Size = UDim2.fromScale(1, 1)
			barText.Text = `{Config.Names.Qi}: {Format.Number(math.floor(state.Qi))}  (peak!)`
		else
			local from, to = STAGE_QI[stage], STAGE_QI[stage + 1]
			local progress = math.clamp((state.Qi - from) / (to - from), 0, 1)
			barFill.Size = UDim2.fromScale(progress, 1)
			barText.Text = `{Config.Names.Qi}: {Format.Number(math.floor(state.Qi))} / {Format.Number(to)}`
		end

		statsLabel.Text = `+{Format.Number(Formulas.QiPerClick(state))} qi per tap  ·  Damage {Format.Number(
			math.floor(Formulas.PunchDamage(state))
		)}`

		stonesLabel.Text = `{Config.Names.Stones}: {Format.Number(state.Stones)}`
		coresLabel.Text = `{Config.Names.Cores}: {Format.Number(state.Cores)}`
		rebirthsLabel.Text = `Rebirths: {state.Rebirths}  (x{Formulas.RebirthMultiplier(state.Rebirths)} qi)`

		if state.TrainingPlatform > 0 then
			local platform = Config.Training.Platforms[state.TrainingPlatform]
			trainingLabel.Text = `Training on {platform.Name} (x{platform.QiMultiplier})`
			trainingLabel.Visible = true
		else
			trainingLabel.Visible = false
		end

		-- Breakthrough button: shows at QC9, glows once you have enough qi
		breakthroughButton.Visible = stage == MAJOR - 1
		if breakthroughButton.Visible then
			local ready = state.Qi >= STAGE_QI[MAJOR]
			breakthroughButton.Text = if ready
				then "BREAKTHROUGH!"
				else `Breakthrough: {Format.Number(math.floor(state.Qi))} / {Format.Number(STAGE_QI[MAJOR])} qi`
			breakthroughButton.BackgroundColor3 = if ready then Color3.fromRGB(240, 180, 40) else Color3.fromRGB(110, 100, 80)
			glow.Enabled = ready
		end

		-- Rebirth button: shows at the final stage
		rebirthButton.Visible = stage >= MAX_STAGE
		if rebirthButton.Visible then
			local now = Formulas.RebirthMultiplier(state.Rebirths)
			local after = Formulas.RebirthMultiplier(state.Rebirths + 1)
			rebirthButton.Text = if os.clock() < confirmUntil
				then "Tap again to REBIRTH (resets everything!)"
				else `REBIRTH  (x{now} → x{after} qi)`
		end

		-- Popups for big moments
		if state.Rebirths > lastRebirths then
			popup(`REBORN! Rebirth {state.Rebirths}`, Color3.fromRGB(200, 140, 255), true)
			playSound("rbxasset://sounds/electronicpingshort.wav", 1)
		elseif stage > lastStage then
			if stage == MAJOR then
				popup(`BREAKTHROUGH!\n{Formulas.StageName(stage)}`, Color3.fromRGB(255, 220, 80), true)
			else
				popup(`{Formulas.StageName(stage)}!`, Color3.fromRGB(150, 230, 255), false)
			end
			playSound("rbxasset://sounds/electronicpingshort.wav", 0.6)
		end

		-- Floating "+qi" by the bar
		if state.Qi > lastQi and stage == lastStage then
			gainLabel.Text = `+{Format.Number(state.Qi - lastQi)}`
			gainLabel.TextTransparency = 0
			gainLabel.TextStrokeTransparency = 0.3
			TweenService:Create(gainLabel, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end

		lastQi, lastStage, lastRebirths = state.Qi, stage, state.Rebirths
	end

	Ui.OnStateChanged(refresh)
	Remotes.Get("Notify").OnClientEvent:Connect(toast)
end

return HudController
