--!strict
-- SkillService: active skill moves (Thunderstep Rush, Earthshatter Stomp, Heaven-Piercing Palm).
-- The client only asks "use skill X". The server checks it's learned and off cooldown,
-- works out what gets hit from the character's real position and facing, deals the damage,
-- and tells every client to play the animation + VFX (the owner also does the dash movement).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local BeastService = require(script.Parent.BeastService)
local CombatService = require(script.Parent.CombatService)

local SkillService = {}

local readyAt: { [Player]: { [string]: number } } = {}

-- Flat direction the character is facing.
local function facing(rootPart: BasePart): Vector3
	local look = rootPart.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
end

-- How far the character can travel before hitting a wall (beasts don't block).
local function clearDistance(character: Model, from: Vector3, direction: Vector3, maxDistance: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { character }
	local beastFolder = Workspace:FindFirstChild("Beasts")
	if beastFolder then
		table.insert(exclude, beastFolder)
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(from, direction * maxDistance, params)
	return if hit then math.max(hit.Distance - 2, 0) else maxDistance
end

local function hitAll(player: Player, targets: { BeastService.Beast }, damage: number)
	for _, beast in targets do
		CombatService.Hit(player, beast, damage, "Skill")
	end
end

function SkillService.Init()
	local skillFx = Remotes.Get("SkillFx")

	local skillById = {}
	for _, skill in Config.Skills do
		skillById[skill.Id] = skill
	end

	Remotes.Get("UseSkill").OnServerEvent:Connect(function(player, id)
		local skill = typeof(id) == "string" and skillById[id]
		local data = PlayerData.Get(player)
		if not skill or not data or (data.Techniques[id] or 0) < 1 then
			return
		end

		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not rootPart or not humanoid or humanoid.Health <= 0 then
			return
		end

		local now = os.clock()
		local timers = readyAt[player] or {}
		readyAt[player] = timers
		if now < (timers[id] or 0) then
			return -- still on cooldown
		end
		timers[id] = now + skill.Cooldown

		local start = rootPart.Position
		local direction = facing(rootPart)
		local damage = Formulas.SkillDamage(data, id)
		local info: { [string]: any } = { Start = start, Direction = direction }

		if id == "DashStrike" then
			local distance = clearDistance(character, start, direction, skill.Distance)
			info.Distance = distance
			local finish = start + direction * distance
			task.delay(skill.ImpactDelay, function()
				hitAll(player, BeastService.InPath(start, finish, skill.Width / 2), damage)
			end)
		elseif id == "Shockwave" then
			task.delay(skill.ImpactDelay, function()
				hitAll(player, BeastService.InRadius(start, skill.Radius), damage)
			end)
		elseif id == "PalmWave" then
			local finish = start + direction * skill.Range
			task.delay(skill.ImpactDelay, function()
				hitAll(player, BeastService.InPath(start, finish, skill.Width / 2), damage)
			end)
		end

		skillFx:FireAllClients(player, id, info)
	end)

	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return SkillService
