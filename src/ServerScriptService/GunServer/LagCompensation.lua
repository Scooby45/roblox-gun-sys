--[[
	Keeps a short history of every player character's root CFrame so hits can be checked against
	where the target was when the shooter saw them, not where they are now on the server.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GunSystem = game:GetService("ReplicatedStorage"):WaitForChild("GunSystem")
local Settings = require(GunSystem:WaitForChild("Settings"))

local LagCompensation = {}

local SAMPLE_RATE = 1 / 30
local MAX_SAMPLES = math.ceil(Settings.Security.MaxRewind / SAMPLE_RATE) + 2

local history = {} -- [Model] = { Index, Times = {}, CFrames = {} }
local accumulator = 0

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < SAMPLE_RATE then
		return
	end
	accumulator = 0
	local now = Workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local record = history[character]
			if not record then
				record = { Index = 0, Times = table.create(MAX_SAMPLES, 0), CFrames = table.create(MAX_SAMPLES, root.CFrame) }
				history[character] = record
				character.Destroying:Connect(function()
					history[character] = nil
				end)
			end
			record.Index = record.Index % MAX_SAMPLES + 1
			record.Times[record.Index] = now
			record.CFrames[record.Index] = root.CFrame
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if player.Character then
		history[player.Character] = nil
	end
end)

local function insideExpandedBox(partCFrame: CFrame, size: Vector3, position: Vector3, tolerance: number): boolean
	local localPoint = partCFrame:PointToObjectSpace(position)
	return math.abs(localPoint.X) <= size.X * 0.5 + tolerance
		and math.abs(localPoint.Y) <= size.Y * 0.5 + tolerance
		and math.abs(localPoint.Z) <= size.Z * 0.5 + tolerance
end

--[[
	Was `position` on `part` (belonging to `character`) at any time in the rewind window?
]]
function LagCompensation.Check(character: Model, part: BasePart, position: Vector3): boolean
	local tolerance = Settings.Security.HitTolerance
	if insideExpandedBox(part.CFrame, part.Size, position, tolerance) then
		return true
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local record = history[character]
	if not root or not record then
		-- NPCs / no history: be a little more lenient with the current position only
		return insideExpandedBox(part.CFrame, part.Size, position, tolerance * 1.5)
	end

	local relative = root.CFrame:ToObjectSpace(part.CFrame)
	local oldest = Workspace:GetServerTimeNow() - Settings.Security.MaxRewind
	for i = 1, MAX_SAMPLES do
		if record.Times[i] >= oldest then
			if insideExpandedBox(record.CFrames[i] * relative, part.Size, position, tolerance) then
				return true
			end
		end
	end
	return false
end

return LagCompensation
