--!strict
-- PlayerMechaVisuals.luau: Automatically transforms player avatars into 3D Mechas from ReplicatedStorage.Mech
-- Preserves standard Roblox Humanoid physics while replacing visual limbs with the custom 3D Mecha

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

	-- Find primary anchor part of the mecha
	local primary = clone.PrimaryPart
	if not primary then
		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("BasePart") then
				primary = desc
				clone.PrimaryPart = desc
				break
			end
		end
	end

	if not primary then
		warn("[PlayerMechaVisuals] Failed to find BasePart in template " .. template.Name)
		clone:Destroy()
		return
	end

	-- Prepare parts: unanchor, massless, non-colliding (zero physics interference)
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true
			part.Anchored = false
			part.CastShadow = true
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

	-- Weld main part to HumanoidRootPart
	local rootWeld = Instance.new("WeldConstraint")
	rootWeld.Name = "MechaRootWeld"
	rootWeld.Part0 = hrp
	rootWeld.Part1 = primary
	rootWeld.Parent = primary

	-- Weld all secondary parts to primary
	for _, p in ipairs(clone:GetDescendants()) do
		if p:IsA("BasePart") and p ~= primary then
			local subWeld = Instance.new("WeldConstraint")
			subWeld.Part0 = primary
			subWeld.Part1 = p
			subWeld.Parent = p
		end
	end

	clone.Name = "MechaAvatar"
	clone.Parent = character

	print(string.format("[PlayerMechaVisuals] Successfully transformed '%s' into Mecha '%s'!", character.Name, template.Name))
end

return PlayerMechaVisuals
