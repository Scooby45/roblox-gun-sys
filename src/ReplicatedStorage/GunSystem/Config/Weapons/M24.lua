return {
	Id = "M24",
	DisplayName = "M24 SWS",
	Ammo = "7.62x51",
	VelocityMultiplier = 1.03, -- 24" barrel

	Action = "Bolt", -- bolt is worked after each shot
	Feed = "Magazine", -- internal magazine modelled as a fixed magazine
	MagazineCapacity = 5,
	SpareMagazines = 4,
	BoltHoldOpen = false,
	RetainMagazines = true,
	FireModes = { "Safe", "Semi" },
	RPM = 50,
	BurstCount = 1,

	Reliability = {
		FailureToFire = 0.0003,
		FailureToFeed = 0.0002,
		Stovepipe = 0,
		DoubleFeed = 0,
		HeatSensitivity = 0.5,
		FoulingSensitivity = 0.2,
	},
	Heat = { PerShot = 0.04, CoolRate = 0.05 },

	Times = {
		Equip = 0.8,
		Cycle = 1.0,
		Reload = 2.6,
		ReloadEmpty = 3.2,
		ClearMalfunction = 1.4,
		ClearDoubleFeed = 1.4,
		FireModeSwitch = 0.25,
		CheckAmmo = 1.5,
		AimIn = 0.35,
		SprintOut = 0.3,
	},

	Spread = {
		MOA = 0.75,
		Hip = 4,
		Aim = 0,
		Move = 3,
		Air = 8,
		BloomPerShot = 0,
		BloomMax = 0,
		BloomRecovery = 4,
		Heat = 0.15,
	},

	Recoil = {
		Vertical = 3.2,
		VerticalVariance = 0.4,
		Horizontal = 0.7,
		HorizontalBias = 0.1,
		FirstShot = 1,
		Recovery = 0.65,
		AimMultiplier = 0.9,
		Camera = { Stiffness = 120, Damping = 13 },
		Viewmodel = { Kick = 0.4, Rise = 6, Roll = 2, Side = 0.04, Stiffness = 200, Damping = 18 },
		Shake = 0.2,
	},

	Handling = {
		AimFOV = 18, -- 3.5-10x optic (simple FOV zoom; use your own scope GUI if wanted)
		Sway = 1.3,
		WalkSpeedMultiplier = 0.92,
		AimWalkSpeedMultiplier = 0.5,
	},

	Viewmodel = {
		AimDistance = 0.4,
	},

	Animations = {},
}
