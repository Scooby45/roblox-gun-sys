--[[
	Other players' guns: shots (cosmetic bullets with the same seed), muzzle flashes, distance-delayed
	sounds, shell casings, reload/clear sounds and upper-body aim pitch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GunSystem = ReplicatedStorage:WaitForChild("GunSystem")
local Modules = GunSystem:WaitForChild("Modules")

local Registry = require(Modules:WaitForChild("Registry"))
local Ballistics = require(Modules:WaitForChild("Ballistics"))
local Remotes = require(Modules:WaitForChild("Remotes"))
local Util = require(Modules:WaitForChild("Util"))

local Assets = require(script.Parent:WaitForChild("Assets"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local Projectiles = require(script.Parent:WaitForChild("Projectiles"))

local LocalPlayer = Players.LocalPlayer

local Replication = {}

-- Gunshots are loud: beyond this distance use the "FireDistant" sound if the weapon has one
local DISTANT_SOUND_RANGE = 350

local function soundParent(tool: Instance?): Instance?
	return tool and tool:FindFirstChild("Handle")
end

Remotes.Replicate.OnClientEvent:Connect(
	function(shooter: Player, tool: Tool?, weaponId: string, origin: Vector3, aimDirection: Vector3, seed: number, spread: number)
		if shooter == LocalPlayer or type(weaponId) ~= "string" then
			return
		end
		-- The tool may be nil if it's streamed out; the bullets still fly
		local config = Registry.GetWeapon(weaponId)
		if not config then
			return
		end

		local directions = Ballistics.PelletDirections(aimDirection, seed, config.Pellets, spread, config.Spread.PelletSpread)
		Projectiles.Fire({
			Shooter = shooter,
			Character = shooter.Character,
			Config = config,
			Origin = origin,
			Directions = directions,
			Seed = seed,
			IsLocal = false,
		})

		local muzzle = tool and Util.FindDescendant(tool, "Muzzle", "Attachment")
		Effects.MuzzleFlash(muzzle)

		-- Sound arrives late over distance (speed of sound)
		local distance = Effects.DistanceToCamera(origin)
		local delay = Effects.SoundDelay(origin)
		local fire = Assets.WeaponSound(config.Id, "Fire")
		if distance > DISTANT_SOUND_RANGE then
			fire = Assets.WeaponSound(config.Id, "FireDistant") or fire
		end
		local parent = soundParent(tool)
		if parent then
			Effects.PlaySound(fire, parent, delay)
		else
			Effects.PlaySoundAt(fire, origin, delay)
		end

		if config.Action == "Gas" then
			local character = shooter.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			Effects.EjectShell(
				Assets.Shell(config.Id),
				tool and Util.FindDescendant(tool, "Eject", "Attachment"),
				root and root.AssemblyLinearVelocity
			)
		end
	end
)

Remotes.ActionFX.OnClientEvent:Connect(function(shooter: Player, tool: Tool?, soundName: string)
	if shooter == LocalPlayer or type(soundName) ~= "string" then
		return
	end
	local config = Registry.GetWeaponFromTool(tool)
	local handle = tool and tool:FindFirstChild("Handle")
	if not config or not handle then
		return
	end
	Effects.PlaySound(Assets.WeaponSound(config.Id, soundName), handle)
	if soundName == "Cycle" then
		task.delay(config.Times.Cycle * 0.45, function()
			Effects.EjectShell(Assets.Shell(config.Id), Util.FindDescendant(tool, "Eject", "Attachment"))
		end)
	end
end)

----------------------------------------------------------------------------------------------------
-- Upper body pitch of other players (R15 waist)
----------------------------------------------------------------------------------------------------

local looks = {} -- [Player] = { Target, Current, Waist, C0 }

Remotes.Look.OnClientEvent:Connect(function(shooter: Player, pitch: number)
	if shooter == LocalPlayer then
		return
	end
	local entry = looks[shooter]
	local character = shooter.Character
	local waist = character and character:FindFirstChild("UpperTorso") and character.UpperTorso:FindFirstChild("Waist")
	if not waist then
		return
	end
	if not entry or entry.Waist ~= waist then
		entry = { Target = pitch, Current = 0, Waist = waist, C0 = waist.C0 }
		looks[shooter] = entry
	end
	entry.Target = pitch
end)

RunService.RenderStepped:Connect(function(dt)
	local alpha = 1 - math.exp(-dt * 12)
	for player, entry in looks do
		local waist = entry.Waist
		if not waist.Parent or not player.Parent then
			looks[player] = nil
			continue
		end
		-- Only aim the torso while a gun is held
		local character = player.Character
		local holding = character and character:FindFirstChildOfClass("Tool")
		local target = if holding and holding:GetAttribute("WeaponId") then entry.Target else 0
		entry.Current += (target - entry.Current) * alpha
		waist.C0 = entry.C0 * CFrame.Angles(entry.Current * 0.6, 0, 0)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	looks[player] = nil
end)

return Replication
