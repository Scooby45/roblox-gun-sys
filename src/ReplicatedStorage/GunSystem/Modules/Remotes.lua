--[[
	Creates (server) or waits for (client) every remote the gun system uses.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Settings = require(script.Parent.Parent:WaitForChild("Settings"))

local DEFINITIONS = {
	Fire = "RemoteEvent", -- client -> server: a shot was fired
	Hit = "RemoteEvent", -- client -> server: batched humanoid hits
	Action = "RemoteEvent", -- client -> server: equip / reload / clear / cycle / fire mode
	State = "RemoteEvent", -- server -> client: authoritative weapon state
	Replicate = "UnreliableRemoteEvent", -- server -> clients: someone else's shot (cosmetic)
	ActionFX = "UnreliableRemoteEvent", -- server -> clients: someone else's reload/clear sounds
	Look = "UnreliableRemoteEvent", -- both ways: upper body aim pitch
	HitConfirm = "UnreliableRemoteEvent", -- server -> client: damage was applied (hitmarker)
}

local Remotes = {}

if RunService:IsServer() then
	local folder = ReplicatedStorage:FindFirstChild(Settings.RemotesFolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Settings.RemotesFolderName
		folder.Parent = ReplicatedStorage
	end
	for name, className in DEFINITIONS do
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
		Remotes[name] = remote
	end
else
	local folder = ReplicatedStorage:WaitForChild(Settings.RemotesFolderName)
	for name in DEFINITIONS do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
