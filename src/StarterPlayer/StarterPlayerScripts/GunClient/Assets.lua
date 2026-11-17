--[[
	Looks up user supplied assets in ReplicatedStorage.GunAssets (name configurable in Settings).
	Everything is optional: missing models/sounds/animations/effects are simply skipped.

	GunAssets
	├── Weapons
	│   └── <WeaponId>
	│       ├── Viewmodel   (Model)  first person arms + gun
	│       ├── Animations  (Folder of Animation objects)
	│       ├── Sounds      (Folder of Sound objects)
	│       └── Shell       (BasePart) ejected casing
	├── Effects
	│   └── Impacts
	│       ├── Default / Metal / Concrete / Wood / Flesh / Water ... (Folder: ParticleEmitters, Sounds, Decal "Hole")
	├── Tracers
	│   └── Default (BasePart, optional)
	└── Sounds (Crack, Whizz, Hitmarker, Kill)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunSystem = ReplicatedStorage:WaitForChild("GunSystem")
local Settings = require(GunSystem:WaitForChild("Settings"))

local Assets = {}

local root = ReplicatedStorage:FindFirstChild(Settings.AssetsFolderName)
if not root then
	task.spawn(function()
		root = ReplicatedStorage:WaitForChild(Settings.AssetsFolderName, 30)
		if not root then
			warn(`[GunSystem] No ReplicatedStorage.{Settings.AssetsFolderName} folder; running without models/sounds/effects.`)
		end
	end)
end

local function path(...)
	local current = root
	for _, name in { ... } do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end
Assets.Path = path

function Assets.WeaponFolder(weaponId: string)
	return path("Weapons", weaponId)
end

function Assets.Viewmodel(weaponId: string): Model?
	local model = path("Weapons", weaponId, "Viewmodel")
	return if model and model:IsA("Model") then model else nil
end

function Assets.WeaponSound(weaponId: string, name: string): Sound?
	local sound = path("Weapons", weaponId, "Sounds", name)
	return if sound and sound:IsA("Sound") then sound else nil
end

function Assets.Shell(weaponId: string): BasePart?
	local shell = path("Weapons", weaponId, "Shell")
	return if shell and shell:IsA("BasePart") then shell else nil
end

function Assets.Animation(weaponId: string, name: string): Animation?
	local animation = path("Weapons", weaponId, "Animations", name)
	return if animation and animation:IsA("Animation") then animation else nil
end

function Assets.Impact(effectName: string?)
	return (effectName and path("Effects", "Impacts", effectName)) or path("Effects", "Impacts", "Default")
end

function Assets.Tracer(): BasePart?
	local tracer = path("Tracers", "Default")
	return if tracer and tracer:IsA("BasePart") then tracer else nil
end

function Assets.GlobalSound(name: string): Sound?
	local sound = path("Sounds", name)
	return if sound and sound:IsA("Sound") then sound else nil
end

return Assets
