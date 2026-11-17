return {
	Id = "Glock17",
	DisplayName = "Glock 17",
	Ammo = "9x19",
	VelocityMultiplier = 1,

	Action = "Gas", -- (short recoil, self-loading)
	Feed = "Magazine",
	MagazineCapacity = 17,
	SpareMagazines = 3,
	BoltHoldOpen = true, -- slide locks back
	RetainMagazines = true,
	FireModes = { "Semi" }, -- no manual safety
	RPM = 600, -- practical trigger reset limit
	BurstCount = 1,

	Reliability = {
		FailureToFire = 0.0004,
		FailureToFeed = 0.0004,
		Stovepipe = 0.0008, -- limp-wristing
		DoubleFeed = 0.0001,
		HeatSensitivity = 2,
		FoulingSensitivity = 0.5,
	},
	Heat = { PerShot = 0.012, CoolRate = 0.1 },

	Times = {
		Equip = 0.35,
		Reload = 1.6,
		ReloadEmpty = 1.9,
		ClearMalfunction = 1.1,
		ClearDoubleFeed = 3.2,
		FireModeSwitch = 0,
		CheckAmmo = 1.2,
		AimIn = 0.18,
		SprintOut = 0.12,
	},

	Spread = {
		MOA = 5,
		Hip = 1.6,
		Aim = 0.1,
		Move = 1.4,
		Air = 4,
		BloomPerShot = 0.3,
		BloomMax = 2,
		BloomRecovery = 5,
		Heat = 0.2,
	},

	Recoil = {
		Vertical = 1.9,
		VerticalVariance = 0.3,
		Horizontal = 0.6,
		HorizontalBias = 0.1,
		FirstShot = 1,
		Recovery = 0.75, -- pistols snap back on target quickly
		AimMultiplier = 0.9,
		Camera = { Stiffness = 210, Damping = 20 },
		Viewmodel = { Kick = 0.12, Rise = 9, Roll = 3, Side = 0.03, Stiffness = 300, Damping = 22 },
		Shake = 0.05,
	},

	Handling = {
		AimFOV = 60,
		Sway = 1.2,
		WalkSpeedMultiplier = 1,
		AimWalkSpeedMultiplier = 0.75,
	},

	Viewmodel = {
		AimDistance = 0.6,
	},

	Animations = {},
}
