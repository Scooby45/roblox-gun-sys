--[[
	Client projectile simulation on FastCast.

	One Caster handles every bullet on this client (your own and everybody else's). Your own bullets
	report humanoid hits to the server (batched once per frame); other players' bullets are purely
	cosmetic but use the same seed so they fly, penetrate and ricochet exactly like the shooter saw.

	Penetration / ricochet: when a cast hits something, Ballistics.ResolveImpact decides the outcome and,
	if the bullet continues, a new cast is launched from the exit point (or ricochet point) with the
	reduced velocity. The path nodes are recorded so the server can re-trace them.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GunSystem = ReplicatedStorage:WaitForChild("GunSystem")
local Modules = GunSystem:WaitForChild("Modules")

local Settings = require(GunSystem:WaitForChild("Settings"))
local FastCast = require(Modules:WaitForChild("FastCastLoader"))
local Ballistics = require(Modules:WaitForChild("Ballistics"))
local Remotes = require(Modules:WaitForChild("Remotes"))
local Util = require(Modules:WaitForChild("Util"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local LocalPlayer = Players.LocalPlayer

local Projectiles = {}

local caster = FastCast.new()
local hitQueue = {}

-- Callback for local hit feedback (set by the HUD)
Projectiles.OnLocalHit = nil :: ((part: BasePart, character: Model) -> ())?

----------------------------------------------------------------------------------------------------
-- Raycast params (per shooter, cached)
----------------------------------------------------------------------------------------------------

local paramsCache = setmetatable({}, { __mode = "k" })

local function getParams(character: Model?, ignoreWater: boolean): RaycastParams
	local key = character or Effects.Folder
	local entry = paramsCache[key]
	if not entry then
		entry = {}
		paramsCache[key] = entry
	end
	local params = entry[ignoreWater]
	if not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = ignoreWater
		entry[ignoreWater] = params
	end
	-- Refreshed every time: the camera's viewmodel and the shooter's character change
	local filter = { Effects.Folder, Workspace.CurrentCamera }
	if character then
		table.insert(filter, character)
	end
	params.FilterDescendantsInstances = filter
	return params
end
Projectiles.GetParams = getParams

----------------------------------------------------------------------------------------------------
-- Casting
----------------------------------------------------------------------------------------------------

local function releaseTracer(data)
	if data.Tracer then
		Effects.ReleaseTracer(data.Tracer)
		data.Tracer = nil
	end
end

local function safeTerminate(cast)
	if cast.StateInfo and cast.StateInfo.UpdateConnection then
		pcall(cast.Terminate, cast)
	end
end

local function launch(data, origin: Vector3, direction: Vector3, speed: number)
	local remaining = data.Config.MaxRange - data.Traveled
	if data.LiquidLimit then
		remaining = math.min(remaining, data.LiquidLimit)
		data.LiquidLimit = nil
	end
	data.Segments += 1
	if remaining < 0.5 or speed < Ballistics.MinSpeed or data.Segments > Settings.Ballistics.MaxSegments then
		releaseTracer(data)
		return
	end

	local behavior = FastCast.newBehavior()
	behavior.RaycastParams = getParams(data.Character, data.IgnoreWater)
	behavior.Acceleration = Ballistics.Acceleration(direction, data.Config.Deceleration)
	behavior.MaxDistance = remaining
	behavior.HighFidelityBehavior = if Settings.Ballistics.HighFidelity
		then FastCast.HighFidelityBehavior.Always
		else FastCast.HighFidelityBehavior.Default
	behavior.AutoIgnoreContainer = false

	data.SegmentStart = origin
	data.LaunchDirection = direction
	local cast = caster:Fire(origin, direction, direction * speed, behavior)
	cast.UserData = data
	data.Cast = cast
end

--[[
	info = {
		Shooter: Player, Character: Model?, Config, Origin: Vector3, Directions: {Vector3},
		Seed: number, ShotId: number?, IsLocal: boolean,
	}
]]
function Projectiles.Fire(info)
	local config = info.Config
	local ammo = config.AmmoData
	local tracer = ammo.TracerEvery > 0 and info.Seed % ammo.TracerEvery == 0

	for pellet, direction in info.Directions do
		local data = {
			Shooter = info.Shooter,
			Character = info.Character,
			IsLocal = info.IsLocal,
			ShotId = info.ShotId,
			Pellet = pellet,
			Config = config,
			Ammo = ammo,
			Rng = Ballistics.PelletRandom(info.Seed, pellet),
			Impact = { Penetrations = 0, Ricochets = 0, Speed0 = config.MuzzleSpeed },
			Points = { info.Origin },
			Kinds = "O",
			Traveled = 0,
			Segments = 0,
			IgnoreWater = false,
			Tracer = if tracer and pellet == 1 then Effects.AcquireTracer(ammo.TracerColor) else nil,
			Flyby = info.IsLocal, -- no flyby sounds for your own bullets
		}
		launch(data, info.Origin, direction, config.MuzzleSpeed)
	end
end

----------------------------------------------------------------------------------------------------
-- FastCast events
----------------------------------------------------------------------------------------------------

caster.LengthChanged:Connect(function(cast, lastPoint: Vector3, rayDirection: Vector3, displacement: number, segmentVelocity: Vector3)
	local data = cast.UserData
	if type(data) ~= "table" or not data.Config then
		return
	end
	local current = lastPoint + rayDirection * displacement

	if data.Tracer then
		Effects.UpdateTracer(data.Tracer, current, segmentVelocity)
	end

	if not data.Flyby then
		local distance, closest = Util.PointSegment(Workspace.CurrentCamera.CFrame.Position, lastPoint, current)
		if distance < Settings.Effects.WhizzRadius then
			data.Flyby = true
			Effects.Flyby(closest, segmentVelocity.Magnitude)
		end
	end

	-- Spent: too slow, or drag has turned it around
	if not data.Ending and (segmentVelocity.Magnitude < Ballistics.MinSpeed or segmentVelocity:Dot(data.LaunchDirection) <= 0) then
		data.Ending = true
		task.defer(safeTerminate, cast)
	end
end)

caster.RayHit:Connect(function(cast, result: RaycastResult, segmentVelocity: Vector3)
	local data = cast.UserData
	if type(data) ~= "table" or not data.Config then
		return
	end
	local speed = segmentVelocity.Magnitude
	if speed < 1e-3 then
		return
	end
	local direction = segmentVelocity / speed
	data.Traveled += (result.Position - data.SegmentStart).Magnitude

	local outcome = Ballistics.ResolveImpact(result, direction, speed, data.Ammo, data.Impact, data.Rng)
	local profile = outcome.Profile

	if not outcome.Silent then
		Effects.Impact(result.Position, result.Normal, profile, result.Instance, false)
	end

	-- Report hits on characters (only for our own bullets)
	local character = outcome.Character
	if data.IsLocal and character and character ~= data.Character and result.Instance:IsA("BasePart") then
		local points = table.clone(data.Points)
		table.insert(points, result.Position)
		table.insert(hitQueue, {
			ShotId = data.ShotId,
			Pellet = data.Pellet,
			Part = result.Instance,
			Points = points,
			Kinds = data.Kinds .. "H",
		})
		if Projectiles.OnLocalHit then
			Projectiles.OnLocalHit(result.Instance, character)
		end
	end

	if outcome.Kind == "Penetrate" then
		if not outcome.Silent then
			data.Impact.Penetrations += 1
			if not profile.Liquid then
				Effects.Impact(outcome.Position, direction, profile, result.Instance, true)
			end
		end
		if outcome.Liquid then
			-- Continue underwater for a short distance, ignoring the water itself
			data.IgnoreWater = true
			data.LiquidLimit = outcome.Depth
		end
		table.insert(data.Points, outcome.Position)
		data.Kinds ..= "P"
		data.Traveled += outcome.Thickness or 0
		launch(data, outcome.Position + outcome.Direction * 0.02, outcome.Direction, outcome.Speed)
	elseif outcome.Kind == "Ricochet" then
		data.Impact.Ricochets += 1
		table.insert(data.Points, result.Position)
		data.Kinds ..= "R"
		launch(data, outcome.Position, outcome.Direction, outcome.Speed)
	end
end)

caster.CastTerminating:Connect(function(cast)
	local data = cast.UserData
	if type(data) ~= "table" then
		return
	end
	-- Only release the tracer if no continuation cast took it over
	if data.Cast == cast then
		releaseTracer(data)
	end
end)

-- Send all hits from this frame in one remote call
RunService.Heartbeat:Connect(function()
	if #hitQueue > 0 then
		Remotes.Hit:FireServer(hitQueue)
		hitQueue = {}
	end
end)

Projectiles.LocalPlayer = LocalPlayer

return Projectiles
