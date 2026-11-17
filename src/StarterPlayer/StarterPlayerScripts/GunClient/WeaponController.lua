--[[
	Drives one equipped gun on the local client: input, firing, recoil, spread, reloads,
	malfunctions, manual actions, first/third person presentation.

	The mechanical state is predicted locally with WeaponState (same seeded RNG as the server) and
	corrected whenever the server sends its authoritative state.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GunSystem = ReplicatedStorage:WaitForChild("GunSystem")
local Modules = GunSystem:WaitForChild("Modules")

local Settings = require(GunSystem:WaitForChild("Settings"))
local WeaponState = require(Modules:WaitForChild("WeaponState"))
local Ballistics = require(Modules:WaitForChild("Ballistics"))
local Remotes = require(Modules:WaitForChild("Remotes"))
local Util = require(Modules:WaitForChild("Util"))

local Assets = require(script.Parent:WaitForChild("Assets"))
local AnimationSet = require(script.Parent:WaitForChild("AnimationSet"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local HUD = require(script.Parent:WaitForChild("HUD"))
local Projectiles = require(script.Parent:WaitForChild("Projectiles"))
local Viewmodel = require(script.Parent:WaitForChild("Viewmodel"))

local LocalPlayer = Players.LocalPlayer
local Keybinds = Settings.Keybinds

local ACTION_PREFIX = "GunSystem_"
local rng = Random.new()
local renderCounter = 0

local WeaponController = {}
WeaponController.__index = WeaponController

local function now(): number
	return Workspace:GetServerTimeNow()
end

function WeaponController.new(tool: Tool, config)
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

	local self = setmetatable({
		Tool = tool,
		Config = config,
		Character = character,
		Humanoid = humanoid,
		Root = character:FindFirstChild("HumanoidRootPart"),
		Head = character:FindFirstChild("Head"),
		State = nil, -- set when the server answers
		ShotId = 0,

		TriggerHeld = false,
		TriggerConsumed = false,
		BurstRemaining = 0,
		NextShot = 0,
		LastShot = 0,
		Bloom = 0,

		AimHeld = false,
		AimAlpha = 0,
		SprintHeld = false,
		SprintAlpha = 0,
		SprintEnded = 0,

		Busy = nil, -- name of the action in progress
		BusyToken = 0,
		ReloadInterrupt = false,
		NeedsCycle = false,

		FirstPerson = false,
		BaseWalkSpeed = humanoid.WalkSpeed,
		LastPitchSent = 0,
		PitchSendTime = 0,
		Status = nil,
		StatusUntil = 0,

		ToolMuzzle = Util.FindDescendant(tool, "Muzzle", "Attachment"),
		ToolEject = Util.FindDescendant(tool, "Eject", "Attachment"),
		ToolParts = {},
		Connections = {},
		Destroyed = false,
	}, WeaponController)

	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(self.ToolParts, descendant)
		end
	end

	self.ThirdPerson = AnimationSet.new(animator, config, "TP_")
	local template = Assets.Viewmodel(config.Id)
	if template then
		self.Viewmodel = Viewmodel.new(template, config)
	end

	-- Upper body aim (R15)
	local upperTorso = character:FindFirstChild("UpperTorso")
	self.Waist = upperTorso and upperTorso:FindFirstChild("Waist")
	self.WaistC0 = self.Waist and self.Waist.C0

	-- Sounds play from the gun in the world (also heard in first person)
	self.SoundParent = tool:FindFirstChild("Handle") or tool

	self:BindInput()
	CameraController.SetEquipped(true)
	CameraController.AimFOV = config.Handling.AimFOV
	HUD.SetVisible(true)

	-- After the camera (and its recoil) so the viewmodel never lags a frame behind
	renderCounter += 1
	self.RenderName = "GunSystemWeapon_" .. renderCounter
	RunService:BindToRenderStep(self.RenderName, Enum.RenderPriority.Camera.Value + 2, function(dt)
		self:Render(dt)
	end)
	table.insert(
		self.Connections,
		humanoid.Died:Connect(function()
			self:Destroy()
		end)
	)

	-- Equip
	self:SetBusy("Equip", config.Times.Equip)
	self:PlayAnimation("Equip", config.Times.Equip)
	self:PlayLoop("Idle")
	self:PlaySound("Equip")
	Remotes.Action:FireServer(tool, "Equip")
	-- The server may not have seen the tool in our hand yet: ask again until it answers
	task.spawn(function()
		for _ = 1, 10 do
			task.wait(0.75)
			if self.Destroyed or self.State then
				return
			end
			Remotes.Action:FireServer(tool, "Equip")
		end
	end)
	return self
end

----------------------------------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------------------------------

function WeaponController:PlayAnimation(name: string, duration: number?)
	if self.Viewmodel then
		self.Viewmodel.Animations:Play(name, duration)
	end
	self.ThirdPerson:Play(name, duration)
end

function WeaponController:PlayLoop(name: string)
	if self.Viewmodel then
		self.Viewmodel.Animations:Play(name, nil, 0.2)
	end
	self.ThirdPerson:Play(name, nil, 0.2)
end

function WeaponController:StopAnimation(name: string)
	if self.Viewmodel then
		self.Viewmodel.Animations:Stop(name)
	end
	self.ThirdPerson:Stop(name)
end

function WeaponController:PlaySound(name: string)
	Effects.PlaySound(Assets.WeaponSound(self.Config.Id, name), self.SoundParent)
end

function WeaponController:Muzzle(): Attachment?
	if self.FirstPerson and self.Viewmodel and self.Viewmodel.Muzzle then
		return self.Viewmodel.Muzzle
	end
	return self.ToolMuzzle
end

function WeaponController:Eject(): Attachment?
	if self.FirstPerson and self.Viewmodel and self.Viewmodel.Eject then
		return self.Viewmodel.Eject
	end
	return self.ToolEject
end

function WeaponController:EjectShell()
	local velocity = self.Root and self.Root.AssemblyLinearVelocity or Vector3.zero
	Effects.EjectShell(Assets.Shell(self.Config.Id), self:Eject(), velocity)
end

function WeaponController:SetStatus(text: string?, duration: number?)
	self.Status = text
	self.StatusUntil = os.clock() + (duration or 1.5)
end

-- Marks the weapon busy for `duration`; returns a token that is invalidated by Destroy/new actions
function WeaponController:SetBusy(name: string, duration: number?)
	self.BusyToken += 1
	local token = self.BusyToken
	self.Busy = name
	if duration then
		task.delay(duration, function()
			if self.BusyToken == token and not self.Destroyed then
				self.Busy = nil
			end
		end)
	end
	return token
end

function WeaponController:IsCurrent(token: number): boolean
	return not self.Destroyed and self.BusyToken == token
end

function WeaponController:EndBusy(token: number)
	if self.BusyToken == token then
		self.Busy = nil
	end
end

----------------------------------------------------------------------------------------------------
-- Server state
----------------------------------------------------------------------------------------------------

function WeaponController:ApplyServerState(data)
	local hadMalfunction = self.State and self.State.Malfunction
	if not self.State then
		self.State = WeaponState.new(self.Config, data.Seed)
	end
	WeaponState.Apply(self.State, data)
	if self.State.Malfunction and not hadMalfunction then
		self:OnMalfunction()
	end
	-- Manual action that needs working (e.g. after a correction)
	self.NeedsCycle = WeaponState.IsManual(self.Config) and self.State.Chamber == "Spent"
end

function WeaponController:OnMalfunction()
	self.TriggerHeld = false
	self.BurstRemaining = 0
	self:PlaySound("Malfunction")
end

----------------------------------------------------------------------------------------------------
-- Input
----------------------------------------------------------------------------------------------------

function WeaponController:BindInput()
	local function bind(name, inputs, handler, touchButton)
		ContextActionService:BindActionAtPriority(ACTION_PREFIX .. name, function(_, inputState, input)
			if self.Destroyed then
				return Enum.ContextActionResult.Pass
			end
			return handler(inputState, input) or Enum.ContextActionResult.Sink
		end, touchButton or false, Enum.ContextActionPriority.High.Value, table.unpack(inputs))
		if touchButton then
			ContextActionService:SetTitle(ACTION_PREFIX .. name, name)
		end
	end

	bind("Fire", Keybinds.Fire, function(inputState)
		if inputState == Enum.UserInputState.Begin then
			self:TriggerDown()
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			self:TriggerUp()
		end
	end, true)

	bind("Aim", Keybinds.Aim, function(inputState)
		self.AimHeld = inputState == Enum.UserInputState.Begin
	end, true)

	bind("Reload", Keybinds.Reload, function(inputState)
		if inputState == Enum.UserInputState.Begin then
			self:Reload()
		end
	end, true)

	bind("Clear", Keybinds.ClearMalfunction, function(inputState)
		if inputState == Enum.UserInputState.Begin then
			self:ClearMalfunction()
		end
	end, true)

	bind("FireMode", Keybinds.FireMode, function(inputState)
		if inputState == Enum.UserInputState.Begin then
			self:SwitchFireMode()
		end
	end)

	bind("CheckAmmo", Keybinds.CheckAmmo, function(inputState)
		if inputState == Enum.UserInputState.Begin then
			self:CheckAmmo()
		end
	end)

	if Settings.Movement.SprintEnabled then
		bind("Sprint", Keybinds.Sprint, function(inputState)
			self.SprintHeld = inputState == Enum.UserInputState.Begin
			return Enum.ContextActionResult.Pass
		end)
	end
end

function WeaponController:UnbindInput()
	for _, name in { "Fire", "Aim", "Reload", "Clear", "FireMode", "CheckAmmo", "Sprint" } do
		ContextActionService:UnbindAction(ACTION_PREFIX .. name)
	end
end

----------------------------------------------------------------------------------------------------
-- Trigger / firing
----------------------------------------------------------------------------------------------------

function WeaponController:TriggerDown()
	self.TriggerHeld = true
	self.TriggerConsumed = false
	if self.Busy == "Reload" and self.Config.Feed == "Tube" then
		-- Stop loading shells after the current one
		self.ReloadInterrupt = true
	end
	if WeaponState.FireModeName(self.State or { FireMode = 1 }, self.Config) == "Burst" then
		self.BurstRemaining = self.Config.BurstCount
	end
end

function WeaponController:TriggerUp()
	self.TriggerHeld = false
	-- Burst triggers stop when released, like real burst groups
	self.BurstRemaining = 0
	if self.NeedsCycle then
		self:Cycle()
	end
end

function WeaponController:CanFire(): boolean
	if not self.State or self.Busy or self.Humanoid.Health <= 0 then
		return false
	end
	if self.SprintAlpha > 0.15 or os.clock() - self.SprintEnded < Settings.Movement.SprintToFireDelay then
		return false
	end
	return true
end

function WeaponController:ProcessTrigger()
	if not (self.TriggerHeld or self.BurstRemaining > 0) then
		return
	end
	if not self:CanFire() then
		return
	end
	local clock = os.clock()
	if clock < self.NextShot then
		return
	end

	local mode = WeaponState.FireModeName(self.State, self.Config)
	local shots = 0
	-- Allow catching up multiple shots in one frame at high RPM / low FPS
	while clock >= self.NextShot and shots < 3 do
		if mode == "Auto" then
			if not self.TriggerHeld then
				break
			end
		elseif mode == "Burst" then
			if self.BurstRemaining <= 0 then
				break
			end
			self.BurstRemaining -= 1
		else
			if self.TriggerConsumed then
				break
			end
			self.TriggerConsumed = true
		end

		self.NextShot = math.max(self.NextShot + self.Config.FireInterval, clock - self.Config.FireInterval * 0.5)
		shots += 1
		if not self:Shoot() then
			self.TriggerConsumed = true
			self.BurstRemaining = 0
			break
		end
	end
end

function WeaponController:GetAim(): (Vector3, Vector3)
	local camera = Workspace.CurrentCamera
	local cameraCFrame = camera.CFrame
	local params = Projectiles.GetParams(self.Character, false)

	local muzzle = self:Muzzle()
	local headPosition = self.Head and self.Head.Position or cameraCFrame.Position
	local origin = if muzzle then muzzle.WorldPosition else headPosition

	-- Muzzle poking through a wall: start the bullet on our side of it
	local toMuzzle = origin - headPosition
	if toMuzzle.Magnitude > 0.05 then
		local blocked = Workspace:Raycast(headPosition, toMuzzle, params)
		if blocked then
			origin = blocked.Position - toMuzzle.Unit * 0.05
		end
	end

	-- Converge on whatever is under the crosshair (prevents third person parallax)
	local look = cameraCFrame.LookVector
	local result = Workspace:Raycast(cameraCFrame.Position, look * 3000, params)
	local target = if result then result.Position else cameraCFrame.Position + look * 3000
	local direction = target - origin
	if direction.Magnitude < 3 or direction.Unit:Dot(look) < 0.6 then
		direction = look
	end
	return origin, direction.Unit
end

function WeaponController:CurrentSpread(): number
	local spread = self.Config.Spread
	local aim = self.AimAlpha
	local value = spread.MOA / 60 + spread.Hip * (1 - aim) + spread.Aim * aim

	local velocity = self.Root and self.Root.AssemblyLinearVelocity or Vector3.zero
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	value += spread.Move * math.clamp(horizontal / 16, 0, 1.5) * (1 - aim * 0.5)
	if self.Humanoid.FloorMaterial == Enum.Material.Air then
		value += spread.Air
	end
	value += self.Bloom * (1 - aim * 0.7)
	value += spread.Heat * (self.State and self.State.Heat or 0)
	return value
end

-- Returns false if the weapon didn't go bang (stop the trigger loop)
function WeaponController:Shoot(): boolean
	local config, state = self.Config, self.State
	local result = WeaponState.PullTrigger(state, config, now())

	if result == "Safe" then
		self:SetStatus("SAFE", 1)
		return false
	elseif result == "Malfunction" or result == "Dry" then
		self:PlaySound("Dry")
		self:PlayAnimation("Dry")
		if result == "Dry" then
			self:SetStatus(if WeaponState.TotalReserve(state) > 0 then "Empty  [R] reload" else "Empty", 1.5)
		end
		return false
	elseif result == "NeedsCycle" then
		self.NeedsCycle = true
		self:Cycle()
		return false
	elseif result == "Dud" then
		self:PlaySound("Dry")
		self:OnMalfunction()
		local origin, direction = self:GetAim()
		self.ShotId += 1
		Remotes.Fire:FireServer(self.Tool, self.ShotId, origin, direction, 0, 0, true)
		return false
	end

	-- Bang
	local origin, aimDirection = self:GetAim()
	local spread = self:CurrentSpread()
	local seed = rng:NextInteger(1, 2 ^ 30)
	self.ShotId += 1
	local directions = Ballistics.PelletDirections(aimDirection, seed, config.Pellets, spread, config.Spread.PelletSpread)

	Projectiles.Fire({
		Shooter = LocalPlayer,
		Character = self.Character,
		Config = config,
		Origin = origin,
		Directions = directions,
		Seed = seed,
		ShotId = self.ShotId,
		IsLocal = true,
	})
	Remotes.Fire:FireServer(self.Tool, self.ShotId, origin, aimDirection, seed, spread, false)

	-- Presentation
	Effects.MuzzleFlash(self:Muzzle())
	self:PlaySound("Fire")
	self:PlayAnimation(if self.AimAlpha > 0.5 then "AimFire" else "Fire")
	if config.Action == "Gas" and state.Malfunction ~= "Stovepipe" then
		self:EjectShell()
	end
	self:ApplyRecoil()

	local s = config.Spread
	self.Bloom = math.min(s.BloomMax, self.Bloom + s.BloomPerShot)
	self.LastShot = os.clock()

	if state.Malfunction then
		self:OnMalfunction()
		return false
	end
	if WeaponState.IsManual(config) then
		self.NeedsCycle = true
		if not self.TriggerHeld then
			self:Cycle()
		end
		return false
	end
	return true
end

function WeaponController:ApplyRecoil()
	local recoil = self.Config.Recoil
	local aim = self.AimAlpha
	local multiplier = 1 + (recoil.AimMultiplier - 1) * aim
	if os.clock() - self.LastShot > self.Config.FireInterval * 2.5 then
		multiplier *= recoil.FirstShot
	end
	-- Moving / airborne shooters control recoil worse
	if self.Humanoid.FloorMaterial == Enum.Material.Air then
		multiplier *= 1.3
	end

	local vertical = (recoil.Vertical + (rng:NextNumber() * 2 - 1) * recoil.VerticalVariance) * multiplier
	local horizontal = (rng:NextNumber() * 2 - 1 + recoil.HorizontalBias) * recoil.Horizontal * multiplier
	local roll = (rng:NextNumber() * 2 - 1) * recoil.Viewmodel.Roll * 0.3
	CameraController.Kick(vertical, horizontal, roll, recoil.Recovery, recoil.Camera)
	CameraController.Shake(recoil.Shake)
	if self.Viewmodel then
		self.Viewmodel:Kick(aim, multiplier)
	end
end

----------------------------------------------------------------------------------------------------
-- Actions
----------------------------------------------------------------------------------------------------

function WeaponController:Reload()
	local config, state = self.Config, self.State
	if not state or self.Busy then
		return
	end
	if state.Malfunction then
		self:SetStatus("Clear the malfunction first  [F]", 1.5)
		return
	end
	local kind = WeaponState.ReloadKind(state, config)
	if not kind then
		if WeaponState.TotalReserve(state) <= 0 then
			self:SetStatus("No spare ammo", 1.5)
		end
		return
	end
	if kind == "Insert" then
		self:TubeReload()
		return
	end

	local duration = WeaponState.ReloadTime(config, kind)
	local token = self:SetBusy("Reload")
	Remotes.Action:FireServer(self.Tool, "ReloadStart", kind)
	local name = if kind == "Empty" then "ReloadEmpty" else "Reload"
	self:PlayAnimation(name, duration)
	self:PlaySound(name)

	task.delay(duration, function()
		if not self:IsCurrent(token) then
			return
		end
		WeaponState.ApplyReload(self.State, config, kind)
		Remotes.Action:FireServer(self.Tool, "ReloadFinish")
		self.NeedsCycle = WeaponState.IsManual(config) and self.State.Chamber ~= "Loaded"
		self:EndBusy(token)
		if self.NeedsCycle and not self.TriggerHeld then
			self:Cycle()
		end
	end)
end

function WeaponController:TubeReload()
	local config = self.Config
	local times = config.Times
	local token = self:SetBusy("Reload")
	self.ReloadInterrupt = false
	Remotes.Action:FireServer(self.Tool, "ReloadStart", "Insert")
	self:PlayAnimation("ReloadStart", times.ReloadStart)
	self:PlaySound("ReloadStart")

	task.spawn(function()
		task.wait(times.ReloadStart)
		while self:IsCurrent(token) and WeaponState.ReloadKind(self.State, config) == "Insert" do
			self:PlayAnimation("ShellInsert", times.ShellInsert)
			self:PlaySound("ShellInsert")
			task.wait(times.ShellInsert)
			if not self:IsCurrent(token) then
				return
			end
			WeaponState.ApplyReload(self.State, config, "Insert")
			Remotes.Action:FireServer(self.Tool, "ReloadFinish")
			if self.ReloadInterrupt then
				break
			end
		end
		if not self:IsCurrent(token) then
			return
		end
		self:PlayAnimation("ReloadEnd", times.ReloadEnd)
		self:PlaySound("ReloadEnd")
		task.wait(times.ReloadEnd)
		if not self:IsCurrent(token) then
			return
		end
		self:EndBusy(token)
		if self.State.Chamber ~= "Loaded" and not self.State.Malfunction then
			self.NeedsCycle = true
			self:Cycle()
		end
	end)
end

-- Work the action (pump / bolt)
function WeaponController:Cycle()
	local config, state = self.Config, self.State
	if state and not WeaponState.CanCycle(state, config) then
		self.NeedsCycle = false
		return
	end
	if not state or self.Busy then
		return
	end
	local duration = config.Times.Cycle
	local token = self:SetBusy("Cycle")
	self:PlayAnimation("Cycle", duration)
	self:PlaySound("Cycle")
	local hadCase = state.Chamber == "Spent"

	task.delay(duration * 0.45, function()
		if self:IsCurrent(token) and hadCase then
			self:EjectShell()
		end
	end)
	task.delay(duration, function()
		if not self:IsCurrent(token) then
			return
		end
		WeaponState.Cycle(self.State, config)
		Remotes.Action:FireServer(self.Tool, "Cycle")
		self.NeedsCycle = false
		if self.State.Malfunction then
			self:OnMalfunction()
		end
		self:EndBusy(token)
	end)
end

function WeaponController:ClearMalfunction()
	local config, state = self.Config, self.State
	if not state or self.Busy then
		return
	end
	local doubleFeed = state.Malfunction == "DoubleFeed"
	local duration = WeaponState.ClearTime(state, config)
	local token = self:SetBusy("Clear")
	Remotes.Action:FireServer(self.Tool, "ClearStart")
	local name = if doubleFeed then "ClearDoubleFeed" else "ClearMalfunction"
	self:PlayAnimation(name, duration)
	self:PlaySound(name)

	task.delay(duration * 0.5, function()
		if self:IsCurrent(token) then
			-- Dud / case / stuck round flies out
			self:EjectShell()
		end
	end)
	task.delay(duration, function()
		if not self:IsCurrent(token) then
			return
		end
		WeaponState.ClearMalfunction(self.State, config)
		Remotes.Action:FireServer(self.Tool, "ClearFinish")
		self.NeedsCycle = false
		self:EndBusy(token)
	end)
end

function WeaponController:SwitchFireMode()
	local config, state = self.Config, self.State
	if not state or self.Busy or #config.FireModes < 2 then
		return
	end
	local token = self:SetBusy("FireMode", config.Times.FireModeSwitch)
	state.FireMode = WeaponState.NextFireMode(state, config)
	Remotes.Action:FireServer(self.Tool, "FireMode", state.FireMode)
	self:PlayAnimation("FireMode", config.Times.FireModeSwitch)
	self:PlaySound("FireMode")
	self:SetStatus(string.upper(WeaponState.FireModeName(state, config)), 1)
	return token
end

function WeaponController:CheckAmmo()
	if not self.State or self.Busy then
		return
	end
	local duration = self.Config.Times.CheckAmmo
	local token = self:SetBusy("CheckAmmo", duration)
	self:PlayAnimation("CheckAmmo", duration)
	task.delay(duration * 0.6, function()
		if self:IsCurrent(token) then
			HUD.ShowEstimate(3)
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- Per frame
----------------------------------------------------------------------------------------------------

function WeaponController:Render(dt: number)
	if self.Destroyed then
		return
	end
	local config = self.Config
	local humanoid = self.Humanoid
	local camera = Workspace.CurrentCamera

	-- Sprint: needs to be moving, cancels aiming
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local sprinting = self.SprintHeld
		and moving
		and humanoid.FloorMaterial ~= Enum.Material.Air
		and (self.Busy == nil or self.Busy == "Reload" or self.Busy == "Equip")
	if not sprinting and self.SprintAlpha > 0.5 then
		self.SprintEnded = os.clock()
	end
	local sprintSpeed = 1 / math.max(config.Times.SprintOut, 0.05)
	self.SprintAlpha = math.clamp(self.SprintAlpha + (if sprinting then dt else -dt) * sprintSpeed, 0, 1)

	-- Aim: blocked while sprinting, reloading, clearing
	local canAim = self.AimHeld and not sprinting and self.Busy ~= "Reload" and self.Busy ~= "Clear"
	local aimSpeed = 1 / math.max(config.Times.AimIn, 0.05)
	self.AimAlpha = math.clamp(self.AimAlpha + (if canAim then dt else -dt) * aimSpeed, 0, 1)
	local easedAim = self.AimAlpha * self.AimAlpha * (3 - 2 * self.AimAlpha)
	CameraController.AimAlpha = easedAim

	-- Walk speed
	local handling = config.Handling
	local speed = self.BaseWalkSpeed
		* (handling.WalkSpeedMultiplier + (handling.AimWalkSpeedMultiplier - handling.WalkSpeedMultiplier) * easedAim)
	if sprinting then
		speed = self.BaseWalkSpeed * Settings.Movement.SprintSpeedMultiplier * handling.WalkSpeedMultiplier
	end
	humanoid.WalkSpeed = speed

	-- Loops
	if sprinting ~= self.WasSprinting then
		self.WasSprinting = sprinting
		if sprinting then
			self:PlayLoop("Sprint")
		else
			self:StopAnimation("Sprint")
		end
	end
	local aimingNow = easedAim > 0.5
	if aimingNow ~= self.WasAiming then
		self.WasAiming = aimingNow
		if aimingNow then
			self.ThirdPerson:Play("Aim", nil, 0.2)
		else
			self.ThirdPerson:Stop("Aim")
		end
	end

	-- Bloom recovery
	self.Bloom = math.max(0, self.Bloom - config.Spread.BloomRecovery * dt)

	-- Firing
	self:ProcessTrigger()
	if self.NeedsCycle and not self.Busy and not self.TriggerHeld then
		self:Cycle()
	end

	-- First / third person
	local firstPerson = CameraController.FirstPerson
	self.FirstPerson = firstPerson
	if self.Viewmodel then
		self.Viewmodel:SetVisible(firstPerson)
		Effects.SetLocalTransparency(self.ToolParts, if firstPerson then 1 else 0)
		if firstPerson then
			local velocity = self.Root and self.Root.AssemblyLinearVelocity or Vector3.zero
			self.Viewmodel:Update(dt, camera.CFrame, {
				AimAlpha = easedAim,
				SprintAlpha = self.SprintAlpha,
				MoveSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude,
				Grounded = humanoid.FloorMaterial ~= Enum.Material.Air,
			})
		end
	end

	-- Upper body pitch (local + replicated)
	local pitch = math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1))
	if self.Waist and self.WaistC0 then
		self.Waist.C0 = self.WaistC0 * CFrame.Angles(pitch * 0.6, 0, 0)
	end
	local clock = os.clock()
	if clock - self.PitchSendTime > 1 / Settings.Replication.LookRate and math.abs(pitch - self.LastPitchSent) > 0.02 then
		self.PitchSendTime = clock
		self.LastPitchSent = pitch
		Remotes.Look:FireServer(pitch)
	end

	-- HUD
	local state = self.State
	if state then
		local status = if os.clock() < self.StatusUntil then self.Status else nil
		if not status and (self.Busy == "Reload" or self.Busy == "Clear") then
			status = if self.Busy == "Reload" then "Reloading..." else "Clearing..."
		end
		local mags = if type(state.Reserve) == "table" then #state.Reserve else 0
		HUD.Update({
			Name = config.DisplayName,
			Mode = WeaponState.FireModeName(state, config),
			Mag = state.Mag,
			Chambered = state.Chamber == "Loaded",
			Reserve = WeaponState.TotalReserve(state),
			Estimate = WeaponState.MagEstimate(state, config),
			ReserveText = if config.Feed == "Tube" then `{state.Reserve} shells` else `{mags} mags`,
			Malfunction = state.Malfunction,
			Status = status,
			ShowDot = not firstPerson and easedAim < 0.5,
		})
	end
end

----------------------------------------------------------------------------------------------------
-- Cleanup
----------------------------------------------------------------------------------------------------

function WeaponController:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.BusyToken += 1
	if self.Busy and self.Busy ~= "Equip" then
		Remotes.Action:FireServer(self.Tool, "Cancel")
	end
	self:UnbindInput()
	RunService:UnbindFromRenderStep(self.RenderName)
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	if self.Viewmodel then
		self.Viewmodel:Destroy()
	end
	self.ThirdPerson:Destroy()
	Effects.SetLocalTransparency(self.ToolParts, 0)
	if self.Waist and self.WaistC0 then
		self.Waist.C0 = self.WaistC0
	end
	if self.Humanoid and self.Humanoid.Parent then
		self.Humanoid.WalkSpeed = self.BaseWalkSpeed
	end
	CameraController.SetEquipped(false)
	HUD.SetVisible(false)
end

return WeaponController
