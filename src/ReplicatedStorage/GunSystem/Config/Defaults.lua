--[[
	Default values merged (deeply) into every weapon config. Anything a weapon omits comes from here.
]]
return {
	DisplayName = "Weapon",
	Ammo = "5.56x45",
	VelocityMultiplier = 1,

	Action = "Gas",
	Feed = "Magazine",
	MagazineCapacity = 30,
	SpareMagazines = 4,
	SpareRounds = 0,
	BoltHoldOpen = false,
	RetainMagazines = true,
	FireModes = { "Semi" },
	RPM = 600,
	BurstCount = 3,

	Reliability = {
		FailureToFire = 0.0005,
		FailureToFeed = 0.0005,
		Stovepipe = 0.0005,
		DoubleFeed = 0.0002,
		HeatSensitivity = 2,
		FoulingSensitivity = 0.5,
	},
	Heat = { PerShot = 0.01, CoolRate = 0.06 },

	Times = {
		Equip = 0.5,
		Reload = 2,
		ReloadEmpty = 2.5,
		ClearMalfunction = 1.4,
		ClearDoubleFeed = 3.5,
		Cycle = 0.6,
		ShellInsert = 0.5,
		ReloadStart = 0.3,
		ReloadEnd = 0.3,
		FireModeSwitch = 0.2,
		CheckAmmo = 1.5,
		AimIn = 0.25,
		SprintOut = 0.2,
	},

	Spread = {
		MOA = 3,
		Hip = 2.5,
		Aim = 0,
		Move = 2,
		Air = 6,
		BloomPerShot = 0.15,
		BloomMax = 2,
		BloomRecovery = 4,
		Heat = 0.3,
		PelletSpread = 0,
	},

	Recoil = {
		Vertical = 1,
		VerticalVariance = 0.2,
		Horizontal = 0.4,
		HorizontalBias = 0,
		FirstShot = 1,
		Recovery = 0.5,
		AimMultiplier = 0.85,
		Camera = { Stiffness = 160, Damping = 17 },
		Viewmodel = { Kick = 0.15, Rise = 3, Roll = 2, Side = 0.03, Stiffness = 260, Damping = 22 },
		Shake = 0.05,
	},

	Handling = {
		AimFOV = 55,
		Sway = 1,
		WalkSpeedMultiplier = 1,
		AimWalkSpeedMultiplier = 0.65,
	},

	Viewmodel = {
		HipOffset = CFrame.new(),
		AimDistance = 0.25,
		SprintOffset = CFrame.new(0.2, -0.25, 0) * CFrame.Angles(-0.35, 0.8, 0.15),
	},

	Animations = {},
}
