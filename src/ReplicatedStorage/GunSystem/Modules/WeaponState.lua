--[[
	Mechanical state of a firearm, shared by client (prediction) and server (authority).

	Tracks the chamber, the inserted magazine / tube, spare magazines, bolt state, heat, fouling and
	malfunctions. Malfunction rolls come from a seeded RNG indexed by shot number, so the client
	predicts the exact same jams as the server without waiting for a round trip.

	Chamber: "Empty" | "Loaded" | "Spent"
	Malfunction: nil | "FailureToFire" | "FailureToFeed" | "Stovepipe" | "DoubleFeed"
]]

local GunSystem = script.Parent.Parent
local Settings = require(GunSystem:WaitForChild("Settings"))

local WeaponState = {}

local function firstFireMode(config): number
	for index, mode in config.FireModes do
		if mode ~= "Safe" then
			return index
		end
	end
	return 1
end

function WeaponState.new(config, seed: number)
	local state = {
		WeaponId = config.Id,
		Seed = seed,
		Shots = 0, -- trigger pulls that reached the primer (indexes the malfunction RNG)
		Chamber = "Loaded",
		Mag = config.MagazineCapacity, -- rounds in the inserted magazine / tube
		HasMag = config.Feed == "Magazine",
		Reserve = nil, -- array of spare magazine counts, or number of loose rounds (tube)
		Malfunction = nil,
		BoltOpen = false, -- locked back on an empty magazine
		Heat = 0,
		HeatTime = 0,
		Fouling = 0, -- rounds fired since cleaned
		FireMode = firstFireMode(config),
	}
	if config.Feed == "Magazine" then
		local mags = table.create(config.SpareMagazines)
		for i = 1, config.SpareMagazines do
			mags[i] = config.MagazineCapacity
		end
		state.Reserve = mags
	else
		state.Reserve = config.SpareRounds
	end
	return state
end

----------------------------------------------------------------------------------------------------
-- Queries
----------------------------------------------------------------------------------------------------

function WeaponState.FireModeName(state, config): string
	return config.FireModes[state.FireMode] or "Semi"
end

function WeaponState.IsManual(config): boolean
	return config.Action == "Pump" or config.Action == "Bolt"
end

function WeaponState.TotalReserve(state): number
	if type(state.Reserve) == "number" then
		return state.Reserve
	end
	local total = 0
	for _, count in state.Reserve do
		total += count
	end
	return total
end

function WeaponState.LoadedRounds(state): number
	return (if state.HasMag or type(state.Reserve) == "number" then state.Mag else 0) + (if state.Chamber == "Loaded" then 1 else 0)
end

-- Rough "feel" of the magazine weight, used when the HUD doesn't show exact counts
function WeaponState.MagEstimate(state, config): string
	if not state.HasMag and config.Feed == "Magazine" then
		return "No magazine"
	end
	local fraction = state.Mag / config.MagazineCapacity
	if fraction <= 0 then
		return "Empty"
	elseif fraction < 0.2 then
		return "Almost empty"
	elseif fraction < 0.45 then
		return "Less than half"
	elseif fraction < 0.7 then
		return "About half"
	elseif fraction < 0.95 then
		return "More than half"
	end
	return "Full"
end

function WeaponState.UpdateHeat(state, config, now: number)
	local dt = now - state.HeatTime
	if dt > 0 then
		state.Heat *= math.exp(-dt * config.Heat.CoolRate)
	end
	state.HeatTime = now
end

function WeaponState.MalfunctionChance(state, config, kind: string): number
	local reliability = config.Reliability
	local base = reliability[kind] or 0
	if base <= 0 then
		return 0
	end
	local heatFactor = 1 + reliability.HeatSensitivity * state.Heat * state.Heat
	local foulingFactor = 1 + reliability.FoulingSensitivity * state.Fouling / 1000
	local ammoFactor = config.AmmoData.Quality or 1
	return base * heatFactor * foulingFactor * ammoFactor * Settings.MalfunctionMultiplier
end

----------------------------------------------------------------------------------------------------
-- Mechanics
----------------------------------------------------------------------------------------------------

local function rolls(state, salt: number)
	local rng = Random.new((state.Seed + state.Shots * 7919 + salt * 104729) % 2147483647)
	return rng:NextNumber(), rng:NextNumber(), rng:NextNumber(), rng:NextNumber()
end

-- Strip a round from the magazine / tube into the chamber
local function feed(state, config, feedRoll: number?, doubleFeedRoll: number?)
	state.Chamber = "Empty"
	local hasSource = state.HasMag or config.Feed == "Tube"
	if not hasSource or state.Mag <= 0 then
		if config.BoltHoldOpen and state.HasMag then
			state.BoltOpen = true
		end
		return
	end
	if doubleFeedRoll and state.Mag >= 2 and doubleFeedRoll < WeaponState.MalfunctionChance(state, config, "DoubleFeed") then
		-- Two rounds trying to enter the chamber at once
		state.Mag -= 1
		state.Malfunction = "DoubleFeed"
		return
	end
	if feedRoll and feedRoll < WeaponState.MalfunctionChance(state, config, "FailureToFeed") then
		state.Malfunction = "FailureToFeed"
		return
	end
	state.Mag -= 1
	state.Chamber = "Loaded"
	state.BoltOpen = false
end

--[[
	Pulls the trigger once. Returns one of:
	  "Fired"       a round was fired (state.Malfunction may now be set by the cycling)
	  "Safe"        selector on safe
	  "Malfunction" weapon is jammed, nothing happens
	  "NeedsCycle"  manual action not worked yet
	  "Dry"         click, nothing in the chamber
	  "Dud"         click, round in chamber didn't fire (FailureToFire)
]]
function WeaponState.PullTrigger(state, config, now: number): string
	if WeaponState.FireModeName(state, config) == "Safe" then
		return "Safe"
	end
	if state.Malfunction then
		return "Malfunction"
	end
	if state.Chamber == "Spent" then
		return "NeedsCycle"
	end
	if state.Chamber ~= "Loaded" then
		return "Dry"
	end

	state.Shots += 1
	local fireRoll, ejectRoll, doubleFeedRoll, feedRoll = rolls(state, 0)
	WeaponState.UpdateHeat(state, config, now)

	if fireRoll < WeaponState.MalfunctionChance(state, config, "FailureToFire") then
		state.Malfunction = "FailureToFire"
		return "Dud"
	end

	state.Chamber = "Spent"
	state.Heat = math.min(1, state.Heat + config.Heat.PerShot)
	state.Fouling += 1

	if config.Action == "Gas" then
		-- Self-loading: extract, eject, feed
		if ejectRoll < WeaponState.MalfunctionChance(state, config, "Stovepipe") then
			state.Malfunction = "Stovepipe"
			return "Fired"
		end
		feed(state, config, feedRoll, doubleFeedRoll)
	end
	return "Fired"
end

-- Manual action (pump / bolt). Also usable on any weapon to rack the action.
function WeaponState.Cycle(state, config)
	if state.Malfunction then
		return false
	end
	-- A live round in the chamber gets ejected and lost
	local _, _, _, feedRoll = rolls(state, 1)
	-- Manual actions are much less prone to feed issues (operator controls the stroke)
	feed(state, config, feedRoll * 4, nil)
	return true
end

function WeaponState.CanCycle(state, config): boolean
	return WeaponState.IsManual(config) and not state.Malfunction and state.Chamber ~= "Loaded"
end

-- Remedial action. Tap-rack for most, full strip/rack/reload for a double feed.
function WeaponState.ClearMalfunction(state, config)
	local malfunction = state.Malfunction
	state.Malfunction = nil
	state.BoltOpen = false
	-- Whatever was in the chamber (dud, case, stuck round - or a live round if the gun was fine) is gone
	state.Chamber = "Empty"
	feed(state, config, nil, nil)
	return malfunction
end

function WeaponState.ClearTime(state, config): number
	if state.Malfunction == "DoubleFeed" then
		return config.Times.ClearDoubleFeed
	end
	return config.Times.ClearMalfunction
end

--[[
	What kind of reload is possible right now:
	  "Tactical" magazine swap with a round still chambered
	  "Empty"    magazine swap + chamber a round (bolt release / charging handle)
	  "Insert"   tube-fed: push one shell
	  nil        nothing to do
]]
function WeaponState.ReloadKind(state, config): string?
	if state.Malfunction then
		return nil
	end
	if config.Feed == "Tube" then
		if state.Mag < config.MagazineCapacity and state.Reserve > 0 then
			return "Insert"
		end
		return nil
	end
	local best = 0
	for _, count in state.Reserve do
		best = math.max(best, count)
	end
	if best <= 0 then
		return nil
	end
	if state.Chamber == "Loaded" then
		if state.HasMag and state.Mag >= config.MagazineCapacity then
			return nil
		end
		return "Tactical"
	end
	if state.Chamber == "Spent" then
		-- Manual action with a fired case: swap the mag, the bolt cycle will handle the rest
		return "Tactical"
	end
	return "Empty"
end

function WeaponState.ReloadTime(config, kind: string): number
	if kind == "Empty" then
		return config.Times.ReloadEmpty
	elseif kind == "Insert" then
		return config.Times.ShellInsert
	end
	return config.Times.Reload
end

function WeaponState.ApplyReload(state, config, kind: string): boolean
	if WeaponState.ReloadKind(state, config) ~= kind then
		return false
	end
	if kind == "Insert" then
		state.Mag += 1
		state.Reserve -= 1
		return true
	end

	local bestIndex, bestCount = nil, 0
	for index, count in state.Reserve do
		if count > bestCount then
			bestIndex, bestCount = index, count
		end
	end
	if not bestIndex then
		return false
	end
	table.remove(state.Reserve, bestIndex)
	if state.HasMag and config.RetainMagazines and state.Mag > 0 then
		table.insert(state.Reserve, state.Mag)
	end
	state.Mag = bestCount
	state.HasMag = true

	if kind == "Empty" then
		state.Chamber = "Empty"
		feed(state, config, nil, nil)
	end
	return true
end

function WeaponState.NextFireMode(state, config): number
	return (state.FireMode % #config.FireModes) + 1
end

----------------------------------------------------------------------------------------------------
-- Network
----------------------------------------------------------------------------------------------------

local SYNC_FIELDS = { "Seed", "Shots", "Chamber", "Mag", "HasMag", "Malfunction", "BoltOpen", "Heat", "HeatTime", "Fouling", "FireMode" }

function WeaponState.Serialize(state)
	local data = {}
	for _, field in SYNC_FIELDS do
		data[field] = state[field]
	end
	data.Reserve = if type(state.Reserve) == "table" then table.clone(state.Reserve) else state.Reserve
	return data
end

function WeaponState.Apply(state, data)
	for _, field in SYNC_FIELDS do
		state[field] = data[field]
	end
	state.Reserve = if type(data.Reserve) == "table" then table.clone(data.Reserve) else data.Reserve
end

return WeaponState
