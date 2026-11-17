--[[
	Client-side visual/audio effects. Everything is pooled to avoid instance churn:
	tracers, bullet holes, impact emitters, shell casings and sounds.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GunSystem = ReplicatedStorage:WaitForChild("GunSystem")
local Settings = require(GunSystem:WaitForChild("Settings"))
local Assets = require(script.Parent:WaitForChild("Assets"))

local FXSettings = Settings.Effects
local HIDDEN = CFrame.new(0, -1e5, 0)
local SPEED_OF_SOUND = 343 * Settings.StudsPerMeter

local Effects = {}

local folder = Instance.new("Folder")
folder.Name = "GunSystemFX"
folder.Parent = Workspace
Effects.Folder = folder

local function camera(): Camera
	return Workspace.CurrentCamera
end

local function distanceToCamera(position: Vector3): number
	return (camera().CFrame.Position - position).Magnitude
end
Effects.DistanceToCamera = distanceToCamera

local function makeInert(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
end

----------------------------------------------------------------------------------------------------
-- Sounds
----------------------------------------------------------------------------------------------------

local soundPools = setmetatable({}, { __mode = "k" }) -- [parent] = { [template] = { list, index } }

function Effects.PlaySound(template: Sound?, parent: Instance?, delay: number?, volumeScale: number?)
	if not template or not parent or not parent.Parent then
		return
	end
	local byParent = soundPools[parent]
	if not byParent then
		byParent = {}
		soundPools[parent] = byParent
	end
	local pool = byParent[template]
	if not pool then
		pool = { List = {}, Index = 0 }
		byParent[template] = pool
	end
	pool.Index = pool.Index % FXSettings.SoundPoolPerWeapon + 1
	local sound = pool.List[pool.Index]
	if not sound or not sound.Parent then
		sound = template:Clone()
		sound.Parent = parent
		pool.List[pool.Index] = sound
	end
	sound.Volume = template.Volume * (volumeScale or 1)
	sound.PlaybackSpeed = template.PlaybackSpeed * (0.96 + math.random() * 0.08)
	if delay and delay > 0.01 then
		task.delay(delay, function()
			if sound.Parent then
				sound.TimePosition = 0
				sound:Play()
			end
		end)
	else
		sound.TimePosition = 0
		sound:Play()
	end
	return sound
end

-- A one-off sound at a world position (impacts, cracks)
local soundAnchors = {}
local soundAnchorIndex = 0
local function soundAnchor(position: Vector3): Attachment
	soundAnchorIndex = soundAnchorIndex % 24 + 1
	local attachment = soundAnchors[soundAnchorIndex]
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "GunSoundAnchor"
		attachment.Parent = Workspace.Terrain
		soundAnchors[soundAnchorIndex] = attachment
	end
	attachment.WorldPosition = position
	return attachment
end

function Effects.PlaySoundAt(template: Sound?, position: Vector3, delay: number?)
	if not template then
		return
	end
	local sound = template:Clone()
	sound.Parent = soundAnchor(position)
	sound.PlaybackSpeed = template.PlaybackSpeed * (0.93 + math.random() * 0.14)
	if delay and delay > 0.01 then
		task.delay(delay, function()
			if sound.Parent then
				sound:Play()
			end
		end)
	else
		sound:Play()
	end
	Debris:AddItem(sound, (delay or 0) + math.max(sound.TimeLength, 2) + 0.5)
end

-- Delay for a sound travelling from `position` to the listener
function Effects.SoundDelay(position: Vector3): number
	return distanceToCamera(position) / SPEED_OF_SOUND
end

----------------------------------------------------------------------------------------------------
-- Muzzle
----------------------------------------------------------------------------------------------------

-- Emits every ParticleEmitter in the muzzle attachment and flashes its lights.
-- Emitters should be Enabled = false; set an "EmitCount" attribute to control particle count.
function Effects.MuzzleFlash(muzzle: Attachment?)
	if not muzzle then
		return
	end
	for _, child in muzzle:GetChildren() do
		if child:IsA("ParticleEmitter") then
			child:Emit(child:GetAttribute("EmitCount") or 1)
		elseif child:IsA("Light") then
			child.Enabled = true
			task.delay(FXSettings.MuzzleLightTime, function()
				child.Enabled = false
			end)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Tracers
----------------------------------------------------------------------------------------------------

local tracerPool = {}

local function newTracer(): BasePart
	local template = Assets.Tracer()
	local part
	if template then
		part = template:Clone()
	else
		part = Instance.new("Part")
		part.Material = Enum.Material.Neon
		part.Shape = Enum.PartType.Block
	end
	makeInert(part)
	part.Name = "Tracer"
	part.CFrame = HIDDEN
	part.Parent = folder
	return part
end

for _ = 1, FXSettings.TracerPoolSize do
	table.insert(tracerPool, newTracer())
end

function Effects.AcquireTracer(color: Color3): BasePart?
	local part = table.remove(tracerPool)
	if not part then
		return nil -- pool exhausted, skip the tracer rather than allocate
	end
	if not Assets.Tracer() then
		part.Color = color
	end
	part.Transparency = 0
	return part
end

function Effects.UpdateTracer(part: BasePart, position: Vector3, velocity: Vector3)
	local speed = velocity.Magnitude
	if speed < 1 then
		return
	end
	local length = math.clamp(FXSettings.TracerLength * speed / 3000, 0.5, FXSettings.TracerLength)
	-- Shrink the tracer as it gets far away less than linearly so it stays visible
	local width = FXSettings.TracerWidth * math.clamp(distanceToCamera(position) / 60, 1, 6)
	part.Size = Vector3.new(width, width, length)
	part.CFrame = CFrame.lookAt(position - velocity / speed * (length * 0.5), position)
end

function Effects.ReleaseTracer(part: BasePart)
	part.CFrame = HIDDEN
	table.insert(tracerPool, part)
end

----------------------------------------------------------------------------------------------------
-- Impacts
----------------------------------------------------------------------------------------------------

local impactPools = {} -- [Folder] = { Attachments, Index }
local IMPACT_POOL_SIZE = 6

local function impactAttachment(effect: Instance): Attachment
	local pool = impactPools[effect]
	if not pool then
		pool = { List = {}, Index = 0 }
		impactPools[effect] = pool
	end
	pool.Index = pool.Index % IMPACT_POOL_SIZE + 1
	local attachment = pool.List[pool.Index]
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "Impact_" .. effect.Name
		for _, child in effect:GetChildren() do
			if child:IsA("ParticleEmitter") or child:IsA("Sound") or child:IsA("Light") then
				local clone = child:Clone()
				if clone:IsA("ParticleEmitter") then
					clone.Enabled = false
				elseif clone:IsA("Light") then
					clone.Enabled = false
				end
				clone.Parent = attachment
			end
		end
		attachment.Parent = Workspace.Terrain
		pool.List[pool.Index] = attachment
	end
	return attachment
end

-- Bullet holes
local holes = {}
local holeIndex = 0

local function placeHole(decal: Decal, position: Vector3, normal: Vector3, hitPart: Instance)
	holeIndex = holeIndex % FXSettings.MaxBulletHoles + 1
	local hole = holes[holeIndex]
	if not hole then
		hole = Instance.new("Part")
		makeInert(hole)
		hole.Transparency = 1
		hole.Name = "BulletHole"
		hole.Parent = folder
		holes[holeIndex] = { Part = hole, Decal = nil, Weld = nil, Time = 0 }
		hole = holes[holeIndex]
	end
	if hole.Weld then
		hole.Weld:Destroy()
		hole.Weld = nil
	end
	if not hole.Decal or hole.Decal.Texture ~= decal.Texture then
		if hole.Decal then
			hole.Decal:Destroy()
		end
		hole.Decal = decal:Clone()
		hole.Decal.Face = Enum.NormalId.Front
		hole.Decal.Parent = hole.Part
	end
	hole.Decal.Transparency = decal.Transparency
	local size = FXSettings.BulletHoleSize * (0.85 + math.random() * 0.3)
	local part = hole.Part
	part.Size = Vector3.new(size, size, 0.02)
	local cf = CFrame.lookAt(position + normal * 0.01, position + normal) * CFrame.Angles(0, 0, math.random() * math.pi * 2)
	part.Anchored = true
	part.CFrame = cf
	if hitPart:IsA("BasePart") and not hitPart.Anchored then
		-- Stick to moving objects
		part.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = hitPart
		weld.Parent = part
		hole.Weld = weld
	end
	hole.Time = os.clock()
end

-- Fade/hide holes past their lifetime
task.spawn(function()
	while true do
		task.wait(1)
		local cutoff = os.clock() - FXSettings.BulletHoleLifetime
		for _, hole in holes do
			if hole.Time > 0 and hole.Time < cutoff then
				hole.Time = 0
				if hole.Weld then
					hole.Weld:Destroy()
					hole.Weld = nil
				end
				hole.Part.Anchored = true
				hole.Part.CFrame = HIDDEN
			end
		end
	end
end)

--[[
	position/normal: where and which way the surface faces.
	profile: material profile (Materials.Profiles entry)
	isExit: exit wound / exit hole on the back of a penetrated object
]]
function Effects.Impact(position: Vector3, normal: Vector3, profile, hitPart: Instance, isExit: boolean?)
	if not profile or not profile.Effect then
		return
	end
	if distanceToCamera(position) > FXSettings.ImpactMaxDistance then
		return
	end
	local effect = Assets.Impact(profile.Effect)
	if not effect then
		return
	end

	local attachment = impactAttachment(effect)
	attachment.WorldCFrame = CFrame.lookAt(position, position + normal)
	for _, child in attachment:GetChildren() do
		if child:IsA("ParticleEmitter") then
			local count = child:GetAttribute("EmitCount") or 6
			child:Emit(if isExit then math.ceil(count * 0.6) else count)
		elseif child:IsA("Sound") and not isExit then
			child.PlaybackSpeed = 0.9 + math.random() * 0.2
			child.TimePosition = 0
			child:Play()
		elseif child:IsA("Light") then
			child.Enabled = true
			task.delay(0.05, function()
				child.Enabled = false
			end)
		end
	end

	local decal = effect:FindFirstChild("Hole")
	if decal and decal:IsA("Decal") and profile ~= nil and profile.Effect ~= "Flesh" and profile.Effect ~= "Water" then
		placeHole(decal, position, normal, hitPart)
	end
end

----------------------------------------------------------------------------------------------------
-- Shell casings
----------------------------------------------------------------------------------------------------

local shells = {}
local shellIndex = 0

function Effects.EjectShell(template: BasePart?, eject: Attachment?, inheritVelocity: Vector3?)
	if not template or not eject then
		return
	end
	local position = eject.WorldPosition
	if distanceToCamera(position) > FXSettings.ShellMaxDistance then
		return
	end
	shellIndex = shellIndex % FXSettings.MaxShells + 1
	local entry = shells[shellIndex]
	if not entry or entry.Template ~= template then
		if entry then
			entry.Part:Destroy()
		end
		local part = template:Clone()
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Parent = folder
		entry = { Part = part, Template = template, Token = 0 }
		shells[shellIndex] = entry
	end
	entry.Token += 1
	local token = entry.Token
	local part = entry.Part
	local frame = eject.WorldCFrame
	part.Anchored = false
	part.CanCollide = true
	part.CFrame = frame
	-- Out to the right (attachment's right vector), a bit up and back
	part.AssemblyLinearVelocity = (inheritVelocity or Vector3.zero)
		+ frame.RightVector * (10 + math.random() * 6)
		+ frame.UpVector * (5 + math.random() * 4)
		- frame.LookVector * (math.random() * 2)
	part.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 40

	local landing = template:FindFirstChildOfClass("Sound")
	task.delay(FXSettings.ShellLifetime, function()
		if entry.Token == token then
			part.Anchored = true
			part.CanCollide = false
			part.CFrame = HIDDEN
		end
	end)
	if landing then
		task.delay(0.35 + math.random() * 0.2, function()
			if entry.Token == token then
				Effects.PlaySoundAt(landing, part.Position)
			end
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- Bullet flyby
----------------------------------------------------------------------------------------------------

function Effects.Flyby(position: Vector3, speed: number)
	local supersonic = speed > SPEED_OF_SOUND * 1.05
	local sound = Assets.GlobalSound(if supersonic then "Crack" else "Whizz") or Assets.GlobalSound("Whizz")
	Effects.PlaySoundAt(sound, position)
end

----------------------------------------------------------------------------------------------------
-- Hiding the local character's tool in first person
----------------------------------------------------------------------------------------------------

function Effects.SetLocalTransparency(instances: { BasePart }, value: number)
	for _, part in instances do
		part.LocalTransparencyModifier = value
	end
end

function Effects.LocalPlayer()
	return Players.LocalPlayer
end

return Effects
