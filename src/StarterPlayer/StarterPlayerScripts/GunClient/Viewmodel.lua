--[[
	First person viewmodel.

	Your viewmodel Model needs:
	  * a PrimaryPart (e.g. "HumanoidRootPart" / "CameraBone"), anchored. It sits at the camera.
	  * an AnimationController (or Humanoid) with an Animator for the first person animations
	  * attachments anywhere inside (found by name):
	      Muzzle   - muzzle flash emitters / lights go in here, bullets start here
	      AimPoint - where your eye should be when aiming. Its LookVector must point down range.
	      Eject    - ejection port. RightVector = direction casings fly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GunSystem = ReplicatedStorage:WaitForChild("GunSystem")
local Spring = require(GunSystem:WaitForChild("Modules"):WaitForChild("Spring"))
local Util = require(GunSystem:WaitForChild("Modules"):WaitForChild("Util"))

local AnimationSet = require(script.Parent:WaitForChild("AnimationSet"))

local Viewmodel = {}
Viewmodel.__index = Viewmodel

function Viewmodel.new(template: Model, config)
	local model = template:Clone()
	local root = model.PrimaryPart
	if not root then
		warn(`[GunSystem] Viewmodel for {config.Id} has no PrimaryPart; first person viewmodel disabled.`)
		model:Destroy()
		return nil
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.Massless = true
		end
	end
	root.Anchored = true

	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		local controller = model:FindFirstChildOfClass("AnimationController") or model:FindFirstChildOfClass("Humanoid")
		if not controller then
			controller = Instance.new("AnimationController")
			controller.Parent = model
		end
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	local recoilConfig = config.Recoil.Viewmodel
	local self = setmetatable({
		Model = model,
		Root = root,
		Config = config,
		Muzzle = Util.FindDescendant(model, "Muzzle", "Attachment"),
		AimPoint = Util.FindDescendant(model, "AimPoint", "Attachment"),
		Eject = Util.FindDescendant(model, "Eject", "Attachment"),
		Animations = AnimationSet.new(animator, config, ""),
		Visible = false,

		KickPosition = Spring.new(recoilConfig.Stiffness, recoilConfig.Damping),
		KickRotation = Spring.new(recoilConfig.Stiffness, recoilConfig.Damping),
		Sway = Spring.new(120, 14),
		MoveSway = Spring.new(90, 12),
		Clock = 0,
	}, Viewmodel)

	model.Name = "Viewmodel"
	return self
end

function Viewmodel:SetVisible(visible: boolean)
	if visible == self.Visible then
		return
	end
	self.Visible = visible
	self.Model.Parent = if visible then Workspace.CurrentCamera else nil
end

function Viewmodel:Kick(aimAlpha: number, multiplier: number)
	local recoil = self.Config.Recoil.Viewmodel
	local scale = multiplier * (1 - aimAlpha * 0.35)
	local side = (math.random() - 0.5) * 2 * recoil.Side
	self.KickPosition:Impulse(Vector3.new(side, recoil.Kick * 0.15, recoil.Kick) * 60 * scale)
	self.KickRotation:Impulse(
		Vector3.new(
			math.rad(recoil.Rise) * (0.85 + math.random() * 0.3),
			math.rad(recoil.Rise) * (math.random() - 0.5) * 0.4,
			math.rad(recoil.Roll) * (math.random() - 0.5) * 2
		)
			* 60
			* scale
	)
end

--[[
	params = {
		AimAlpha, SprintAlpha (0..1), MoveSpeed (studs/s), Grounded (bool), Breath (0..1 extra sway)
	}
]]
function Viewmodel:Update(dt: number, cameraCFrame: CFrame, params)
	if not self.Visible then
		return
	end
	local config = self.Config
	local aim = params.AimAlpha
	local sprint = params.SprintAlpha
	self.Clock += dt

	-- Mouse sway: gun lags behind camera rotation
	local mouseDelta = UserInputService:GetMouseDelta()
	local swayAmount = config.Handling.Sway * (1 - aim * 0.75)
	self.Sway:Impulse(Vector3.new(mouseDelta.Y, mouseDelta.X, mouseDelta.X) * -0.012 * swayAmount)
	local sway = self.Sway:Update(dt)

	-- Movement bob
	local speed = params.MoveSpeed
	local bobScale = math.clamp(speed / 16, 0, 1.6) * (if params.Grounded then 1 else 0.2) * (1 - aim * 0.85)
	local frequency = 7 + sprint * 3
	local t = self.Clock * frequency
	local bob = Vector3.new(math.sin(t * 0.5) * 0.05, -math.abs(math.cos(t * 0.5)) * 0.04, 0) * bobScale * (1 + sprint)
	local bobRotation = CFrame.Angles(0, 0, math.sin(t * 0.5) * 0.015 * bobScale)

	-- Breathing (more visible when aimed)
	local breath = (0.25 + aim * 0.75) * (params.Breath or 1) * config.Handling.Sway
	local breathOffset = CFrame.Angles(math.sin(self.Clock * 1.1) * 0.0025 * breath, math.sin(self.Clock * 0.7) * 0.002 * breath, 0)

	-- Hip / aim offsets. Aim offset is measured from the current animated pose so sights line up
	local hip = config.Viewmodel.HipOffset
	local target = hip
	if aim > 0 and self.AimPoint then
		local relative = self.Root.CFrame:ToObjectSpace(self.AimPoint.WorldCFrame)
		local aimOffset = CFrame.new(0, 0, -config.Viewmodel.AimDistance) * relative:Inverse()
		target = hip:Lerp(aimOffset, aim)
	end
	if sprint > 0 then
		target = target:Lerp(hip * config.Viewmodel.SprintOffset, sprint)
	end

	-- Recoil springs
	local kickPosition = self.KickPosition:Update(dt)
	local kickRotation = self.KickRotation:Update(dt)

	self.Root.CFrame = cameraCFrame
		* breathOffset
		* CFrame.Angles(sway.X, sway.Y, sway.Z * 0.6)
		* CFrame.new(bob)
		* bobRotation
		* target
		* CFrame.new(kickPosition)
		* CFrame.Angles(kickRotation.X, kickRotation.Y, kickRotation.Z)
end

function Viewmodel:Destroy()
	self.Animations:Destroy()
	self.Model:Destroy()
end

return Viewmodel
