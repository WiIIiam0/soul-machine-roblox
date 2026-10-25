--!strict
-- PlayerMechaVisuals.luau: Automatically transforms player avatars into 3D Mechas from ReplicatedStorage.Mech
-- Supports dual-axis rotation: legs face movement direction, while upper torso aims towards target or aligns with legs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlayerMechaVisuals = {}

local MECHA_CANDIDATE_KEYWORDS = {
	"mech_humanoid_lvl1",
	"mech_humanoid_lvl2",
	"mech_humanoid_lvl3",
	"humanoid_body_lvl1",
	"humanoid_body_lvl2",
	"cockpit_humanoid_lvl1",
	"legs_med",
	"mech_walker_legs_med",
	"cockpit_base",
	"mech_humanoid",
	"humanoid_body",
	"mech_walker",
}

local cachedMechaTemplate: Model? = nil

local function findMechaTemplate(): Model?
	if cachedMechaTemplate and cachedMechaTemplate.Parent then
		return cachedMechaTemplate
	end

	local containers = {
		ReplicatedStorage:FindFirstChild("Mech"),
		ReplicatedStorage:FindFirstChild("CustomCreeps"),
		ReplicatedStorage:FindFirstChild("Assets"),
		ReplicatedStorage,
		Workspace:FindFirstChild("Mech"),
	}

	for _, container in ipairs(containers) do
		if container then
			-- 1. Try prioritized exact/keyword candidates
			for _, kw in ipairs(MECHA_CANDIDATE_KEYWORDS) do
				for _, desc in ipairs(container:GetDescendants()) do
					if desc:IsA("Model") and not desc:FindFirstAncestor("ActiveEnemies") and not desc:FindFirstAncestorOfClass("Player") then
						local lower = string.lower(desc.Name)
						if string.find(lower, kw, 1, true) then
							print(string.format("[PlayerMechaVisuals] Found player Mecha model: %s (%s)", desc.Name, desc:GetFullName()))
							cachedMechaTemplate = desc
							return desc
						end
					end
				end
			end

			-- 2. Fallback: Any model starting with Mech_Humanoid or Cockpit
			for _, desc in ipairs(container:GetDescendants()) do
				if desc:IsA("Model") and not desc:FindFirstAncestor("ActiveEnemies") and not desc:FindFirstAncestorOfClass("Player") then
					local lower = string.lower(desc.Name)
					if string.find(lower, "mech", 1, true) or string.find(lower, "cockpit", 1, true) then
						print(string.format("[PlayerMechaVisuals] Fallback player Mecha model: %s (%s)", desc.Name, desc:GetFullName()))
						cachedMechaTemplate = desc
						return desc
					end
				end
			end
		end
	end

	return nil
end

local function isUpperBodyPart(part: BasePart, modelCenterY: number): boolean
	local name = string.lower(part.Name)
	if string.find(name, "spine") or string.find(name, "chest") or string.find(name, "torso")
		or string.find(name, "head") or string.find(name, "neck") or string.find(name, "arm")
		or string.find(name, "shoulder") or string.find(name, "hand") or string.find(name, "gun")
		or string.find(name, "weapon") or string.find(name, "cockpit") or string.find(name, "backpack")
		or string.find(name, "buste") then
		return true
	end
	if string.find(name, "leg") or string.find(name, "foot") or string.find(name, "feet")
		or string.find(name, "pelvis") or string.find(name, "hip") or string.find(name, "thigh")
		or string.find(name, "wheel") or string.find(name, "track") or string.find(name, "tread") then
		return false
	end
	return part.Position.Y >= modelCenterY
end

local function applySciFiMechaMaterials(part: BasePart)
	local name = string.lower(part.Name)
	if string.find(name, "eye") or string.find(name, "visor") or string.find(name, "glow")
		or string.find(name, "light") or string.find(name, "core") or string.find(name, "glass") then
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(0, 225, 255)
	elseif string.find(name, "joint") or string.find(name, "spine") or string.find(name, "frame")
		or string.find(name, "hydraulic") or string.find(name, "piston") then
		part.Material = Enum.Material.DiamondPlate
		part.Color = Color3.fromRGB(28, 32, 42)
	elseif string.find(name, "accent") or string.find(name, "stripe") or string.find(name, "shoulder") then
		part.Material = Enum.Material.Metal
		part.Color = Color3.fromRGB(25, 125, 245)
	else
		-- High-grade gunmetal battle plating
		part.Material = Enum.Material.Metal
		part.Color = Color3.fromRGB(52, 58, 70)
	end
end

function PlayerMechaVisuals.Apply(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not hrp or not humanoid then return end

	-- Remove existing Mecha avatar if re-applying
	local existing = character:FindFirstChild("MechaAvatar")
	if existing then
		existing:Destroy()
	end

	local template = findMechaTemplate()
	if not template then
		print("[PlayerMechaVisuals] No custom Mecha template found, keeping default avatar.")
		return
	end

	local clone = template:Clone()

	-- Clean up nested humanoids to prevent Roblox character physics conflicts
	for _, child in ipairs(clone:GetDescendants()) do
		if child:IsA("Humanoid") or child:IsA("Animator") then
			child:Destroy()
		end
	end

	-- Prepare parts: unanchor, massless, non-colliding (zero physics interference)
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true
			part.Anchored = false
			part.CastShadow = true
			applySciFiMechaMaterials(part)
		end
	end

	-- Scale mecha to heroic robot height (~6.2 studs)
	local extents = clone:GetExtentsSize()
	if extents.Y > 0 then
		local targetHeight = 6.2
		local factor = math.clamp(targetHeight / extents.Y, 0.01, 50.0)
		clone:ScaleTo(factor)
	end

	-- Make default Roblox character body parts invisible
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" then
			desc.Transparency = 1
		elseif desc:IsA("Decal") then
			desc.Transparency = 1
		elseif desc:IsA("Accessory") then
			local handle = desc:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.Transparency = 1
			end
		end
	end

	-- Position mecha at HumanoidRootPart slightly offset so feet align with ground
	clone:PivotTo(hrp.CFrame * CFrame.new(0, -0.6, 0))

	-- Calculate model vertical center to separate Lower Body (legs) and Upper Body (torso)
	local modelCf, modelSize = clone:GetBoundingBox()
	local modelCenterY = modelCf.Position.Y - (modelSize.Y * 0.1)

	-- Create Torso Anchor for swiveling Upper Body
	local torsoAnchor = Instance.new("Part")
	torsoAnchor.Name = "MechaTorsoAnchor"
	torsoAnchor.Size = Vector3.new(1, 1, 1)
	torsoAnchor.CFrame = hrp.CFrame * CFrame.new(0, 0.5, 0)
	torsoAnchor.Transparency = 1
	torsoAnchor.CanCollide = false
	torsoAnchor.Massless = true
	torsoAnchor.Anchored = false
	torsoAnchor.Parent = clone

	-- Motor6D connecting Legs (HRP) to Torso Anchor (Allows independent buste rotation)
	local oldJoint = hrp:FindFirstChild("MechaWaistJoint")
	if oldJoint then oldJoint:Destroy() end

	local waistJoint = Instance.new("Motor6D")
	waistJoint.Name = "MechaWaistJoint"
	waistJoint.Part0 = hrp
	waistJoint.Part1 = torsoAnchor
	waistJoint.C0 = CFrame.new(0, 0.5, 0)
	waistJoint.C1 = CFrame.identity
	waistJoint.Parent = hrp

	-- Separate and weld Upper vs Lower parts
	local upperParts: { BasePart } = {}
	local lowerParts: { BasePart } = {}

	for _, p in ipairs(clone:GetDescendants()) do
		if p:IsA("BasePart") and p ~= torsoAnchor then
			if isUpperBodyPart(p, modelCenterY) then
				table.insert(upperParts, p)
			else
				table.insert(lowerParts, p)
			end
		end
	end

	-- Weld upper body parts to torsoAnchor
	for _, p in ipairs(upperParts) do
		local w = Instance.new("WeldConstraint")
		w.Part0 = torsoAnchor
		w.Part1 = p
		w.Parent = p
	end

	-- Weld lower body (legs/hips) to HRP
	for _, p in ipairs(lowerParts) do
		local w = Instance.new("WeldConstraint")
		w.Part0 = hrp
		w.Part1 = p
		w.Parent = p
	end

	clone.Name = "MechaAvatar"
	clone.Parent = character

	print(string.format("[PlayerMechaVisuals] Applied modular Mecha '%s' (Upper: %d, Lower: %d)", template.Name, #upperParts, #lowerParts))
end

return PlayerMechaVisuals
