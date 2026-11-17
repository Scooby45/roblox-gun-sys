--[[
	Global settings for the gun system.

	Units: weapon/ammo configs are written in real-world units (m/s, mm, m/s^2) and
	converted to studs internally using StudsPerMeter.
]]

local Settings = {}

----------------------------------------------------------------------------------------------------
-- World / units
----------------------------------------------------------------------------------------------------

-- 1 stud = 0.28 m (Roblox's commonly used character scale).
Settings.StudsPerMeter = 1 / 0.28
Settings.MillimetersPerStud = 1000 / Settings.StudsPerMeter

-- true  -> bullets fall at real 9.81 m/s^2 (converted to studs)
-- false -> bullets use workspace.Gravity (196.2 by default, which is ~5.5x stronger than real)
Settings.UseRealisticGravity = true

----------------------------------------------------------------------------------------------------
-- Ballistics
----------------------------------------------------------------------------------------------------

Settings.Ballistics = {
	MaxRange = 2500, -- studs, hard cap for any projectile
	MinSpeed = 90, -- m/s, a projectile slower than this is considered spent
	MaxPenetrationDepth = 10, -- studs, the deepest we will ever probe for an exit point
	MaxRicochets = 2,
	MaxSegments = 12, -- max continuation casts per pellet (penetrations + ricochets + pass-throughs)
	HighFidelity = false, -- FastCast HighFidelityBehavior (Default is fine for almost all games)
}

----------------------------------------------------------------------------------------------------
-- Malfunctions
----------------------------------------------------------------------------------------------------

-- Global multiplier for every malfunction chance. Real-world rates are tiny (roughly 1 in
-- several thousand rounds for a clean rifle); the configs are already scaled up a bit for gameplay.
-- 0 disables malfunctions entirely.
Settings.MalfunctionMultiplier = 1

----------------------------------------------------------------------------------------------------
-- Damage
----------------------------------------------------------------------------------------------------

Settings.Damage = {
	FriendlyFire = false,
	-- Multipliers per body part. Anything not listed uses Default.
	HitZones = {
		Default = 1,
		Head = 3.5,
		UpperTorso = 1.1,
		Torso = 1.05,
		HumanoidRootPart = 1,
		LowerTorso = 0.95,
		LeftUpperArm = 0.6,
		RightUpperArm = 0.6,
		LeftLowerArm = 0.5,
		RightLowerArm = 0.5,
		LeftHand = 0.4,
		RightHand = 0.4,
		["Left Arm"] = 0.55,
		["Right Arm"] = 0.55,
		LeftUpperLeg = 0.7,
		RightUpperLeg = 0.7,
		LeftLowerLeg = 0.55,
		RightLowerLeg = 0.55,
		LeftFoot = 0.45,
		RightFoot = 0.45,
		["Left Leg"] = 0.6,
		["Right Leg"] = 0.6,
	},
	-- Character attributes read for armor: "BodyArmor" (0-1) protects torso parts,
	-- "Helmet" (0-1) protects the head. Ammo ArmorPenetration (0-1) reduces their effect.
	TorsoParts = { UpperTorso = true, LowerTorso = true, Torso = true, HumanoidRootPart = true },
}

----------------------------------------------------------------------------------------------------
-- Security / anti-exploit (server)
----------------------------------------------------------------------------------------------------

Settings.Security = {
	MaxOriginDistance = 9, -- studs between head and the reported muzzle position (plus movement)
	FireRateTolerance = 1.12, -- token bucket refill multiplier to absorb network jitter
	FireBucketSize = 3, -- shots that may arrive bunched together
	ShotLifetime = 6, -- seconds a fired shot may still report hits
	MaxShotsTracked = 96, -- per player
	MaxRewind = 1.0, -- seconds of lag compensation history
	HitTolerance = 3.5, -- studs of slack when checking a hit against a rewound hitbox
	DirectionTolerance = 1.5, -- degrees of slack for the first leg of a bullet path
	PenetrationTolerance = 1.2, -- server allows 20% more penetration than computed (geometry differences)
	ActionTimeTolerance = 0.8, -- a reload/clear must take at least 80% of its configured time
}

----------------------------------------------------------------------------------------------------
-- Replication (cosmetic)
----------------------------------------------------------------------------------------------------

Settings.Replication = {
	MaxDistance = 3000, -- studs, shots further than this from a player are not replicated to them
	LookRate = 12, -- Hz, upper body aim pitch updates
}

----------------------------------------------------------------------------------------------------
-- Client effects / performance
----------------------------------------------------------------------------------------------------

Settings.Effects = {
	TracerPoolSize = 48,
	TracerLength = 6, -- studs at full speed (scaled with speed)
	TracerWidth = 0.08,
	MaxBulletHoles = 150,
	BulletHoleLifetime = 25,
	BulletHoleSize = 0.35,
	MaxShells = 30,
	ShellLifetime = 2.5,
	ShellMaxDistance = 70, -- studs from camera to spawn shell casings
	ImpactMaxDistance = 450, -- studs from camera to spawn impact effects
	WhizzRadius = 9, -- studs, supersonic crack / whizz when a bullet passes this close
	MuzzleLightTime = 0.045,
	SoundPoolPerWeapon = 6,
}

----------------------------------------------------------------------------------------------------
-- Camera
----------------------------------------------------------------------------------------------------

Settings.Camera = {
	FieldOfView = 70,
	FirstPersonThreshold = 1.5, -- studs between camera and head to count as first person
	ShoulderOffset = Vector3.new(1.75, 0.4, 0), -- Humanoid.CameraOffset while holding a gun in 3rd person
	ShoulderSwitchKey = Enum.KeyCode.Q, -- swap shoulder side (nil to disable)
	LockMouseInThirdPerson = true, -- behave like shift-lock while a gun is equipped
	-- "Zoom"       -> aiming in third person just zooms the FOV over the shoulder
	-- "FirstPerson" -> aiming in third person snaps into first person (tactical shooter style)
	ThirdPersonAimMode = "Zoom",
	ThirdPersonAimFOVMultiplier = 0.8,
}

----------------------------------------------------------------------------------------------------
-- Movement
----------------------------------------------------------------------------------------------------

Settings.Movement = {
	SprintEnabled = true,
	SprintSpeedMultiplier = 1.45,
	SprintToFireDelay = 0.18, -- seconds after sprint ends before the gun can fire (raising it)
}

----------------------------------------------------------------------------------------------------
-- HUD
----------------------------------------------------------------------------------------------------

Settings.HUD = {
	Enabled = true,
	ShowExactAmmo = false, -- realistic: only an estimate after checking the mag (T)
	ShowMalfunctionType = true, -- false: just show "Weapon won't fire"
	Crosshair = true, -- hip-fire dot in third person only
	Hitmarker = true,
}

----------------------------------------------------------------------------------------------------
-- Input
----------------------------------------------------------------------------------------------------

Settings.Keybinds = {
	Fire = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 },
	Aim = { Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2 },
	Reload = { Enum.KeyCode.R, Enum.KeyCode.ButtonX },
	ClearMalfunction = { Enum.KeyCode.F, Enum.KeyCode.ButtonY },
	FireMode = { Enum.KeyCode.V, Enum.KeyCode.DPadUp },
	CheckAmmo = { Enum.KeyCode.T, Enum.KeyCode.DPadDown },
	Sprint = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 },
}

----------------------------------------------------------------------------------------------------
-- Locations
----------------------------------------------------------------------------------------------------

-- Name of the folder in ReplicatedStorage that holds your models, sounds, animations and effects.
Settings.AssetsFolderName = "GunAssets"
-- Name of the folder in ReplicatedStorage the remotes are created in.
Settings.RemotesFolderName = "GunSystemRemotes"

return Settings
