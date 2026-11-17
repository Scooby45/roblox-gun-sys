return {
	Id = "M4A1",
	DisplayName = "M4A1",
	Ammo = "5.56x45",
	VelocityMultiplier = 0.96, -- 14.5" barrel

	Action = "Gas",
	Feed = "Magazine",
	MagazineCapacity = 30,
	SpareMagazines = 5,
	BoltHoldOpen = true, -- bolt catch: empty reload is just a bolt release
	RetainMagazines = true,
	FireModes = { "Safe", "Semi", "Auto" },
	RPM = 800,
	BurstCount = 3,

	Reliability = {
		FailureToFire = 0.0005,
		FailureToFeed = 0.0007,
		Stovepipe = 0.0006,
		DoubleFeed = 0.0003,
		HeatSensitivity = 3.5,
		FoulingSensitivity = 1.2, -- direct impingement fouls faster
	},
	Heat = { PerShot = 0.011, CoolRate = 0.06 },

	Times = {
		Equip = 0.55,
		Reload = 2.1,
		ReloadEmpty = 2.5,
		ClearMalfunction = 1.4,
		ClearDoubleFeed = 4,
		FireModeSwitch = 0.2,
		CheckAmmo = 1.5,
		AimIn = 0.25,
		SprintOut = 0.18,
	},

	Spread = {
		MOA = 2.5,
		Hip = 2.4,
		Aim = 0,
		Move = 2,
		Air = 6,
		BloomPerShot = 0.15,
		BloomMax = 1.8,
		BloomRecovery = 4,
		Heat = 0.35,
	},

	Recoil = {
		Vertical = 0.95,
		VerticalVariance = 0.15,
		Horizontal = 0.4,
		HorizontalBias = 0.05,
		FirstShot = 1.1,
		Recovery = 0.5,
		AimMultiplier = 0.85,
		Camera = { Stiffness = 170, Damping = 18 },
		Viewmodel = { Kick = 0.15, Rise = 3, Roll = 1.5, Side = 0.03, Stiffness = 280, Damping = 23 },
		Shake = 0.06,
	},

	Handling = {
		AimFOV = 55,
		Sway = 0.9,
		WalkSpeedMultiplier = 0.96,
		AimWalkSpeedMultiplier = 0.65,
	},

	Viewmodel = {
		AimDistance = 0.25,
	},

	Animations = {},
}
