--[[
	Minimal, realistic HUD: weapon, selector, ammo (estimate unless Settings.HUD.ShowExactAmmo),
	malfunction prompt, hip-fire dot in third person and a hitmarker.
	Replace freely with your own UI: everything goes through the functions below.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GunSystem = ReplicatedStorage:WaitForChild("GunSystem")
local Settings = require(GunSystem:WaitForChild("Settings"))
local Assets = require(script.Parent:WaitForChild("Assets"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local HUDSettings = Settings.HUD
local LocalPlayer = Players.LocalPlayer

local HUD = {}

local MALFUNCTION_TEXT = {
	FailureToFire = "Click - failure to fire  [F] tap-rack",
	FailureToFeed = "Failure to feed  [F] tap-rack",
	Stovepipe = "Stovepipe  [F] clear",
	DoubleFeed = "Double feed  [F] strip mag & clear",
}

local gui, panel, nameLabel, modeLabel, ammoLabel, statusLabel, dot, hitmarker
local estimateUntil = 0

local function label(parent, size, position, textSize, alignment)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = size
	text.Position = position
	text.Font = Enum.Font.GothamMedium
	text.TextSize = textSize
	text.TextColor3 = Color3.fromRGB(235, 235, 235)
	text.TextStrokeTransparency = 0.6
	text.TextXAlignment = alignment or Enum.TextXAlignment.Right
	text.Text = ""
	text.Parent = parent
	return text
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "GunHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.BackgroundTransparency = 1
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -24, 1, -24)
	panel.Size = UDim2.fromOffset(360, 96)
	panel.Parent = gui

	nameLabel = label(panel, UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 0), 18)
	modeLabel = label(panel, UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 24), 14)
	ammoLabel = label(panel, UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 44), 20)
	statusLabel = label(panel, UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 72), 14)
	statusLabel.TextColor3 = Color3.fromRGB(255, 110, 90)

	dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(4, 4)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BackgroundTransparency = 0.2
	dot.BorderSizePixel = 0
	dot.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	local stroke = Instance.new("UIStroke")
	stroke.Transparency = 0.5
	stroke.Parent = dot
	dot.Parent = gui

	hitmarker = Instance.new("TextLabel")
	hitmarker.AnchorPoint = Vector2.new(0.5, 0.5)
	hitmarker.Position = UDim2.fromScale(0.5, 0.5)
	hitmarker.Size = UDim2.fromOffset(30, 30)
	hitmarker.BackgroundTransparency = 1
	hitmarker.Font = Enum.Font.GothamBold
	hitmarker.Text = "×"
	hitmarker.TextSize = 30
	hitmarker.TextColor3 = Color3.new(1, 1, 1)
	hitmarker.TextTransparency = 1
	hitmarker.Parent = gui
end

if HUDSettings.Enabled then
	build()
end

function HUD.SetVisible(visible: boolean)
	if gui then
		gui.Enabled = visible
	end
end

function HUD.ShowEstimate(duration: number)
	estimateUntil = os.clock() + duration
end

--[[
	view = { Name, Mode, Mag, Capacity, Chambered, Reserve, Estimate, Malfunction, Status, ShowDot }
]]
function HUD.Update(view)
	if not gui then
		return
	end
	nameLabel.Text = view.Name
	modeLabel.Text = string.upper(view.Mode)
	if HUDSettings.ShowExactAmmo then
		ammoLabel.Text = string.format("%d%s / %d", view.Mag, view.Chambered and "+1" or "", view.Reserve)
	elseif os.clock() < estimateUntil then
		ammoLabel.Text = `{view.Estimate}  ·  {view.ReserveText}`
	else
		ammoLabel.Text = ""
	end

	if view.Malfunction then
		statusLabel.Text = if HUDSettings.ShowMalfunctionType
			then MALFUNCTION_TEXT[view.Malfunction] or view.Malfunction
			else "Weapon won't fire  [F] clear"
	else
		statusLabel.Text = view.Status or ""
	end

	dot.Visible = HUDSettings.Crosshair and view.ShowDot
end

function HUD.Hitmarker(killed: boolean, headshot: boolean)
	if not gui or not HUDSettings.Hitmarker then
		return
	end
	hitmarker.TextColor3 = if killed
		then Color3.fromRGB(255, 70, 70)
		elseif headshot then Color3.fromRGB(255, 210, 90)
		else Color3.new(1, 1, 1)
	hitmarker.TextTransparency = 0
	TweenService:Create(hitmarker, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
	local camera = workspace.CurrentCamera
	Effects.PlaySound(Assets.GlobalSound(if killed then "Kill" else "Hitmarker"), camera)
end

return HUD
