--!strict
-- Remotes: every RemoteEvent in one list. The server creates them; the client waits for them.
--
-- Client -> server (intents only, the server validates everything):
--   Click, DevCommand(name, arg?) [Studio only], Shop(action, id), Rebirth,
--   Furnace("Refine", { Cores = { CoreStack }, Stones = n } | "Finish", won),
--   Seclusion("Enter" | "Leave" | "Consume", { Tier = n, Failed = bool } | "Unqueue", index | "All")
-- Server -> client:
--   Notify(message), TrainingQi(amount), BrewStart(tier),
--   Seclusion("Entered" | "Left" | "Qi", amount | "Absorb", tier, failed, seconds | "AbsorbEnd"
--     | "Queue", { { Tier = n, Failed = bool } })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Click",
	"DevCommand",
	"Shop",
	"Rebirth",
	"Notify",
	"TrainingQi",
	"Furnace",
	"BrewStart",
	"Seclusion",
}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local Remotes = {}

function Remotes.Get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
