--[[
	Gun system client bootstrap. Creates a WeaponController whenever the local character equips a
	Tool that has a "WeaponId" attribute matching a config in GunSystem/Config/Weapons.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunSystem = ReplicatedStorage:WaitForChild("GunSystem")
local Modules = GunSystem:WaitForChild("Modules")

local Registry = require(Modules:WaitForChild("Registry"))
local Remotes = require(Modules:WaitForChild("Remotes"))

local WeaponController = require(script:WaitForChild("WeaponController"))
local HUD = require(script:WaitForChild("HUD"))
local Projectiles = require(script:WaitForChild("Projectiles"))
require(script:WaitForChild("Replication"))

local LocalPlayer = Players.LocalPlayer

local controllers = {} -- [Tool] = WeaponController

local function onToolEquipped(tool: Tool)
	local config = Registry.GetWeaponFromTool(tool)
	if not config or controllers[tool] then
		return
	end
	local controller = WeaponController.new(tool, config)
	if controller then
		controllers[tool] = controller
	end
end

local function onToolUnequipped(tool: Tool)
	local controller = controllers[tool]
	if controller then
		controllers[tool] = nil
		controller:Destroy()
	end
end

local function onCharacter(character: Model)
	for tool, controller in controllers do
		controller:Destroy()
		controllers[tool] = nil
	end
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			onToolEquipped(child)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			onToolUnequipped(child)
		end
	end)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			onToolEquipped(child)
		end
	end
end

if LocalPlayer.Character then
	onCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacter)

-- Authoritative state from the server
Remotes.State.OnClientEvent:Connect(function(tool: Tool, data)
	local controller = controllers[tool]
	if controller and type(data) == "table" then
		controller:ApplyServerState(data)
	end
end)

Remotes.HitConfirm.OnClientEvent:Connect(function(killed: boolean, headshot: boolean)
	HUD.Hitmarker(killed, headshot)
end)

-- Hook point for instant (unconfirmed) local hit feedback, e.g. blood screen effects
Projectiles.OnLocalHit = nil
