--[[
	Camera side of the gun system:
	  * recoil: part of every kick is permanent (you must pull down), the rest springs back
	  * shake, FOV zoom when aiming
	  * over-the-shoulder offset, mouse lock and character facing in third person
	  * first/third person detection and "aim into first person" mode

	Runs after Roblox's camera scripts (RenderPriority.Camera + 1) and applies rotation deltas,
	so it composes with the default camera instead of replacing it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GunSystem = ReplicatedStorage:WaitForChild("GunSystem")
local Settings = require(GunSystem:WaitForChild("Settings"))
local Spring = require(GunSystem:WaitForChild("Modules"):WaitForChild("Spring"))

local LocalPlayer = Players.LocalPlayer
local CameraSettings = Settings.Camera

local CameraController = {
	Equipped = false,
	AimAlpha = 0, -- 0 hip .. 1 fully aimed (driven by the weapon controller)
	AimFOV = CameraSettings.FieldOfView,
	FirstPerson = false,
	ShoulderSide = 1,
}

local recoil = Spring.new(160, 17) -- X pitch, Y yaw, Z roll (radians)
local shake = Spring.new(400, 18)
local lastRecoil = Vector3.zero
local pendingPermanent = Vector2.zero -- pitch, yaw still to be applied smoothly
local shoulderOffset = Vector3.zero
local forcedFirstPerson = false
local savedZoom = nil
local baseFOV = CameraSettings.FieldOfView

local function getCharacter()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, head, root
end

function CameraController.IsFirstPerson(): boolean
	local _, _, head = getCharacter()
	if not head then
		return false
	end
	local camera = Workspace.CurrentCamera
	return (camera.CFrame.Position - head.Position).Magnitude < CameraSettings.FirstPersonThreshold
end

--[[
	pitch/yaw in degrees (positive pitch = up, positive yaw = right).
	recovery: fraction of the kick the camera returns on its own (0..1).
]]
function CameraController.Kick(pitch: number, yaw: number, roll: number, recovery: number, springConfig)
	if springConfig then
		recoil.Stiffness = springConfig.Stiffness
		recoil.Damping = springConfig.Damping
	end
	local pitchRad, yawRad = math.rad(pitch), -math.rad(yaw)
	-- Permanent part (muzzle climb you have to fight)
	pendingPermanent += Vector2.new(pitchRad, yawRad) * (1 - recovery)
	-- Recoverable part: an impulse whose peak roughly equals the requested angle
	local omega = math.sqrt(recoil.Stiffness / recoil.Mass)
	recoil:Impulse(Vector3.new(pitchRad * recovery, yawRad * recovery, math.rad(roll)) * omega * math.exp(1))
end

function CameraController.Shake(intensity: number)
	if intensity <= 0 then
		return
	end
	shake:Impulse(Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * intensity * 2)
end

function CameraController.Reset()
	recoil:Reset()
	shake:Reset()
	lastRecoil = Vector3.zero
	pendingPermanent = Vector2.zero
end

local function setForcedFirstPerson(enabled: boolean)
	if enabled == forcedFirstPerson then
		return
	end
	forcedFirstPerson = enabled
	local camera = Workspace.CurrentCamera
	if enabled then
		savedZoom = (camera.CFrame.Position - camera.Focus.Position).Magnitude
		LocalPlayer.CameraMaxZoomDistance = 0.5
		LocalPlayer.CameraMinZoomDistance = 0.5
	else
		local minZoom = game:GetService("StarterPlayer").CameraMinZoomDistance
		local maxZoom = game:GetService("StarterPlayer").CameraMaxZoomDistance
		LocalPlayer.CameraMaxZoomDistance = maxZoom
		LocalPlayer.CameraMinZoomDistance = math.clamp(savedZoom or minZoom, minZoom, maxZoom)
		task.delay(0.1, function()
			if not forcedFirstPerson then
				LocalPlayer.CameraMinZoomDistance = minZoom
			end
		end)
	end
end

if CameraSettings.ShoulderSwitchKey then
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == CameraSettings.ShoulderSwitchKey and CameraController.Equipped then
			CameraController.ShoulderSide = -CameraController.ShoulderSide
		end
	end)
end

RunService:BindToRenderStep("GunSystemCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera = Workspace.CurrentCamera
	local _, humanoid, _, root = getCharacter()
	local equipped = CameraController.Equipped

	-- Recoil (deltas, so the default camera keeps the permanent part)
	local offset = recoil:Update(dt)
	local delta = offset - lastRecoil
	lastRecoil = offset
	local apply = 1 - math.exp(-dt * 30)
	local permanentStep = pendingPermanent * apply
	pendingPermanent -= permanentStep
	local shakeOffset = shake:Update(dt)

	camera.CFrame = camera.CFrame
		* CFrame.Angles(delta.X + permanentStep.X, delta.Y + permanentStep.Y, 0)
		* CFrame.Angles(shakeOffset.X * 0.02, shakeOffset.Y * 0.02, offset.Z + shakeOffset.Z * 0.03)

	-- First person forcing when aiming (optional mode)
	local wantForced = equipped and CameraSettings.ThirdPersonAimMode == "FirstPerson" and CameraController.AimAlpha > 0.05
	setForcedFirstPerson(wantForced)

	CameraController.FirstPerson = CameraController.IsFirstPerson()

	-- FOV
	local targetFOV = baseFOV
	if equipped then
		local aimFOV = CameraController.AimFOV
		if not CameraController.FirstPerson then
			aimFOV = math.max(aimFOV, baseFOV * CameraSettings.ThirdPersonAimFOVMultiplier)
		end
		targetFOV = baseFOV + (aimFOV - baseFOV) * CameraController.AimAlpha
	end
	camera.FieldOfView += (targetFOV - camera.FieldOfView) * (1 - math.exp(-dt * 18))

	if not humanoid or not root then
		return
	end

	-- Shoulder camera
	local targetShoulder = Vector3.zero
	if equipped and not CameraController.FirstPerson then
		local base = CameraSettings.ShoulderOffset
		targetShoulder = Vector3.new(base.X * CameraController.ShoulderSide, base.Y, base.Z)
	end
	shoulderOffset = shoulderOffset:Lerp(targetShoulder, 1 - math.exp(-dt * 12))
	if equipped or shoulderOffset.Magnitude > 0.01 then
		humanoid.CameraOffset = shoulderOffset
	end

	-- Face the camera direction and lock the mouse (shift-lock style) in third person
	if equipped and CameraSettings.LockMouseInThirdPerson then
		humanoid.AutoRotate = false
		if not CameraController.FirstPerson then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
		if humanoid.Sit == false and humanoid.PlatformStand == false then
			local look = camera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 1e-3 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
			end
		end
	end
end)

function CameraController.SetEquipped(equipped: boolean)
	CameraController.Equipped = equipped
	if not equipped then
		CameraController.AimAlpha = 0
		setForcedFirstPerson(false)
		local _, humanoid = getCharacter()
		if humanoid then
			humanoid.AutoRotate = true
			humanoid.CameraOffset = Vector3.zero
		end
		shoulderOffset = Vector3.zero
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter and not CameraController.IsFirstPerson() then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end
end

return CameraController
