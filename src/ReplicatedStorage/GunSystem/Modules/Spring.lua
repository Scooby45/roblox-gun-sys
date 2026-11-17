--[[
	Damped Vector3 spring with fixed sub-stepping (stable at any framerate).
	Position is the offset, Target is the rest point (usually zero).
]]

local Spring = {}
Spring.__index = Spring

local STEP = 1 / 240

function Spring.new(stiffness: number, damping: number, mass: number?)
	return setmetatable({
		Position = Vector3.zero,
		Velocity = Vector3.zero,
		Target = Vector3.zero,
		Stiffness = stiffness,
		Damping = damping,
		Mass = mass or 1,
	}, Spring)
end

function Spring:Impulse(velocity: Vector3)
	self.Velocity += velocity
end

function Spring:Update(dt: number): Vector3
	dt = math.min(dt, 0.1)
	local steps = math.clamp(math.ceil(dt / STEP), 1, 24)
	local h = dt / steps
	local k, c, m = self.Stiffness, self.Damping, self.Mass
	local position, velocity, target = self.Position, self.Velocity, self.Target
	for _ = 1, steps do
		local force = (target - position) * k - velocity * c
		velocity += force / m * h
		position += velocity * h
	end
	self.Position, self.Velocity = position, velocity
	return position
end

function Spring:Reset()
	self.Position = Vector3.zero
	self.Velocity = Vector3.zero
end

return Spring
