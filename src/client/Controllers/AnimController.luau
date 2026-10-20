--!strict
-- AnimController: plays the Blender-made animations (punches and skills) on characters.
--
-- Two ways, chosen per animation:
--   * Uploaded asset (Config.Assets.Animations[name] is set): the owning player's client plays
--     it on their own Animator, and Roblox replicates it to everyone.
--   * Not uploaded yet: we play the keyframes from AnimationData (exported from Blender)
--     ourselves, on every client, by layering each pose onto the character's joints every
--     frame after the normal walk/idle animation has run. Joints the animation doesn't use
--     (e.g. legs during a punch) keep walking normally.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationData = require(ReplicatedStorage.Shared.AnimationData)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local AnimController = {}

type Keyframe = { Time: number, Poses: { [string]: { number } } }
type Clip = { Length: number, Keyframes: { Keyframe } }

type JointState = { LastWritten: CFrame?, LastOffset: CFrame }
type Playback = { Clip: Clip, Start: number, Joints: { [string]: any } }

local clips: { [string]: Clip } = AnimationData.Animations :: any
local playing: { [Model]: Playback } = {}
local jointState: { [any]: JointState } = {}
local loadedTracks: { [Model]: { [string]: AnimationTrack } } = {}
local nextPunchIsRight: { [Model]: boolean } = {}

local function toCFrame(c: { number }): CFrame
	return CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
end

-- The joint that moves `part` (R15: a Motor6D or AnimationConstraint inside the part).
local function jointFor(character: Model, partName: string): any
	local part = character:FindFirstChild(partName)
	if not part then
		return nil
	end
	for _, child in part:GetChildren() do
		if child:IsA("Motor6D") or child:IsA("AnimationConstraint") then
			return child
		end
	end
	return nil
end

-- Pose of `partName` at time t, blending between the two nearest keyframes.
local function sample(clip: Clip, partName: string, t: number): CFrame
	local frames = clip.Keyframes
	local before, after = frames[1], frames[#frames]
	for i = 1, #frames - 1 do
		if frames[i + 1].Time >= t then
			before, after = frames[i], frames[i + 1]
			break
		end
	end
	local a = before.Poses[partName]
	local b = after.Poses[partName]
	if not a or not b then
		return CFrame.identity
	end
	local span = after.Time - before.Time
	local alpha = if span > 0 then math.clamp((t - before.Time) / span, 0, 1) else 1
	return toCFrame(a):Lerp(toCFrame(b), alpha)
end

-- Write `offset` on top of whatever the Animator set this frame.
local function layer(joint: any, offset: CFrame)
	local state = jointState[joint]
	if not state then
		state = { LastWritten = nil, LastOffset = CFrame.identity }
		jointState[joint] = state
	end
	local base: CFrame = joint.Transform
	if state.LastWritten and base == state.LastWritten then
		base = base * state.LastOffset:Inverse() -- nothing else touched it; undo our last frame
	end
	local written = base * offset
	joint.Transform = written
	state.LastWritten = written
	state.LastOffset = offset
end

local function step()
	local now = os.clock()
	for character, playback in playing do
		local t = now - playback.Start
		local done = t >= playback.Clip.Length or not character.Parent
		for partName, joint in playback.Joints do
			if joint.Parent then
				layer(joint, if done then CFrame.identity else sample(playback.Clip, partName, t))
			end
		end
		if done then
			playing[character] = nil
		end
	end
end

-- Play an uploaded animation on our own character (replicates to everyone).
local function playAsset(character: Model, name: string, id: string)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local tracks = loadedTracks[character]
	if not tracks then
		tracks = {}
		loadedTracks[character] = tracks
		character.Destroying:Connect(function()
			loadedTracks[character] = nil
		end)
	end
	local track = tracks[name]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action
		tracks[name] = track
	end
	track:Play(0.05)
end

function AnimController.Play(character: Model, name: string)
	local id = Config.Assets.Animations[name]
	if id and id ~= "" then
		-- Only the owner plays uploaded animations; Roblox shows them to everyone else.
		if character == Players.LocalPlayer.Character then
			playAsset(character, name, id)
		end
		return
	end

	local clip = clips[name]
	if not clip then
		return
	end
	local joints = {}
	for partName in clip.Keyframes[1].Poses do
		local joint = jointFor(character, partName)
		if joint then
			joints[partName] = joint
		end
	end
	-- Joints the previous animation used but this one doesn't: let them go back to normal.
	local previous = playing[character]
	if previous then
		for partName, joint in previous.Joints do
			if not joints[partName] then
				layer(joint, CFrame.identity)
			end
		end
	end
	playing[character] = { Clip = clip, Start = os.clock(), Joints = joints }
end

function AnimController.Init()
	-- PreSimulation runs after the Animator has posed characters for this frame.
	RunService.PreSimulation:Connect(step)

	Remotes.Get("PunchFx").OnClientEvent:Connect(function(player: Player)
		local character = player and player.Character
		if character then
			local right = nextPunchIsRight[character] ~= false
			nextPunchIsRight[character] = not right
			AnimController.Play(character, if right then "PunchRight" else "PunchLeft")
		end
	end)

	Remotes.Get("SkillFx").OnClientEvent:Connect(function(player: Player, id: string)
		local character = player and player.Character
		if character then
			AnimController.Play(character, id)
		end
	end)
end

return AnimController
