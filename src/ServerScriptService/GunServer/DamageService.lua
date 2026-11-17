--[[
	Applies damage. Hook into ServerStorage.GunSystemEvents.Damaged (BindableEvent) for kill feeds,
	stats, etc:  Damaged.Event:Connect(function(attacker, humanoid, damage, info) ... end)
	info = { WeaponId, Part, Position, Distance, Speed, Headshot }
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local GunSystem = game:GetService("ReplicatedStorage"):WaitForChild("GunSystem")
local Settings = require(GunSystem:WaitForChild("Settings"))

local DamageService = {}

local events = ServerStorage:FindFirstChild("GunSystemEvents")
if not events then
	events = Instance.new("Folder")
	events.Name = "GunSystemEvents"
	events.Parent = ServerStorage
end
local damaged = events:FindFirstChild("Damaged")
if not damaged then
	damaged = Instance.new("BindableEvent")
	damaged.Name = "Damaged"
	damaged.Parent = events
end
DamageService.Damaged = damaged

-- Override this from your own code if you need custom rules (game modes, safe zones...)
function DamageService.CanDamage(attacker: Player, humanoid: Humanoid): boolean
	if humanoid.Health <= 0 then
		return false
	end
	local victim = Players:GetPlayerFromCharacter(humanoid.Parent)
	if victim == attacker then
		return false
	end
	if victim and not Settings.Damage.FriendlyFire then
		if not attacker.Neutral and not victim.Neutral and attacker.Team == victim.Team then
			return false
		end
	end
	return true
end

function DamageService.Apply(attacker: Player, humanoid: Humanoid, damage: number, info): boolean
	if damage <= 0 or not DamageService.CanDamage(attacker, humanoid) then
		return false
	end

	-- Classic "creator" tag so existing leaderboards / kill credit scripts work
	local old = humanoid:FindFirstChild("creator")
	if old then
		old:Destroy()
	end
	local tag = Instance.new("ObjectValue")
	tag.Name = "creator"
	tag.Value = attacker
	tag.Parent = humanoid
	Debris:AddItem(tag, 3)

	humanoid:TakeDamage(damage)
	damaged:Fire(attacker, humanoid, damage, info)
	return true
end

return DamageService
