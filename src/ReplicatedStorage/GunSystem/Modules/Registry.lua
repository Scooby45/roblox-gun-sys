--[[
	Access to weapon / ammo configs with defaults merged in and derived values precomputed.
]]

local Config = script.Parent.Parent:WaitForChild("Config")
local Settings = require(script.Parent.Parent:WaitForChild("Settings"))

local Defaults = require(Config:WaitForChild("Defaults"))
local Weapons = require(Config:WaitForChild("Weapons"))
local Ammo = require(Config:WaitForChild("Ammo"))

local Registry = {}

local function deepMerge(base, override)
	local result = {}
	for key, value in base do
		result[key] = value
	end
	for key, value in override do
		if type(value) == "table" and type(result[key]) == "table" and #value == 0 and next(value) ~= nil then
			result[key] = deepMerge(result[key], value)
		else
			result[key] = value
		end
	end
	return result
end

local weaponCache = {}
local ammoCache = {}

function Registry.GetAmmo(ammoId: string)
	local cached = ammoCache[ammoId]
	if cached then
		return cached
	end
	local raw = Ammo[ammoId]
	if not raw then
		return nil
	end
	local ammo = table.clone(raw)
	ammo.Id = ammoId
	ammoCache[ammoId] = ammo
	return ammo
end

function Registry.GetWeapon(weaponId: string)
	local cached = weaponCache[weaponId]
	if cached then
		return cached
	end
	local raw = Weapons[weaponId]
	if not raw then
		return nil
	end

	local config = deepMerge(Defaults, raw)
	config.Id = weaponId
	local ammo = Registry.GetAmmo(config.Ammo)
	assert(ammo, `[GunSystem] Weapon {weaponId} uses unknown ammo "{config.Ammo}"`)
	config.AmmoData = ammo

	-- Derived values (studs)
	local spm = Settings.StudsPerMeter
	config.MuzzleSpeed = ammo.MuzzleVelocity * config.VelocityMultiplier * spm
	config.Deceleration = ammo.Deceleration * spm
	config.FireInterval = 60 / config.RPM
	config.Pellets = ammo.Pellets or 1
	-- Max useful range: where speed falls under the minimum (v^2 = v0^2 - 2ad)
	local minSpeed = Settings.Ballistics.MinSpeed * spm
	local range = (config.MuzzleSpeed ^ 2 - minSpeed ^ 2) / (2 * config.Deceleration)
	config.MaxRange = math.clamp(range, 50, Settings.Ballistics.MaxRange)

	weaponCache[weaponId] = config
	return config
end

function Registry.GetWeaponFromTool(tool: Instance?)
	if not tool or not tool:IsA("Tool") then
		return nil
	end
	local id = tool:GetAttribute("WeaponId")
	if type(id) ~= "string" then
		return nil
	end
	return Registry.GetWeapon(id)
end

function Registry.AllWeapons()
	local list = {}
	for id in Weapons do
		table.insert(list, Registry.GetWeapon(id))
	end
	return list
end

return Registry
