--[[
	Gun system server.

	The server owns every weapon's mechanical state (chamber, magazines, malfunctions, heat) and
	validates everything a client reports:
	  * fire rate (token bucket on RPM), muzzle position, selector, chamber, malfunctions
	  * reload / clear / cycle timings
	  * every hit: shot exists and is fresh, pellet direction matches the seeded spread, the path
	    is physically possible (re-traced with the same penetration/ricochet model), and the target
	    really was there (lag compensated hitbox history)
	Damage is always computed here from the server's own velocity estimate.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GunSystem = ReplicatedStorage:WaitForChild("GunSystem")
local Modules = GunSystem:WaitForChild("Modules")

local Settings = require(GunSystem:WaitForChild("Settings"))
local Registry = require(Modules:WaitForChild("Registry"))
local WeaponState = require(Modules:WaitForChild("WeaponState"))
local Ballistics = require(Modules:WaitForChild("Ballistics"))
local Util = require(Modules:WaitForChild("Util"))
local Remotes = require(Modules:WaitForChild("Remotes"))
local Materials = require(GunSystem:WaitForChild("Config"):WaitForChild("Materials"))

local LagCompensation = require(script:WaitForChild("LagCompensation"))
local DamageService = require(script:WaitForChild("DamageService"))

local Security = Settings.Security

local toolRecords = {} -- [Tool] = record
local playerData = {} -- [Player] = { Shots = {}, Order = {}, LastLook = 0 }

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function getPlayerData(player: Player)
	local data = playerData[player]
	if not data then
		data = { Shots = {}, Order = {}, LastLook = 0 }
		playerData[player] = data
	end
	return data
end

local function isAlive(character: Model?): boolean
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Returns the record for a tool the player is currently holding
local function getRecord(player: Player, tool: any)
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return nil
	end
	local character = player.Character
	if not character or tool.Parent ~= character or not isAlive(character) then
		return nil
	end
	local config = Registry.GetWeaponFromTool(tool)
	if not config then
		return nil
	end

	local record = toolRecords[tool]
	if not record then
		local state = WeaponState.new(config, math.random(1, 2 ^ 30))
		local fired = tool:GetAttribute("RoundsFired")
		state.Fouling = if type(fired) == "number" then fired else 0
		state.HeatTime = now()
		record = {
			Config = config,
			State = state,
			Tokens = Security.FireBucketSize,
			TokenTime = now(),
			LastShot = 0,
			Pending = nil,
		}
		toolRecords[tool] = record
		tool.Destroying:Connect(function()
			toolRecords[tool] = nil
		end)
		tool.Unequipped:Connect(function()
			record.Pending = nil
		end)
	end
	return record
end

local function sendState(player: Player, tool: Tool, record)
	Remotes.State:FireClient(player, tool, WeaponState.Serialize(record.State))
end

-- Cosmetic relay to everyone near enough to care
local function relay(remote: UnreliableRemoteEvent, source: Player, position: Vector3, ...)
	local maxDistance = Settings.Replication.MaxDistance
	for _, other in Players:GetPlayers() do
		if other ~= source then
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or (root.Position - position).Magnitude <= maxDistance then
				remote:FireClient(other, source, ...)
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Firing
----------------------------------------------------------------------------------------------------

local function validVector(v: any): boolean
	return typeof(v) == "Vector3" and Util.IsFinite(v)
end

local function validNumber(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < 1e9
end

Remotes.Fire.OnServerEvent:Connect(function(player: Player, tool, shotId, origin, aimDirection, seed, spread, predictedDud)
	if not (validNumber(shotId) and validVector(origin) and validVector(aimDirection) and validNumber(seed) and validNumber(spread)) then
		return
	end
	if aimDirection.Magnitude < 0.5 then
		return
	end
	aimDirection = aimDirection.Unit
	seed = math.floor(seed)

	local record = getRecord(player, tool)
	if not record then
		return
	end
	local config, state = record.Config, record.State
	local t = now()
	local data = getPlayerData(player)
	if data.Shots[shotId] then
		return
	end

	-- Fire rate (token bucket so jittery packets that arrive together aren't rejected)
	local refill = (t - record.TokenTime) / config.FireInterval * Security.FireRateTolerance
	record.Tokens = math.min(Security.FireBucketSize, record.Tokens + refill)
	record.TokenTime = t
	if record.Tokens < 0.999 then
		sendState(player, tool, record)
		return
	end
	record.Tokens -= 1

	-- Muzzle has to be near the shooter
	local character = player.Character
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not head or not root then
		return
	end
	local ping = math.clamp(player:GetNetworkPing(), 0, 1)
	local allowed = Security.MaxOriginDistance + root.AssemblyLinearVelocity.Magnitude * (ping + 0.1)
	if (origin - head.Position).Magnitude > allowed then
		sendState(player, tool, record)
		return
	end

	-- Firing interrupts shell-by-shell loading; anything else in progress blocks it
	if record.Pending then
		if record.Pending.Action == "Reload" and record.Pending.Kind == "Insert" then
			record.Pending = nil
		else
			sendState(player, tool, record)
			return
		end
	end

	local result = WeaponState.PullTrigger(state, config, t)
	local serverDud = result == "Dud"
	if result ~= "Fired" and not serverDud then
		sendState(player, tool, record)
		return
	end
	if serverDud or predictedDud == true then
		-- Client and server disagree (or both agree on a dud): resync
		sendState(player, tool, record)
		if serverDud then
			return
		end
	end

	record.LastShot = t
	tool:SetAttribute("RoundsFired", state.Fouling)

	-- Register the shot so hits can be validated
	local minSpread = config.Spread.MOA / 60 + config.Spread.Aim
	spread = math.clamp(spread, minSpread, 45)
	data.Shots[shotId] = {
		Time = t,
		Origin = origin,
		Config = config,
		Directions = Ballistics.PelletDirections(aimDirection, seed, config.Pellets, spread, config.Spread.PelletSpread),
		Pellets = {},
	}
	table.insert(data.Order, shotId)
	if #data.Order > Security.MaxShotsTracked then
		data.Shots[table.remove(data.Order, 1)] = nil
	end

	relay(Remotes.Replicate, player, origin, tool, config.Id, origin, aimDirection, seed, spread)

	if state.Malfunction then
		sendState(player, tool, record)
	end
end)

----------------------------------------------------------------------------------------------------
-- Hits
----------------------------------------------------------------------------------------------------

local function characterExcludeList(extra: { Instance })
	local list = table.clone(extra)
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

local function processHit(player: Player, data, hit)
	if type(hit) ~= "table" then
		return
	end
	local shot = data.Shots[hit.ShotId]
	if not shot then
		return
	end
	local t = now()
	if t - shot.Time > Security.ShotLifetime then
		return
	end

	local pellet = hit.Pellet
	if type(pellet) ~= "number" or not shot.Directions[pellet] then
		return
	end
	local part = hit.Part
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") or not part:IsDescendantOf(Workspace) then
		return
	end
	local character = Materials.CharacterOf(part)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or character == player.Character then
		return
	end

	-- Path: { origin, ...nodes, hitPosition } and one kind char per point
	local points, kinds = hit.Points, hit.Kinds
	if type(points) ~= "table" or type(kinds) ~= "string" then
		return
	end
	local count = #points
	if count < 2 or count > Settings.Ballistics.MaxSegments + 2 or #kinds ~= count then
		return
	end
	for i = 1, count do
		if not validVector(points[i]) then
			return
		end
	end
	local config = shot.Config
	if (points[1] - shot.Origin).Magnitude > 0.05 then
		return
	end
	local position = points[count]

	-- Every pellet may hit a limited number of distinct parts (over-penetration)
	local pelletRecord = shot.Pellets[pellet]
	if not pelletRecord then
		pelletRecord = { Count = 0, Parts = {}, SpeedFactor = 1 }
		shot.Pellets[pellet] = pelletRecord
	end
	if pelletRecord.Parts[part] or pelletRecord.Count > (config.AmmoData.MaxPenetrations or 0) then
		return
	end

	-- First leg must leave the muzzle along the seeded pellet direction (allowing for drop)
	local firstLeg = points[2] - points[1]
	local legLength = firstLeg.Magnitude
	if legLength > 0.5 then
		local T = legLength / config.MuzzleSpeed
		local expected = shot.Directions[pellet] * config.MuzzleSpeed * T + 0.5 * Ballistics.Gravity() * T * T
		local angle = math.deg(math.acos(math.clamp(expected.Unit:Dot(firstLeg.Unit), -1, 1)))
		if angle > Security.DirectionTolerance then
			return
		end
	end

	-- Can't arrive faster than the bullet could fly (generous: half the flight time, minus jitter)
	local pathLength = 0
	for i = 1, count - 1 do
		pathLength += (points[i + 1] - points[i]).Magnitude
	end
	if t - shot.Time < pathLength / config.MuzzleSpeed * 0.5 - 0.15 then
		return
	end

	-- Target was really there (lag compensated)
	if not LagCompensation.Check(character, part, position) then
		return
	end

	-- Re-trace the path through world geometry with the server's penetration model
	local ok, speed = Ballistics.TracePath(points, kinds, config, characterExcludeList({ character }))
	if not ok then
		return
	end
	speed *= pelletRecord.SpeedFactor

	local damage = Ballistics.Damage(config, speed, part.Name, character)
	pelletRecord.Count += 1
	pelletRecord.Parts[part] = true

	-- Energy lost going through this body part for any following hit with the same pellet
	local ammo = config.AmmoData
	local direction = (points[count] - points[count - 1]).Unit
	local thickness = Util.BoxExtentAlong(part.CFrame, part.Size, direction) * 0.7
	local cost = thickness * Settings.MillimetersPerStud * Materials.Profiles.Flesh.Resistance
	local budget = ammo.Penetration * (speed / config.MuzzleSpeed) ^ 2
	pelletRecord.SpeedFactor *= math.sqrt(math.max(0, 1 - cost / math.max(budget, 1e-6)))

	local applied = DamageService.Apply(player, humanoid, damage, {
		WeaponId = config.Id,
		Part = part,
		Position = position,
		Distance = pathLength,
		Speed = speed / Settings.StudsPerMeter,
		Headshot = part.Name == "Head",
	})
	if applied then
		Remotes.HitConfirm:FireClient(player, humanoid.Health <= 0, part.Name == "Head")
	end
end

Remotes.Hit.OnServerEvent:Connect(function(player: Player, hits)
	if type(hits) ~= "table" or #hits > 48 then
		return
	end
	local data = getPlayerData(player)
	for _, hit in hits do
		processHit(player, data, hit)
	end
end)

----------------------------------------------------------------------------------------------------
-- Actions (equip, reload, malfunction clearing, manual cycling, selector)
----------------------------------------------------------------------------------------------------

local ActionHandlers = {}

function ActionHandlers.Equip(player, tool, record)
	record.Pending = nil
	sendState(player, tool, record)
end

function ActionHandlers.ReloadStart(player, tool, record, kind)
	local config, state = record.Config, record.State
	if WeaponState.ReloadKind(state, config) ~= kind then
		sendState(player, tool, record)
		return
	end
	local required = WeaponState.ReloadTime(config, kind)
	if kind == "Insert" then
		required += config.Times.ReloadStart
	end
	record.Pending = { Action = "Reload", Kind = kind, Start = now(), Required = required }
	relay(
		Remotes.ActionFX,
		player,
		tool.Handle.Position,
		tool,
		kind == "Empty" and "ReloadEmpty" or (kind == "Insert" and "ReloadStart" or "Reload")
	)
end

function ActionHandlers.ReloadFinish(player, tool, record)
	local pending = record.Pending
	local config, state = record.Config, record.State
	if not pending or pending.Action ~= "Reload" then
		sendState(player, tool, record)
		return
	end
	local t = now()
	if t - pending.Start < pending.Required * Security.ActionTimeTolerance then
		sendState(player, tool, record)
		return
	end
	WeaponState.ApplyReload(state, config, pending.Kind)
	if pending.Kind == "Insert" and WeaponState.ReloadKind(state, config) == "Insert" then
		-- Next shell
		record.Pending = { Action = "Reload", Kind = "Insert", Start = t, Required = config.Times.ShellInsert }
		relay(Remotes.ActionFX, player, tool.Handle.Position, tool, "ShellInsert")
	else
		record.Pending = nil
	end
	sendState(player, tool, record)
end

function ActionHandlers.ClearStart(player, tool, record)
	record.Pending = { Action = "Clear", Start = now(), Required = WeaponState.ClearTime(record.State, record.Config) }
	relay(
		Remotes.ActionFX,
		player,
		tool.Handle.Position,
		tool,
		record.State.Malfunction == "DoubleFeed" and "ClearDoubleFeed" or "ClearMalfunction"
	)
end

function ActionHandlers.ClearFinish(player, tool, record)
	local pending = record.Pending
	if pending and pending.Action == "Clear" and now() - pending.Start >= pending.Required * Security.ActionTimeTolerance then
		WeaponState.ClearMalfunction(record.State, record.Config)
		record.Pending = nil
	end
	sendState(player, tool, record)
end

function ActionHandlers.Cycle(player, tool, record)
	local config, state = record.Config, record.State
	if record.Pending and record.Pending.Action == "Reload" and record.Pending.Kind == "Insert" then
		record.Pending = nil
	end
	if WeaponState.CanCycle(state, config) and now() - record.LastShot >= config.Times.Cycle * Security.ActionTimeTolerance then
		WeaponState.Cycle(state, config)
		relay(Remotes.ActionFX, player, tool.Handle.Position, tool, "Cycle")
	end
	sendState(player, tool, record)
end

function ActionHandlers.FireMode(player, tool, record, index)
	if type(index) == "number" and record.Config.FireModes[index] then
		record.State.FireMode = index
		relay(Remotes.ActionFX, player, tool.Handle.Position, tool, "FireMode")
	end
end

function ActionHandlers.Cancel(_player, _tool, record)
	record.Pending = nil
end

Remotes.Action.OnServerEvent:Connect(function(player: Player, tool, action, argument)
	if type(action) ~= "string" then
		return
	end
	local handler = ActionHandlers[action]
	if not handler then
		return
	end
	local record = getRecord(player, tool)
	if not record or not tool:FindFirstChild("Handle") then
		return
	end
	handler(player, tool, record, argument)
end)

----------------------------------------------------------------------------------------------------
-- Upper-body aim replication
----------------------------------------------------------------------------------------------------

Remotes.Look.OnServerEvent:Connect(function(player: Player, pitch)
	if not validNumber(pitch) then
		return
	end
	local data = getPlayerData(player)
	local t = os.clock()
	if t - data.LastLook < 0.5 / Settings.Replication.LookRate then
		return
	end
	data.LastLook = t
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		relay(Remotes.Look, player, root.Position, math.clamp(pitch, -1.4, 1.4))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerData[player] = nil
end)
