--!strict
-- Remotes: every RemoteEvent in one list. The server creates them; the client waits for them.
--
-- Client -> server (intents only, the server validates everything):
--   Click, BuyTechnique(id), Breakthrough, Rebirth
-- Server -> client (effects and messages):
--   PunchFx(player), FloatText(position, text, kind), LootFx(position, stones, cores), Notify(text)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Click",
	"BuyTechnique",
	"Breakthrough",
	"Rebirth",
	"PunchFx",
	"FloatText",
	"LootFx",
	"Notify",
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
