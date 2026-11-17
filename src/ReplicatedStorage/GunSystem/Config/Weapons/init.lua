--[[
	Weapon registry. Every ModuleScript under this one is a weapon config; it is keyed by its Id.
	Add a new weapon by adding a ModuleScript here (copy one of the examples) and giving your Tool
	an attribute WeaponId = "<Id>".
]]

local Weapons = {}

for _, module in script:GetChildren() do
	if module:IsA("ModuleScript") then
		local config = require(module)
		config.Id = config.Id or module.Name
		Weapons[config.Id] = config
	end
end

return Weapons
