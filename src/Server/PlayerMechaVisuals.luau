--!strict
-- PlayerMechaVisuals.luau: Modular 3D Mecha transformation with independent Torso (aim), Chassis & Legs joints
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
	-- 1. Explicit lower body / locomotion keywords
	if string.find(name, "leg") or string.find(name, "foot") or string.find(name, "feet")
		or string.find(name, "pelvis") or string.find(name, "hip") or string.find(name, "thigh")
		or string.find(name, "shin") or string.find(name, "toe") or string.find(name, "heel")
		or string.find(name, "wheel") or string.find(name, "track") or string.find(name, "tread") then
		return false
	end

	-- 2. Explicit upper body / torso keywords (includes body, chest, arms, shoulders, guns, cockpit, head)
	if string.find(name, "body") or string.find(name, "chest") or string.find(name, "torso")
		or string.find(name, "head") or string.find(name, "neck") or string.find(name, "arm")
		or string.find(name, "shoulder") or string.find(name, "hand") or string.find(name, "gun")
		or string.find(name, "weapon") or string.find(name, "cockpit") or string.find(name, "backpack")
		or string.find(name, "buste") or string.find(name, "spine") or string.find(name, "mount")
		or string.find(name, "eye") or string.find(name, "visor") then
		return true
	end

	-- 3. Fallback based on height relative to model center
	return part.Position.Y >= modelCenterY
end

local function applySciFiMechaMaterials(part: BasePart)
	-- Preserve original textures or decals if present
	if (part:IsA("MeshPart") and part.TextureID ~= "") or part:FindFirstChildOfClass("SurfaceAppearance") or part:FindFirstChildOfClass("Decal") then
		part.Color = Color3.new(1, 1, 1)
		return
	end

	local name = string.lower(part.Name)
	if string.find(name, "eye") or string.find(name, "visor") or string.find(name, "glow")
		or string.find(name, "light") or string.find(name, "core") or string.find(name, "glass") then
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(0, 225, 255)
	elseif string.find(name, "joint") or string.find(name, "spine") or string.find(name, "frame")
		or string.find(name, "hydraulic") or string.find(name, "piston") then
		part.Material = Enum.Material.DiamondPlate
		part.Color = Color3.fromRGB(28, 32, 40)
	elseif string.find(name, "outline") then
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(15, 18, 24)
	else
		-- High-grade military gunmetal composite (unified and textured appearance)
		part.Material = Enum.Material.Metal
		part.Color = Color3.fromRGB(56, 62, 74)
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
	local function hideDefaultPart(desc: Instance)
		if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" and not desc:IsDescendantOf(clone) then
			desc.Transparency = 1
		elseif desc:IsA("Decal") and not desc:IsDescendantOf(clone) then
			desc.Transparency = 1
		elseif desc:IsA("Accessory") then
			local handle = desc:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.Transparency = 1
			end
		end
	end

	for _, desc in ipairs(character:GetDescendants()) do
		hideDefaultPart(desc)
	end
	character.DescendantAdded:Connect(hideDefaultPart)

	-- Position mecha slightly offset so feet align flush with ground
	clone:PivotTo(hrp.CFrame * CFrame.new(0, -0.6, 0))

	local modelCf, modelSize = clone:GetBoundingBox()
	local modelCenterY = modelCf.Position.Y - (modelSize.Y * 0.15)

	-- 1. Create articulated Anchors for Torso, Chassis & Individual Legs
	local chassisAnchor = createJointAnchor("MechaChassisAnchor", hrp.CFrame * CFrame.new(0, -0.2, 0), clone)
	local torsoAnchor = createJointAnchor("MechaTorsoAnchor", hrp.CFrame * CFrame.new(0, 0.4, 0), clone)
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

	createOrResetMotor6D("MechaChassisJoint", hrp, chassisAnchor, CFrame.new(0, -0.2, 0))
	createOrResetMotor6D("MechaWaistJoint", hrp, torsoAnchor, CFrame.new(0, 0.4, 0))
	createOrResetMotor6D("MechaLeftHip", hrp, leftLegAnchor, CFrame.new(-0.8, -0.2, 0))
	createOrResetMotor6D("MechaRightHip", hrp, rightLegAnchor, CFrame.new(0.8, -0.2, 0))

	-- 3. Group and weld parts to their respective articulated anchors
	local upperCount = 0
	local leftCount = 0
	local rightCount = 0
	local chassisCount = 0

	for _, p in ipairs(clone:GetDescendants()) do
		if p:IsA("BasePart") and p ~= torsoAnchor and p ~= chassisAnchor and p ~= leftLegAnchor and p ~= rightLegAnchor then
			local name = string.lower(p.Name)
			if isUpperBodyPart(p, modelCenterY) then
				-- Upper body (Cockpit, Torso, Head, Shoulders, Arms, Hands, Weapons)
				local w = Instance.new("WeldConstraint")
				w.Part0 = torsoAnchor
				w.Part1 = p
				w.Parent = p
				upperCount += 1
			else
				-- Lower body: determine Left Leg vs Right Leg vs Central Chassis
				if string.find(name, "left") or string.find(name, "_l_") or string.find(name, "_l") or (p.Position.X < (modelCf.Position.X - 0.35)) then
					local w = Instance.new("WeldConstraint")
					w.Part0 = leftLegAnchor
					w.Part1 = p
					w.Parent = p
					leftCount += 1
				elseif string.find(name, "right") or string.find(name, "_r_") or string.find(name, "_r") or (p.Position.X > (modelCf.Position.X + 0.35)) then
					local w = Instance.new("WeldConstraint")
					w.Part0 = rightLegAnchor
					w.Part1 = p
					w.Parent = p
					rightCount += 1
				else
					-- Central chassis / pelvis / consolidated legs (like Mech_Humanoid_Legs_Geom)
					local w = Instance.new("WeldConstraint")
					w.Part0 = chassisAnchor
					w.Part1 = p
					w.Parent = p
					chassisCount += 1
				end
			end
		end
	end

	clone.Name = "MechaAvatar"
	clone.Parent = character

	print(string.format("[PlayerMechaVisuals] Articulated Mecha '%s' mounted (Torso: %d, Chassis: %d, LeftLeg: %d, RightLeg: %d)",
		template.Name, upperCount, chassisCount, leftCount, rightCount))
end

return PlayerMechaVisuals
