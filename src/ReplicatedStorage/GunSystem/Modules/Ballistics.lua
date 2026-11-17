--[[
	Shared ballistics math: spread, drag, penetration and ricochet.

	Model
	-----
	* Drag: constant deceleration along the flight path -> v^2 = v0^2 - 2*a*d
	* Penetration capacity scales with kinetic energy: budget = Penetration * (v / v0)^2   [mm steel-eq]
	* Cost of an obstacle = path length through it (mm) * material Resistance
	* After penetrating: v' = v * sqrt(1 - cost / budget)  (energy spent), plus random yaw that grows
	  with how much of the budget was used.
	* Ricochet: below a material's critical grazing angle the bullet may skip, losing speed.

	Used by the client to simulate bullets (FastCast) and by the server to validate reported paths.
]]

local Workspace = game:GetService("Workspace")

local GunSystem = script.Parent.Parent
local Settings = require(GunSystem:WaitForChild("Settings"))
local Materials = require(GunSystem:WaitForChild("Config"):WaitForChild("Materials"))
local Util = require(script.Parent:WaitForChild("Util"))

local Ballistics = {}

local MM_PER_STUD = Settings.MillimetersPerStud
local MIN_SPEED = Settings.Ballistics.MinSpeed * Settings.StudsPerMeter

Ballistics.MinSpeed = MIN_SPEED

function Ballistics.Gravity(): Vector3
	if Settings.UseRealisticGravity then
		return Vector3.new(0, -9.81 * Settings.StudsPerMeter, 0)
	end
	return Vector3.new(0, -Workspace.Gravity, 0)
end

-- Acceleration FastCast should use for a projectile launched along `direction`
function Ballistics.Acceleration(direction: Vector3, deceleration: number): Vector3
	return Ballistics.Gravity() - direction.Unit * deceleration
end

function Ballistics.SpeedAfter(speed: number, deceleration: number, distance: number): number
	return math.sqrt(math.max(0, speed * speed - 2 * deceleration * distance))
end

--[[
	Deterministic shot dispersion. Both the shooter, the server and every observer produce the
	same pellet directions from (aimDirection, seed, spread).
	spreadDeg: overall shot dispersion (sigma, degrees). pelletSpreadDeg: per-pellet pattern (sigma).
]]
function Ballistics.PelletDirections(aimDirection: Vector3, seed: number, pellets: number, spreadDeg: number, pelletSpreadDeg: number)
	local rng = Random.new(seed)
	local center = Util.GaussianCone(aimDirection, math.rad(spreadDeg) * 0.5, rng)
	local directions = table.create(pellets)
	for i = 1, pellets do
		if pellets > 1 then
			directions[i] = Util.GaussianCone(center, math.rad(pelletSpreadDeg), rng)
		else
			directions[i] = center
		end
	end
	return directions
end

-- Per-pellet RNG for penetration/ricochet randomness, identical on every client
function Ballistics.PelletRandom(seed: number, pellet: number): Random
	return Random.new((seed * 31 + pellet * 7919) % 2147483647)
end

local thicknessParams = RaycastParams.new()
thicknessParams.FilterType = Enum.RaycastFilterType.Include
thicknessParams.IgnoreWater = true

--[[
	Measures how far a ray travels through `instance` starting at `entry` along `direction`.
	Casts backwards from `entry + direction * maxDepth` against only that instance and takes the
	first surface it meets as the exit. Returns nil if the object is thicker than maxDepth.
]]
function Ballistics.MeasureThickness(instance: Instance, entry: Vector3, direction: Vector3, maxDepth: number): (number?, Vector3?)
	if maxDepth <= 0.01 then
		return nil, nil
	end
	thicknessParams.FilterDescendantsInstances = { instance }
	local far = entry + direction * maxDepth
	local result = Workspace:Raycast(far, -direction * (maxDepth + 0.05), thicknessParams)
	if not result then
		return nil, nil
	end
	local thickness = (result.Position - entry).Magnitude
	if (far - result.Position).Magnitude < 0.005 then
		-- Started inside the object (e.g. terrain thicker than maxDepth)
		return nil, nil
	end
	return thickness, result.Position
end

local function reflect(direction: Vector3, normal: Vector3): Vector3
	return direction - 2 * direction:Dot(normal) * normal
end

-- Angle in degrees between the flight path and the surface plane (0 = grazing, 90 = head on)
local function grazingAngle(direction: Vector3, normal: Vector3): number
	return math.deg(math.asin(math.clamp(-direction:Dot(normal), 0, 1)))
end
Ballistics.GrazingAngle = grazingAngle

--[[
	Decides what happens when a projectile meets a surface.

	state: { Penetrations: number, Ricochets: number, Speed0: number }
	returns {
		Kind = "Stop" | "Penetrate" | "Ricochet",
		Profile, Character,
		Position (exit or continue point), Direction, Speed,
		Thickness (penetrations only),
	}
]]
function Ballistics.ResolveImpact(result: RaycastResult, direction: Vector3, speed: number, ammo, state, rng: Random)
	local profile, character = Materials.Resolve(result.Instance, result.Material)
	local outcome = { Kind = "Stop", Profile = profile, Character = character, Speed = 0 }

	-- Hats, invisible triggers... continue untouched
	if profile.PassThrough then
		local thickness, exit =
			Ballistics.MeasureThickness(result.Instance, result.Position, direction, Settings.Ballistics.MaxPenetrationDepth)
		if thickness then
			outcome.Kind = "Penetrate"
			outcome.Position = exit
			outcome.Direction = direction
			outcome.Speed = speed
			outcome.Thickness = thickness
			outcome.Silent = true
		end
		return outcome
	end

	local energyRatio = (speed / state.Speed0) ^ 2

	-- Ricochet
	local critical = profile.RicochetAngle * (ammo.Ricochet or 1)
	if critical > 0 and state.Ricochets < Settings.Ballistics.MaxRicochets then
		local graze = grazingAngle(direction, result.Normal)
		if graze < critical then
			local chance = 1 - (graze / critical) ^ 2
			if rng:NextNumber() < chance then
				local normal = result.Normal
				local reflected = reflect(direction, normal)
				-- Bullets leave the surface at a shallower angle than they arrive and scatter a little
				reflected = (reflected - normal * reflected:Dot(normal) * 0.35).Unit
				reflected = Util.GaussianCone(reflected, math.rad(2 + graze * 0.3), rng)
				if reflected:Dot(normal) < 0.02 then
					reflected = (reflected + normal * 0.05).Unit
				end
				outcome.Kind = "Ricochet"
				outcome.Position = result.Position + normal * 0.02
				outcome.Direction = reflected
				outcome.Speed = speed * profile.RicochetRetention * (0.85 + rng:NextNumber() * 0.15)
				return outcome
			end
		end
	end

	-- Water: bullets destabilise and stop within a short distance
	if profile.Liquid then
		local budget = ammo.Penetration * energyRatio
		outcome.Kind = "Penetrate"
		outcome.Liquid = true
		outcome.Position = result.Position + direction * 0.05
		outcome.Direction = Util.GaussianCone(direction, math.rad(profile.Deflection) * 0.5, rng)
		outcome.Speed = speed * 0.6
		outcome.Thickness = 0
		outcome.Depth = math.min(Settings.Ballistics.MaxPenetrationDepth * 2, budget / profile.Resistance / MM_PER_STUD)
		return outcome
	end

	-- Penetration
	if state.Penetrations >= (ammo.MaxPenetrations or 0) or profile.Resistance == math.huge then
		return outcome
	end
	local budget = ammo.Penetration * energyRatio
	local maxDepth = math.min(Settings.Ballistics.MaxPenetrationDepth, budget / math.max(profile.Resistance, 1e-4) / MM_PER_STUD)
	local thickness, exit = Ballistics.MeasureThickness(result.Instance, result.Position, direction, maxDepth)
	if not thickness then
		return outcome
	end
	local cost = thickness * MM_PER_STUD * profile.Resistance
	if cost >= budget then
		return outcome
	end

	local used = cost / budget
	local newSpeed = speed * math.sqrt(1 - used)
	if newSpeed < MIN_SPEED then
		return outcome
	end

	-- Yaw after exiting: more if the bullet barely made it through
	local yaw = math.rad(profile.Deflection * (ammo.Deflection or 1)) * used
	outcome.Kind = "Penetrate"
	outcome.Position = exit
	outcome.Direction = Util.GaussianCone(direction, yaw * 0.5, rng)
	outcome.Speed = newSpeed
	outcome.Thickness = thickness
	return outcome
end

--[[
	SERVER: re-traces a path reported by a client and returns the projectile speed at the end, or
	false + reason if the path is impossible (shooting through walls it can't penetrate, etc.).

	points: { origin, node2, ..., finalHitPosition }
	kinds:  string with one char per point: "O" origin, "P" penetration exit, "R" ricochet, "H" hit
	exclude: instances to ignore (all characters - characters are validated separately)
]]
local traceParams = RaycastParams.new()
traceParams.FilterType = Enum.RaycastFilterType.Exclude
traceParams.IgnoreWater = true

function Ballistics.TracePath(points: { Vector3 }, kinds: string, config, exclude: { Instance })
	local ammo = config.AmmoData
	local v0 = config.MuzzleSpeed
	local deceleration = config.Deceleration
	local gravity = Ballistics.Gravity()
	local tolerance = Settings.Security.PenetrationTolerance
	local maxDepthLimit = Settings.Ballistics.MaxPenetrationDepth

	traceParams.FilterDescendantsInstances = exclude

	local speed = v0
	local penetrations, ricochets, total = 0, 0, 0

	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local leg = b - a
		local legLength = leg.Magnitude
		if legLength > 1e-3 then
			total += legLength
			if total > config.MaxRange + 10 then
				return false, "range"
			end

			local endsInRicochet = string.sub(kinds, i + 1, i + 1) == "R"
			local legDir = leg / legLength

			-- Rebuild the ballistic arc between the two nodes so drop doesn't clip the ground
			local T = legLength / math.max(speed, 1)
			local sag = 0.125 * gravity.Magnitude * T * T
			local steps = if sag > 0.4 then math.clamp(math.ceil(sag / 0.4), 2, 8) else 1
			local launch = (leg - 0.5 * gravity * T * T) / T

			local legStart = if i > 1 then a + legDir * 0.03 else a
			local previous = legStart
			local lastSpeedPoint = a

			for s = 1, steps do
				local t = T * s / steps
				local target = if s == steps then b else a + launch * t + 0.5 * gravity * t * t
				local origin = previous
				local guard = 0
				while true do
					guard += 1
					if guard > 16 then
						return false, "complex"
					end
					local segment = target - origin
					local segmentLength = segment.Magnitude
					if segmentLength < 1e-3 then
						break
					end
					local direction = segment / segmentLength
					local result = Workspace:Raycast(origin, segment, traceParams)
					if not result then
						break
					end

					-- Account for drag up to this obstacle
					speed = Ballistics.SpeedAfter(speed, deceleration, (result.Position - lastSpeedPoint).Magnitude)
					lastSpeedPoint = result.Position

					local profile = Materials.Resolve(result.Instance, result.Material)

					if endsInRicochet and s == steps and (b - result.Position).Magnitude < 1.25 then
						-- The surface the client says it skipped off
						local critical = profile.RicochetAngle * (ammo.Ricochet or 1)
						local graze = grazingAngle(direction, result.Normal)
						if critical <= 0 or graze > critical * 1.5 + 3 then
							return false, "ricochet"
						end
						ricochets += 1
						if ricochets > Settings.Ballistics.MaxRicochets then
							return false, "ricochets"
						end
						speed *= profile.RicochetRetention
						break
					end

					local thickness, exit
					if profile.PassThrough then
						thickness, exit = Ballistics.MeasureThickness(result.Instance, result.Position, direction, maxDepthLimit)
						if not thickness then
							return false, "blocked"
						end
					else
						penetrations += 1
						if penetrations > (ammo.MaxPenetrations or 0) or profile.Resistance == math.huge then
							return false, "penetrations"
						end
						local budget = ammo.Penetration * (speed / v0) ^ 2
						local allowed = budget * tolerance
						local maxDepth = math.min(maxDepthLimit, allowed / math.max(profile.Resistance, 1e-4) / MM_PER_STUD + 0.25)
						thickness, exit = Ballistics.MeasureThickness(result.Instance, result.Position, direction, maxDepth)
						if not thickness then
							return false, "blocked"
						end
						local cost = thickness * MM_PER_STUD * profile.Resistance
						if cost > allowed then
							return false, "blocked"
						end
						speed *= math.sqrt(math.max(0.02, 1 - cost / math.max(budget, 1e-6)))
					end
					origin = exit + direction * 0.02
					-- Exit is at/after this sub-segment's end (a penetration node): done
					if (target - origin):Dot(direction) <= 0 then
						break
					end
				end
				previous = target
			end

			speed = Ballistics.SpeedAfter(speed, deceleration, (b - lastSpeedPoint).Magnitude)
			if speed < MIN_SPEED * 0.85 then
				return false, "spent"
			end
		end
	end

	return true, speed
end

--[[
	Damage for a hit given the projectile speed at impact.
]]
function Ballistics.Damage(config, speed: number, partName: string, character: Model?)
	local ammo = config.AmmoData
	local ratio = math.clamp(speed / config.MuzzleSpeed, 0, 1.2)
	local scale = math.max(ratio ^ (ammo.DamageExponent or 1), ammo.MinDamageRatio or 0)
	local zones = Settings.Damage.HitZones
	local damage = ammo.Damage * scale * (zones[partName] or zones.Default)

	if character then
		local armorPen = ammo.ArmorPenetration or 0
		if partName == "Head" then
			local helmet = character:GetAttribute("Helmet")
			if typeof(helmet) == "number" then
				damage *= 1 - math.clamp(helmet, 0, 1) * (1 - armorPen)
			end
		elseif Settings.Damage.TorsoParts[partName] then
			local armor = character:GetAttribute("BodyArmor")
			if typeof(armor) == "number" then
				damage *= 1 - math.clamp(armor, 0, 1) * (1 - armorPen)
			end
		end
	end
	return damage
end

return Ballistics
