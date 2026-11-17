return {
	Id = "Remington870",
	DisplayName = "Remington 870",
	Ammo = "12ga Buckshot",
	VelocityMultiplier = 1,

	Action = "Pump", -- every shot must be pumped (auto-performed after releasing the trigger)
	Feed = "Tube", -- shells are loaded one at a time; firing interrupts the reload
	MagazineCapacity = 6, -- tube capacity
	SpareRounds = 24, -- loose shells (tube-fed weapons use SpareRounds instead of SpareMagazines)
	FireModes = { "Safe", "Semi" },
	RPM = 70, -- limited by the pump
	BurstCount = 1,

	Reliability = {
		FailureToFire = 0.0005,
		FailureToFeed = 0.0006, -- short-stroke / shell catch
		Stovepipe = 0,
		DoubleFeed = 0,
		HeatSensitivity = 1,
		FoulingSensitivity = 0.3,
	},
	Heat = { PerShot = 0.03, CoolRate = 0.06 },

	Times = {
		Equip = 0.7,
		Cycle = 0.55, -- pump
		ShellInsert = 0.5,
		ReloadStart = 0.35, -- bringing the gun up to load
		ReloadEnd = 0.3,
		ClearMalfunction = 1.6,
		ClearDoubleFeed = 1.6,
		FireModeSwitch = 0.2,
		CheckAmmo = 1.5,
		AimIn = 0.3,
		SprintOut = 0.22,
	},

	Spread = {
		MOA = 0,
		Hip = 1.2,
		Aim = 0,
		Move = 1,
		Air = 3,
		BloomPerShot = 0,
		BloomMax = 0,
		BloomRecovery = 4,
		Heat = 0,
		PelletSpread = 1.6, -- cylinder bore pattern (sigma)
	},

	Recoil = {
		Vertical = 5,
		VerticalVariance = 0.8,
		Horizontal = 1.2,
		HorizontalBias = 0.2,
		FirstShot = 1,
		Recovery = 0.7,
		AimMultiplier = 0.9,
		Camera = { Stiffness = 120, Damping = 13 },
		Viewmodel = { Kick = 0.45, Rise = 9, Roll = 4, Side = 0.06, Stiffness = 200, Damping = 18 },
		Shake = 0.3,
	},

	Handling = {
		AimFOV = 60,
		Sway = 1.1,
		WalkSpeedMultiplier = 0.95,
		AimWalkSpeedMultiplier = 0.65,
	},

	Viewmodel = {
		AimDistance = 0.3,
	},

	Animations = {},
}
