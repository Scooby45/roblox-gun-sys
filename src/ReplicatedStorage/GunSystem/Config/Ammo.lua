--[[
	Cartridge definitions. Real-world units:

	MuzzleVelocity    m/s from a reference barrel (weapons can scale it with VelocityMultiplier)
	Deceleration      m/s^2, average drag deceleration (v^2 = v0^2 - 2*a*d). Higher = sheds speed faster.
	Damage            damage at the muzzle before hit zone / armor multipliers
	DamageExponent    damage scales with (v / v0) ^ DamageExponent
	MinDamageRatio    floor for the velocity damage scale
	Penetration       mm of mild-steel equivalent the projectile can defeat at muzzle velocity.
	                  Penetration capacity scales with kinetic energy, i.e. (v / v0)^2.
	MaxPenetrations   how many separate objects a projectile may pass through
	Ricochet          multiplier on every material's ricochet angle (hard/fast bullets skip more)
	Deflection        multiplier on yaw after penetrating something
	ArmorPenetration  0-1, how much of body armor this round ignores
	Pellets           projectiles per shot
	TracerEvery       every Nth round is a tracer (0 = never, 1 = always)
	TracerColor       Color3 for tracers
	Quality           malfunction multiplier (1 = good factory ammo, >1 = surplus / bad)
]]

return {
	["5.56x45"] = {
		MuzzleVelocity = 910,
		Deceleration = 760,
		Damage = 34,
		DamageExponent = 1.1,
		MinDamageRatio = 0.3,
		Penetration = 9,
		MaxPenetrations = 4,
		Ricochet = 1.1,
		Deflection = 1.2, -- light fast bullets yaw/fragment readily
		ArmorPenetration = 0.45,
		Pellets = 1,
		TracerEvery = 4,
		TracerColor = Color3.fromRGB(255, 120, 70),
		Quality = 1,
	},

	["5.45x39"] = {
		MuzzleVelocity = 880,
		Deceleration = 720,
		Damage = 33,
		DamageExponent = 1.1,
		MinDamageRatio = 0.3,
		Penetration = 8,
		MaxPenetrations = 4,
		Ricochet = 1.05,
		Deflection = 1.3,
		ArmorPenetration = 0.4,
		Pellets = 1,
		TracerEvery = 4,
		TracerColor = Color3.fromRGB(140, 255, 120),
		Quality = 1.15, -- surplus
	},

	["7.62x51"] = {
		MuzzleVelocity = 840,
		Deceleration = 520,
		Damage = 58,
		DamageExponent = 1,
		MinDamageRatio = 0.35,
		Penetration = 13,
		MaxPenetrations = 5,
		Ricochet = 0.9,
		Deflection = 0.7,
		ArmorPenetration = 0.6,
		Pellets = 1,
		TracerEvery = 5,
		TracerColor = Color3.fromRGB(255, 110, 60),
		Quality = 1,
	},

	["9x19"] = {
		MuzzleVelocity = 365,
		Deceleration = 420,
		Damage = 24,
		DamageExponent = 1,
		MinDamageRatio = 0.35,
		Penetration = 3,
		MaxPenetrations = 2,
		Ricochet = 1.25, -- round nose pistol bullets skip easily
		Deflection = 1,
		ArmorPenetration = 0.1,
		Pellets = 1,
		TracerEvery = 0,
		TracerColor = Color3.fromRGB(255, 200, 120),
		Quality = 1,
	},

	["12ga Buckshot"] = {
		MuzzleVelocity = 400,
		Deceleration = 1250, -- round pellets have terrible ballistic coefficients
		Damage = 13, -- per pellet (00 buck: 9 pellets)
		DamageExponent = 1.3,
		MinDamageRatio = 0.1,
		Penetration = 1.6,
		MaxPenetrations = 1,
		Ricochet = 1.4,
		Deflection = 1.5,
		ArmorPenetration = 0,
		Pellets = 9,
		TracerEvery = 0,
		TracerColor = Color3.fromRGB(255, 200, 120),
		Quality = 1,
	},
}
