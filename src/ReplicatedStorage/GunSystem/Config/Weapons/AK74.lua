--[[
	Weapon config reference (all fields shown here; omitted fields fall back to Defaults.lua).
	Times are in seconds, angles in degrees.
]]
return {
	Id = "AK74",
	DisplayName = "AK-74",
	Ammo = "5.45x39",
	VelocityMultiplier = 1, -- barrel length effect on MuzzleVelocity

	-- Operation
	Action = "Gas", -- "Gas" (self-loading), "Pump", "Bolt"
	Feed = "Magazine", -- "Magazine" or "Tube"
	MagazineCapacity = 30,
	SpareMagazines = 5,
	BoltHoldOpen = false, -- AKs do not lock back on empty
	RetainMagazines = true, -- partially used mags go back in the pouch on a tactical reload
	FireModes = { "Safe", "Auto", "Semi" }, -- selector order (AK: safe -> auto -> semi)
	RPM = 650,
	BurstCount = 3,

	-- Reliability: chance per round at a clean, cool weapon (before Settings.MalfunctionMultiplier)
	Reliability = {
		FailureToFire = 0.0006, -- dud / light strike
		FailureToFeed = 0.0005,
		Stovepipe = 0.0004, -- failure to eject
		DoubleFeed = 0.0002,
		HeatSensitivity = 3, -- chance * (1 + HeatSensitivity * heat^2)
		FoulingSensitivity = 0.6, -- chance * (1 + FoulingSensitivity * roundsFired / 1000)
	},
	Heat = {
		PerShot = 0.01, -- heat 0 (cold) .. 1 (barrel glowing)
		CoolRate = 0.06, -- fraction lost per second (exponential)
	},

	Times = {
		Equip = 0.6,
		Reload = 2.4, -- tactical (round chambered)
		ReloadEmpty = 3.1, -- includes racking the charging handle
		ClearMalfunction = 1.5, -- tap-rack
		ClearDoubleFeed = 4.2, -- strip mag, rack x3, reinsert, rack
		Cycle = 0, -- manual action time (Pump / Bolt)
		ShellInsert = 0, -- per shell for tube-fed
		FireModeSwitch = 0.25,
		CheckAmmo = 1.6,
		AimIn = 0.28,
		SprintOut = 0.2,
	},

	Spread = {
		MOA = 4, -- mechanical accuracy (rifle + ammo), always applied
		Hip = 2.6, -- extra degrees when firing from the hip
		Aim = 0, -- extra degrees when aiming down sights
		Move = 2.2, -- extra degrees at full walk speed
		Air = 6, -- extra degrees when airborne
		BloomPerShot = 0.18, -- sustained fire bloom (hip only, ADS uses recoil)
		BloomMax = 2,
		BloomRecovery = 4, -- degrees per second
		Heat = 0.4, -- extra degrees at max heat (barrel walk / mirage)
		PelletSpread = 0,
	},

	Recoil = {
		Vertical = 1.25, -- camera degrees per shot
		VerticalVariance = 0.2,
		Horizontal = 0.55, -- max side kick
		HorizontalBias = 0.15, -- -1 left .. 1 right
		FirstShot = 1.15,
		Recovery = 0.45, -- fraction of the kick the camera returns on its own
		AimMultiplier = 0.85,
		Camera = { Stiffness = 160, Damping = 17 },
		Viewmodel = { Kick = 0.18, Rise = 3.5, Roll = 2.5, Side = 0.04, Stiffness = 260, Damping = 22 },
		Shake = 0.08,
	},

	Handling = {
		AimFOV = 55,
		Sway = 1,
		WalkSpeedMultiplier = 0.95,
		AimWalkSpeedMultiplier = 0.65,
	},

	Viewmodel = {
		HipOffset = CFrame.new(0, 0, 0), -- extra offset applied to your viewmodel at the hip
		AimDistance = 0.25, -- how far in front of the camera the AimPoint sits when aiming
		SprintOffset = CFrame.new(0.2, -0.25, 0) * CFrame.Angles(-0.35, 0.8, 0.15),
	},

	-- Optional: animation ids. Animation objects inside GunAssets/Weapons/AK74/Animations also work
	-- and take priority. See README for the full list of names.
	Animations = {},
}
