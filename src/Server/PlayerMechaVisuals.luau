--!strict
-- PlayerMechaVisuals.luau: Modular 3D Mecha transformation with independent Torso (aim) and Legs (walk cycle) joints
-- Fully supports dual-axis rotation and procedural mechanical walk animation.

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

local function createJointAnchor(name: string, cframe: CFrame, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(0.5, 0.5, 0.5)
	p.CFrame = cframe
	p.Transparency = 1
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Anchored = false
	p.Parent = parent
	return p
end

function PlayerMechaVisuals.Apply(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not hrp or not humanoid then return end

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

	-- Clean up nested humanoids or animators to prevent Roblox physics conflicts
	for _, child in ipairs(clone:GetDescendants()) do
		if child:IsA("Humanoid") or child:IsA("Animator") then
			child:Destroy()
		end
	end

	-- Prepare parts: unanchor, massless, non-colliding
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true
			part.Anchored = false
			part.CastShadow = true
			applySciFiMechaMaterials(part)
		end
	end

	-- Scale mecha to heroic height (~6.2 studs)
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

	-- Position mecha slightly offset so feet align flush with ground
	clone:PivotTo(hrp.CFrame * CFrame.new(0, -0.6, 0))

	local modelCf, modelSize = clone:GetBoundingBox()
	local modelCenterY = modelCf.Position.Y - (modelSize.Y * 0.1)

	-- 1. Create independent Torso & Leg Anchors
	local torsoAnchor = createJointAnchor("MechaTorsoAnchor", hrp.CFrame * CFrame.new(0, 0.5, 0), clone)
	local leftLegAnchor = createJointAnchor("MechaLeftLegAnchor", hrp.CFrame * CFrame.new(-0.8, -0.2, 0), clone)
	local rightLegAnchor = createJointAnchor("MechaRightLegAnchor", hrp.CFrame * CFrame.new(0.8, -0.2, 0), clone)

	-- 2. Create Motor6D joints on HRP for full animation
	local function createOrResetMotor6D(name: string, p0: BasePart, p1: BasePart, c0: CFrame): Motor6D
		local existingJoint = hrp:FindFirstChild(name)
		if existingJoint then existingJoint:Destroy() end

		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = c0
		m.C1 = CFrame.identity
		m.Parent = hrp
		return m
	end

	createOrResetMotor6D("MechaWaistJoint", hrp, torsoAnchor, CFrame.new(0, 0.5, 0))
	createOrResetMotor6D("MechaLeftHip", hrp, leftLegAnchor, CFrame.new(-0.8, -0.2, 0))
	createOrResetMotor6D("MechaRightHip", hrp, rightLegAnchor, CFrame.new(0.8, -0.2, 0))

	-- 3. Group and weld parts to their respective articulated anchors
	local upperCount = 0
	local leftCount = 0
	local rightCount = 0
	local pelvisCount = 0

	for _, p in ipairs(clone:GetDescendants()) do
		if p:IsA("BasePart") and p ~= torsoAnchor and p ~= leftLegAnchor and p ~= rightLegAnchor then
			local name = string.lower(p.Name)
			if isUpperBodyPart(p, modelCenterY) then
				local w = Instance.new("WeldConstraint")
				w.Part0 = torsoAnchor
				w.Part1 = p
				w.Parent = p
				upperCount += 1
			else
				-- Lower body: determine Left Leg vs Right Leg vs Pelvis
				if string.find(name, "left") or string.find(name, "_l_") or string.find(name, "_l") or (p.Position.X < (modelCf.Position.X - 0.25)) then
					local w = Instance.new("WeldConstraint")
					w.Part0 = leftLegAnchor
					w.Part1 = p
					w.Parent = p
					leftCount += 1
				elseif string.find(name, "right") or string.find(name, "_r_") or string.find(name, "_r") or (p.Position.X > (modelCf.Position.X + 0.25)) then
					local w = Instance.new("WeldConstraint")
					w.Part0 = rightLegAnchor
					w.Part1 = p
					w.Parent = p
					rightCount += 1
				else
					-- Central hips / pelvis
					local w = Instance.new("WeldConstraint")
					w.Part0 = hrp
					w.Part1 = p
					w.Parent = p
					pelvisCount += 1
				end
			end
		end
	end

	clone.Name = "MechaAvatar"
	clone.Parent = character

	print(string.format("[PlayerMechaVisuals] Articulated Mecha '%s' mounted (Torso: %d, LeftLeg: %d, RightLeg: %d, Pelvis: %d)",
		template.Name, upperCount, leftCount, rightCount, pelvisCount))
end

return PlayerMechaVisuals
