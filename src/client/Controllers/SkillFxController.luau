--!strict
-- SkillFxController: what skills look like, plus the dash movement for your own character.
--   Thunderstep Rush: you dash forward; a streak along the path and a slash at the end.
--   Earthshatter Stomp: a shockwave ring bursts out along the ground.
--   Heaven-Piercing Palm: a crescent wave of qi flies forward.
-- Uses the Blender meshes from ReplicatedStorage.VFXMeshes when uploaded, plain parts otherwise.
-- Purely visual: the server already decided what gets hit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local SkillFxController = {}

local QI_COLOR = Color3.fromRGB(110, 220, 255)
local skillById = {}
for _, skill in Config.Skills do
	skillById[skill.Id] = skill
end

-- A glowing effect part: the Blender mesh if we have it, otherwise a plain neon block/cylinder.
local function effectPart(meshName: string, fallbackShape: Enum.PartType): BasePart
	local folder = ReplicatedStorage:FindFirstChild("VFXMeshes")
	local template = folder and folder:FindFirstChild(meshName)
	local part: BasePart
	if template then
		part = (template :: BasePart):Clone()
	else
		part = Ui.New("Part", { Shape = fallbackShape })
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = QI_COLOR
	part.Parent = Workspace
	return part
end

local function fadeAndDestroy(part: BasePart, time: number, goal: { [string]: any })
	goal.Transparency = 1
	TweenService:Create(part, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	task.delay(time, function()
		part:Destroy()
	end)
end

-- Move our own character forward for the dash.
local function dash(character: Model, direction: Vector3, distance: number, time: number)
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart or distance <= 0 then
		return
	end
	local attachment = Ui.New("Attachment", { Parent = rootPart })
	local velocity = Ui.New("LinearVelocity", {
		Attachment0 = attachment,
		RelativeTo = Enum.ActuatorRelativeTo.World,
		MaxForce = math.huge,
		VectorVelocity = direction * (distance / time),
		Parent = rootPart,
	})
	task.delay(time, function()
		velocity:Destroy()
		attachment:Destroy()
		rootPart.AssemblyLinearVelocity = Vector3.zero
	end)
end

local function dashFx(info, skill)
	local start: Vector3, direction: Vector3, distance: number = info.Start, info.Direction, info.Distance or 0
	local finish = start + direction * distance
	-- Streak along the path
	local streak = effectPart("", Enum.PartType.Block)
	streak.Size = Vector3.new(0.6, 0.6, math.max(distance, 1))
	streak.CFrame = CFrame.lookAt((start + finish) / 2, finish)
	streak.Transparency = 0.2
	fadeAndDestroy(streak, 0.4, { Size = Vector3.new(0.1, 0.1, math.max(distance, 1)) })
	-- Slash at the end of the dash
	task.delay(skill.DashTime, function()
		local slash = effectPart("DashSlash", Enum.PartType.Block)
		local width = skill.Width * 1.4
		slash.Size = Vector3.new(width, 0.2, width * 0.45)
		slash.CFrame = CFrame.lookAt(finish, finish + direction) * CFrame.Angles(0, 0, math.rad(20))
		slash.Transparency = 0.1
		fadeAndDestroy(slash, 0.35, { Size = slash.Size * 1.5 })
	end)
end

local function shockwaveFx(info, skill)
	task.delay(skill.ImpactDelay, function()
		local start: Vector3 = info.Start
		local ground = start - Vector3.new(0, 2.8, 0)
		local ring = effectPart("ShockwaveRing", Enum.PartType.Cylinder)
		local isMesh = ring:IsA("MeshPart")
		local function ringSize(diameter: number): Vector3
			return if isMesh then Vector3.new(diameter, 0.6, diameter) else Vector3.new(0.4, diameter, diameter)
		end
		ring.Size = ringSize(2)
		-- A plain cylinder stands on its side, so tip it flat
		ring.CFrame = if isMesh then CFrame.new(ground) else CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))
		ring.Transparency = 0.15
		fadeAndDestroy(ring, 0.45, { Size = ringSize(skill.Radius * 2) })

		local character = Players.LocalPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart and (rootPart.Position - start).Magnitude < skill.Radius * 2.5 then
			Ui.ShakeCamera(1.2, 0.3)
		end
	end)
end

local function palmWaveFx(info, skill)
	task.delay(skill.ImpactDelay, function()
		local start: Vector3, direction: Vector3 = info.Start, info.Direction
		local wave = effectPart("PalmWave", Enum.PartType.Block)
		local isMesh = wave:IsA("MeshPart")
		wave.Size = if isMesh then Vector3.new(skill.Width, skill.Width * 0.8, 3) else Vector3.new(skill.Width, 5, 1)
		wave.Transparency = 0.15
		local from = CFrame.lookAt(start + direction * 2, start + direction * 3)
		wave.CFrame = from
		local travel = 0.35
		TweenService:Create(wave, TweenInfo.new(travel, Enum.EasingStyle.Linear), {
			CFrame = from + direction * skill.Range,
		}):Play()
		fadeAndDestroy(wave, travel + 0.1, {})
	end)
end

function SkillFxController.Init()
	Remotes.Get("SkillFx").OnClientEvent:Connect(function(player: Player, id: string, info)
		local skill = skillById[id]
		if not skill then
			return
		end
		if id == "DashStrike" then
			dashFx(info, skill)
			if player == Players.LocalPlayer and player.Character then
				dash(player.Character, info.Direction, info.Distance or 0, skill.DashTime)
			end
		elseif id == "Shockwave" then
			shockwaveFx(info, skill)
		elseif id == "PalmWave" then
			palmWaveFx(info, skill)
		end
	end)
end

return SkillFxController
