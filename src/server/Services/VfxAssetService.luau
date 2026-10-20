--!strict
-- VfxAssetService: turns the uploaded Blender VFX meshes (Config.Assets.Meshes) into MeshPart
-- templates in ReplicatedStorage.VFXMeshes, so clients can clone them for skill effects.
-- Any mesh that isn't uploaded yet is simply skipped; the client then uses plain parts.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local VfxAssetService = {}

function VfxAssetService.Init()
	local folder = Instance.new("Folder")
	folder.Name = "VFXMeshes"
	folder.Parent = ReplicatedStorage

	for name, meshId in Config.Assets.Meshes do
		if meshId ~= "" then
			task.spawn(function()
				local ok, result = pcall(function()
					return AssetService:CreateMeshPartAsync(meshId)
				end)
				if ok then
					local part = result :: MeshPart
					part.Name = name
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.Material = Enum.Material.Neon
					part.Parent = folder
				else
					warn(`[VfxAssetService] Could not load mesh {name} ({meshId}): {result}`)
				end
			end)
		end
	end
end

return VfxAssetService
