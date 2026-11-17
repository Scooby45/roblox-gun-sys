--[[
	Loads a weapon's animations onto an Animator. Animation objects in GunAssets take priority over
	ids in the weapon config's Animations table. Missing animations are silently ignored.

	First person names:  Idle, Equip, Fire, AimFire, Reload, ReloadEmpty, ReloadStart, ShellInsert,
	                     ReloadEnd, Cycle, ClearMalfunction, ClearDoubleFeed, CheckAmmo, FireMode,
	                     Sprint, Dry
	Third person names:  same names prefixed with "TP_", plus TP_Aim (looped while aiming)
]]

local Assets = require(script.Parent:WaitForChild("Assets"))

local LOOPED = { Idle = true, Sprint = true, Aim = true }

local AnimationSet = {}
AnimationSet.__index = AnimationSet

function AnimationSet.new(animator: Animator, config, prefix: string)
	local self = setmetatable({ Animator = animator, Config = config, Prefix = prefix, Tracks = {} }, AnimationSet)
	return self
end

function AnimationSet:Get(name: string): AnimationTrack?
	local track = self.Tracks[name]
	if track ~= nil then
		return track or nil
	end
	local fullName = self.Prefix .. name
	local animation = Assets.Animation(self.Config.Id, fullName)
	if not animation then
		local id = self.Config.Animations[fullName]
		if id then
			animation = Instance.new("Animation")
			animation.AnimationId = if type(id) == "number" then "rbxassetid://" .. id else id
		end
	end
	if not animation then
		self.Tracks[name] = false
		return nil
	end
	local ok, loaded = pcall(self.Animator.LoadAnimation, self.Animator, animation)
	if not ok then
		self.Tracks[name] = false
		return nil
	end
	loaded.Looped = LOOPED[name] or loaded.Looped
	if name == "Idle" or name == "Aim" or name == "Sprint" then
		loaded.Priority = Enum.AnimationPriority.Action
	else
		loaded.Priority = Enum.AnimationPriority.Action2
	end
	self.Tracks[name] = loaded
	return loaded
end

-- Plays an animation, optionally stretching it to last `duration` seconds
function AnimationSet:Play(name: string, duration: number?, fade: number?, weight: number?)
	local track = self:Get(name)
	if not track then
		return nil
	end
	track:Play(fade or 0.1, weight or 1)
	if duration and duration > 0 and track.Length > 0 then
		track:AdjustSpeed(track.Length / duration)
	end
	return track
end

function AnimationSet:Stop(name: string, fade: number?)
	local track = self.Tracks[name]
	if track then
		track:Stop(fade or 0.15)
	end
end

function AnimationSet:IsPlaying(name: string): boolean
	local track = self.Tracks[name]
	return track and track.IsPlaying or false
end

function AnimationSet:Preload(names: { string })
	for _, name in names do
		self:Get(name)
	end
end

function AnimationSet:Destroy()
	for _, track in self.Tracks do
		if track then
			track:Stop(0)
			track:Destroy()
		end
	end
	table.clear(self.Tracks)
end

return AnimationSet
