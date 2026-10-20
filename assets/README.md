# Assets (Blender → Roblox)

## Files
- `blender/plus1_animations.blend`: R15 rig (built from the real Roblox R15 joint positions),
  the 5 animations as Actions (PunchRight, PunchLeft, DashStrike, Shockwave, PalmWave), and the VFX meshes.
- `blender/export_animations.py`: exports every Action into `src/shared/AnimationData.luau`.
- `vfx/plus1_vfx.fbx`: the VFX meshes (ShockwaveRing, DashSlash, PalmWave).

## Editing an animation
1. Open `plus1_animations.blend`, select `R15Rig`, pick the Action in the Action Editor, pose and key bones.
   Bones have plain axes: rotating a limb bone around X swings it forward/back.
2. Scripting tab → open `export_animations.py` → Run Script. Rojo syncs it into Studio.
3. Until an animation is published, the game plays this data directly. If it's already published,
   re-publish it (below) to update the uploaded version.

## Publishing animations (one time each)
The rig `Workspace.AnimRig` has all 5 animations saved inside it (`AnimSaves`).
1. Select `AnimRig` → Avatar tab → **Animation Editor**.
2. `...` menu → **Load** → pick an animation.
3. `...` menu → **Publish to Roblox** → Submit → copy the asset ID.
4. Put it in `Config.Assets.Animations` in `src/shared/Config.luau` as `"rbxassetid://<id>"`.
Delete `AnimRig` once all are published (it's only for publishing).

## Importing VFX meshes (one time)
1. Studio: **Import 3D** → choose `assets/vfx/plus1_vfx.fbx` → Import.
2. Each imported MeshPart has a `MeshId`. Put them in `Config.Assets.Meshes`.
3. You can delete the imported model afterwards; the game loads meshes from the IDs.
