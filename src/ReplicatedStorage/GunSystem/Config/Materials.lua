--[[
	Ballistic material table.

	Resistance        cost per mm of thickness, relative to mild steel (1.0).
	                  e.g. 5.56 (9 mm steel-equivalent) through wood (0.045) ~= 200 mm of wood.
	RicochetAngle     degrees. Impacts shallower than this (angle between bullet and surface) may skip.
	RicochetRetention fraction of speed kept after a ricochet.
	Deflection        max degrees of random yaw after fully using up penetration (scaled by how much was used).
	Effect            name of the impact effect folder in GunAssets/Effects/Impacts (falls back to "Default").

	Per-part overrides (attributes):
	  BallisticMaterial (string)  -> use that entry from this table
	  Impenetrable      (bool)    -> bullets never go through
	  PenetrationResistance (num) -> override Resistance
]]

local Materials = {}

Materials.Profiles = {
	-- Metals
	Metal = { Resistance = 1.0, RicochetAngle = 22, RicochetRetention = 0.7, Deflection = 8, Effect = "Metal" },
	DiamondPlate = { Resistance = 1.1, RicochetAngle = 24, RicochetRetention = 0.7, Deflection = 8, Effect = "Metal" },
	CorrodedMetal = { Resistance = 0.75, RicochetAngle = 18, RicochetRetention = 0.6, Deflection = 10, Effect = "Metal" },
	Foil = { Resistance = 0.15, RicochetAngle = 4, RicochetRetention = 0.5, Deflection = 3, Effect = "Metal" },

	-- Masonry / stone
	Concrete = { Resistance = 0.22, RicochetAngle = 14, RicochetRetention = 0.55, Deflection = 14, Effect = "Concrete" },
	Brick = { Resistance = 0.26, RicochetAngle = 12, RicochetRetention = 0.5, Deflection = 14, Effect = "Brick" },
	Cobblestone = { Resistance = 0.3, RicochetAngle = 14, RicochetRetention = 0.55, Deflection = 14, Effect = "Concrete" },
	Pavement = { Resistance = 0.22, RicochetAngle = 15, RicochetRetention = 0.55, Deflection = 14, Effect = "Concrete" },
	Asphalt = { Resistance = 0.18, RicochetAngle = 14, RicochetRetention = 0.5, Deflection = 14, Effect = "Concrete" },
	Granite = { Resistance = 0.35, RicochetAngle = 16, RicochetRetention = 0.6, Deflection = 12, Effect = "Concrete" },
	Marble = { Resistance = 0.33, RicochetAngle = 16, RicochetRetention = 0.6, Deflection = 12, Effect = "Concrete" },
	Slate = { Resistance = 0.32, RicochetAngle = 15, RicochetRetention = 0.55, Deflection = 12, Effect = "Concrete" },
	Rock = { Resistance = 0.35, RicochetAngle = 16, RicochetRetention = 0.55, Deflection = 12, Effect = "Concrete" },
	Basalt = { Resistance = 0.37, RicochetAngle = 16, RicochetRetention = 0.55, Deflection = 12, Effect = "Concrete" },
	Limestone = { Resistance = 0.28, RicochetAngle = 14, RicochetRetention = 0.5, Deflection = 12, Effect = "Concrete" },
	Sandstone = { Resistance = 0.24, RicochetAngle = 12, RicochetRetention = 0.5, Deflection = 12, Effect = "Concrete" },
	CrackedLava = { Resistance = 0.3, RicochetAngle = 14, RicochetRetention = 0.5, Deflection = 12, Effect = "Concrete" },
	Pebble = { Resistance = 0.18, RicochetAngle = 12, RicochetRetention = 0.45, Deflection = 14, Effect = "Dirt" },
	Salt = { Resistance = 0.15, RicochetAngle = 10, RicochetRetention = 0.45, Deflection = 10, Effect = "Concrete" },
	Plaster = { Resistance = 0.04, RicochetAngle = 6, RicochetRetention = 0.4, Deflection = 6, Effect = "Concrete" },

	-- Wood
	Wood = { Resistance = 0.045, RicochetAngle = 7, RicochetRetention = 0.45, Deflection = 6, Effect = "Wood" },
	WoodPlanks = { Resistance = 0.05, RicochetAngle = 7, RicochetRetention = 0.45, Deflection = 6, Effect = "Wood" },
	Cardboard = { Resistance = 0.006, RicochetAngle = 0, RicochetRetention = 0, Deflection = 1, Effect = "Wood" },

	-- Soft / synthetic
	Plastic = { Resistance = 0.03, RicochetAngle = 6, RicochetRetention = 0.4, Deflection = 4, Effect = "Plastic" },
	SmoothPlastic = { Resistance = 0.03, RicochetAngle = 6, RicochetRetention = 0.4, Deflection = 4, Effect = "Plastic" },
	Neon = { Resistance = 0.03, RicochetAngle = 6, RicochetRetention = 0.4, Deflection = 4, Effect = "Plastic" },
	Rubber = { Resistance = 0.05, RicochetAngle = 4, RicochetRetention = 0.3, Deflection = 6, Effect = "Plastic" },
	Fabric = { Resistance = 0.008, RicochetAngle = 0, RicochetRetention = 0, Deflection = 1, Effect = "Fabric" },
	Carpet = { Resistance = 0.01, RicochetAngle = 0, RicochetRetention = 0, Deflection = 1, Effect = "Fabric" },
	Leather = { Resistance = 0.02, RicochetAngle = 0, RicochetRetention = 0, Deflection = 2, Effect = "Fabric" },
	ForceField = { Resistance = math.huge, RicochetAngle = 0, RicochetRetention = 0, Deflection = 0, Effect = "Default" },

	-- Glass / ice
	Glass = { Resistance = 0.05, RicochetAngle = 8, RicochetRetention = 0.4, Deflection = 5, Effect = "Glass" },
	Ice = { Resistance = 0.06, RicochetAngle = 9, RicochetRetention = 0.5, Deflection = 6, Effect = "Glass" },
	Glacier = { Resistance = 0.07, RicochetAngle = 9, RicochetRetention = 0.5, Deflection = 6, Effect = "Glass" },

	-- Ground
	Grass = { Resistance = 0.11, RicochetAngle = 8, RicochetRetention = 0.4, Deflection = 15, Effect = "Dirt" },
	LeafyGrass = { Resistance = 0.11, RicochetAngle = 8, RicochetRetention = 0.4, Deflection = 15, Effect = "Dirt" },
	Ground = { Resistance = 0.12, RicochetAngle = 8, RicochetRetention = 0.4, Deflection = 15, Effect = "Dirt" },
	Mud = { Resistance = 0.1, RicochetAngle = 5, RicochetRetention = 0.3, Deflection = 15, Effect = "Mud" },
	Sand = { Resistance = 0.14, RicochetAngle = 6, RicochetRetention = 0.35, Deflection = 18, Effect = "Sand" },
	Snow = { Resistance = 0.03, RicochetAngle = 5, RicochetRetention = 0.3, Deflection = 8, Effect = "Snow" },

	-- Liquids (bullets destabilise fast in water)
	Water = { Resistance = 0.02, RicochetAngle = 7, RicochetRetention = 0.55, Deflection = 25, Effect = "Water", Liquid = true },

	-- Special
	Flesh = { Resistance = 0.012, RicochetAngle = 0, RicochetRetention = 0, Deflection = 12, Effect = "Flesh" },
	-- Accessories, invisible non-colliding parts: bullet passes through untouched, no effects
	PassThrough = { Resistance = 0, RicochetAngle = 0, RicochetRetention = 1, Deflection = 0, Effect = nil, PassThrough = true },
	Default = { Resistance = 0.08, RicochetAngle = 8, RicochetRetention = 0.45, Deflection = 8, Effect = "Default" },
}

local Profiles = Materials.Profiles

local function characterOf(instance: Instance): Model?
	local model = instance:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end
Materials.CharacterOf = characterOf

--[[
	Returns the ballistic profile for a raycast hit, plus the character model if the part belongs to one.
]]
function Materials.Resolve(instance: Instance, material: Enum.Material)
	if instance:IsA("Terrain") then
		return Profiles[material.Name] or Profiles.Default, nil
	end

	-- Accessories (hats, hair...) should not stop bullets or count as hits
	if instance:FindFirstAncestorOfClass("Accessory") then
		return Profiles.PassThrough, nil
	end

	local override = instance:GetAttribute("BallisticMaterial")
	if override and Profiles[override] then
		return Profiles[override], characterOf(instance)
	end

	local character = characterOf(instance)
	if character then
		return Profiles.Flesh, character
	end

	if instance:IsA("BasePart") then
		-- Invisible, non-colliding parts (trigger zones, hitboxes for other systems...)
		if instance.Transparency >= 0.98 and not instance.CanCollide then
			return Profiles.PassThrough, nil
		end

		local profile = Profiles[instance.Material.Name] or Profiles.Default
		if instance:GetAttribute("Impenetrable") then
			return {
				Resistance = math.huge,
				RicochetAngle = profile.RicochetAngle,
				RicochetRetention = profile.RicochetRetention,
				Deflection = 0,
				Effect = profile.Effect,
			},
				nil
		end
		local resistance = instance:GetAttribute("PenetrationResistance")
		if typeof(resistance) == "number" then
			return {
				Resistance = resistance,
				RicochetAngle = profile.RicochetAngle,
				RicochetRetention = profile.RicochetRetention,
				Deflection = profile.Deflection,
				Effect = profile.Effect,
			},
				nil
		end
		return profile, nil
	end

	return Profiles.Default, nil
end

return Materials
