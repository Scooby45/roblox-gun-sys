local Util = {}

-- Standard normal sample (Box-Muller), truncated to +-2.5 sigma
function Util.Gaussian(rng: Random): number
	local u1 = math.max(rng:NextNumber(), 1e-9)
	local u2 = rng:NextNumber()
	local g = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
	return math.clamp(g, -2.5, 2.5)
end

local function basis(direction: Vector3): CFrame
	local up = math.abs(direction.Y) > 0.99 and Vector3.xAxis or Vector3.yAxis
	return CFrame.lookAt(Vector3.zero, direction, up)
end
Util.Basis = basis

-- Rotate a direction by pitch/yaw offsets (radians) in its own frame
function Util.Deviate(direction: Vector3, pitch: number, yaw: number): Vector3
	return (basis(direction) * CFrame.Angles(pitch, yaw, 0)).LookVector
end

-- Random direction within a gaussian cone. sigma is in radians.
function Util.GaussianCone(direction: Vector3, sigma: number, rng: Random): Vector3
	if sigma <= 0 then
		return direction.Unit
	end
	return Util.Deviate(direction.Unit, Util.Gaussian(rng) * sigma, Util.Gaussian(rng) * sigma)
end

-- Random direction uniformly inside a cone. maxAngle in radians.
function Util.UniformCone(direction: Vector3, maxAngle: number, rng: Random): Vector3
	if maxAngle <= 0 then
		return direction.Unit
	end
	local r = math.sqrt(rng:NextNumber()) * maxAngle
	local theta = rng:NextNumber() * 2 * math.pi
	return Util.Deviate(direction.Unit, r * math.sin(theta), r * math.cos(theta))
end

function Util.MOAToRadians(moa: number): number
	return math.rad(moa / 60)
end

function Util.FindDescendant(root: Instance, name: string, className: string?)
	local found = root:FindFirstChild(name, true)
	if found and (not className or found:IsA(className)) then
		return found
	end
	return nil
end

-- Closest distance from point P to segment AB, and the closest point
function Util.PointSegment(p: Vector3, a: Vector3, b: Vector3): (number, Vector3)
	local ab = b - a
	local lengthSq = ab:Dot(ab)
	local t = lengthSq > 0 and math.clamp((p - a):Dot(ab) / lengthSq, 0, 1) or 0
	local closest = a + ab * t
	return (p - closest).Magnitude, closest
end

-- Length of an oriented box projected along a direction (upper bound on chord length)
function Util.BoxExtentAlong(cf: CFrame, size: Vector3, direction: Vector3): number
	return math.abs(cf.RightVector:Dot(direction)) * size.X
		+ math.abs(cf.UpVector:Dot(direction)) * size.Y
		+ math.abs(cf.LookVector:Dot(direction)) * size.Z
end

function Util.IsFinite(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e7 and math.abs(v.Y) < 1e7 and math.abs(v.Z) < 1e7
end

return Util
