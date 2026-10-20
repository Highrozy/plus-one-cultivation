--!strict
-- PunchAnimController: plays a quick punch (arm thrust forward) on any character
-- the server says just punched. Arms alternate left/right.
-- Needs no animation assets: every frame, after the normal walk/idle animation
-- has posed the character, we add a forward swing to the shoulder joint.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PunchAnimController = {}

local THRUST_TIME = 0.07 -- arm goes out
local RETURN_TIME = 0.14 -- arm comes back

type Swing = {
	Joint: any, -- Motor6D or AnimationConstraint (both have .Transform)
	Rotation: CFrame,
	Start: number,
	LastWritten: CFrame?, -- what we last set Transform to
	LastOffset: CFrame,
}

local active: { [any]: Swing } = {}
local nextArmIsRight: { [Model]: boolean } = {}

-- Classic rigs use Motor6D; the newer avatar joints use AnimationConstraint.
local function isJoint(instance: Instance): boolean
	return instance:IsA("Motor6D") or instance:IsA("AnimationConstraint")
end

-- Returns the shoulder joint plus the rotation that swings that arm straight forward.
local function shoulder(character: Model, right: boolean): (any, CFrame)
	-- R15
	local upperArm = character:FindFirstChild(if right then "RightUpperArm" else "LeftUpperArm")
	local joint = upperArm and upperArm:FindFirstChild(if right then "RightShoulder" else "LeftShoulder")
	if joint and isJoint(joint) then
		return joint, CFrame.Angles(math.rad(90), 0, 0)
	end
	-- R6
	local torso = character:FindFirstChild("Torso")
	joint = torso and torso:FindFirstChild(if right then "Right Shoulder" else "Left Shoulder")
	if joint and isJoint(joint) then
		return joint, CFrame.Angles(0, 0, math.rad(if right then 90 else -90))
	end
	return nil, CFrame.identity
end

local function punch(character: Model)
	local right = nextArmIsRight[character] ~= false
	nextArmIsRight[character] = not right

	local joint, rotation = shoulder(character, right)
	if not joint then
		return
	end
	local existing = active[joint]
	active[joint] = {
		Joint = joint,
		Rotation = rotation,
		Start = os.clock(),
		LastWritten = existing and existing.LastWritten,
		LastOffset = if existing then existing.LastOffset else CFrame.identity,
	}
end

-- How far out the arm is (0 = resting, 1 = fully punched) at time t.
local function swingAmount(t: number): number
	if t < THRUST_TIME then
		return t / THRUST_TIME
	end
	return math.max(0, 1 - (t - THRUST_TIME) / RETURN_TIME)
end

local function step()
	local now = os.clock()
	for joint, swing in active do
		if not joint.Parent then
			active[joint] = nil
			continue
		end
		-- If no animation rewrote the joint since our last frame, remove our old offset first.
		local base = joint.Transform
		if swing.LastWritten and base == swing.LastWritten then
			base = base * swing.LastOffset:Inverse()
		end

		local t = now - swing.Start
		local offset = CFrame.new():Lerp(swing.Rotation, swingAmount(t))
		local written = base * offset
		joint.Transform = written
		swing.LastWritten = written
		swing.LastOffset = offset

		if t > THRUST_TIME + RETURN_TIME then
			joint.Transform = base
			active[joint] = nil
		end
	end
end

function PunchAnimController.Init()
	-- PreSimulation runs after the Animator has posed characters for this frame.
	RunService.PreSimulation:Connect(step)

	Remotes.Get("PunchFx").OnClientEvent:Connect(function(player: Player)
		local character = player and player.Character
		if character then
			punch(character)
		end
	end)
end

return PunchAnimController
