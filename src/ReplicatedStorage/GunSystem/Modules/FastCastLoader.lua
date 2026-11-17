--[[
	Finds FastCastRedux. Put the FastCastRedux ModuleScript (https://github.com/EtiTheSpirit/FastCastAPI)
	in ANY of these places:
	  ReplicatedStorage.FastCastRedux
	  ReplicatedStorage.Packages.FastCastRedux  (or .FastCast)
	  ReplicatedStorage.GunSystem.Vendor.FastCastRedux
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function find()
	local candidates = {
		ReplicatedStorage:FindFirstChild("FastCastRedux"),
		ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("FastCastRedux"),
		ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("FastCast"),
		script.Parent.Parent:FindFirstChild("Vendor") and script.Parent.Parent.Vendor:FindFirstChild("FastCastRedux"),
	}
	for _, candidate in candidates do
		if candidate and candidate:IsA("ModuleScript") then
			return candidate
		end
	end
	return nil
end

local module = find()
if not module then
	warn("[GunSystem] Waiting for FastCastRedux in ReplicatedStorage (see FastCastLoader for locations)...")
	module = ReplicatedStorage:WaitForChild("FastCastRedux")
end

local FastCast = require(module)
FastCast.VisualizeCasts = false
return FastCast
