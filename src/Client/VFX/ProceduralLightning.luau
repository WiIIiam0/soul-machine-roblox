--!strict
-- ProceduralLightning.luau: 3D Procedural Perlin-noise lightning & electric tracer VFX
-- Faithfully recreates Unity TheSwarm's TracerEclair.vfx, TracerTaser.prefab, TracerDarkStorm.prefab, and TracerRifle.prefab.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ProceduralLightning = {}

-- Cached container folder in Workspace to isolate visual effects
local vfxFolder: Folder? = nil
local function getVfxFolder(): Folder
	if not vfxFolder or not vfxFolder.Parent then
		local existing = Workspace:FindFirstChild("ProceduralVFX")
		if existing and existing:IsA("Folder") then
			vfxFolder = existing
		else
			local f = Instance.new("Folder")
			f.Name = "ProceduralVFX"
			f.Parent = Workspace
			vfxFolder = f
		end
	end
	return vfxFolder :: Folder
end

export type BoltConfig = {
	segments: number,
	amplitude: number,
	frequency: number,
	jitterAmp: number,
	hasCore: boolean,
	coreColor: Color3?,
	outerColor: Color3,
	width: number,
	lifetime: number,
	branches: number,
	isSniperRifle: boolean?,
}

local function getBoltConfig(weaponId: string?, baseColor: Color3?, baseWidth: number?): BoltConfig
	local id = weaponId or "Default"
	local color = baseColor or Color3.fromRGB(0, 220, 255)
	local width = baseWidth or 0.32

	if id == "Taser" then
		return {
			segments = 14,
			amplitude = 1.9,
			frequency = 8.5,
			jitterAmp = 0.45,
			hasCore = true,
			coreColor = Color3.fromRGB(240, 255, 255),
			outerColor = baseColor or Color3.fromRGB(70, 210, 255),
			width = baseWidth or 0.35,
			lifetime = 0.10,
			branches = 2,
		}
	elseif id == "DarkStorm" then
		return {
			segments = 16,
			amplitude = 2.4,
			frequency = 12.0,
			jitterAmp = 0.65,
			hasCore = true,
			coreColor = Color3.fromRGB(255, 170, 255),
			outerColor = baseColor or Color3.fromRGB(190, 50, 255),
			width = baseWidth or 0.38,
			lifetime = 0.12,
			branches = 2,
		}
	elseif id == "Rifle" then
		return {
			segments = 10,
			amplitude = 1.0,
			frequency = 6.0,
			jitterAmp = 0.25,
			hasCore = true,
			coreColor = Color3.fromRGB(255, 255, 220),
			outerColor = baseColor or Color3.fromRGB(255, 230, 80),
			width = baseWidth or 0.30,
			lifetime = 0.08,
			branches = 0,
			isSniperRifle = true,
		}
	elseif id == "Pompe" then
		return {
			segments = 6,
			amplitude = 0.6,
			frequency = 6.0,
			jitterAmp = 0.30,
			hasCore = false,
			outerColor = baseColor or Color3.fromRGB(255, 140, 30),
			width = baseWidth or 0.24,
			lifetime = 0.07,
			branches = 0,
		}
	elseif id == "Eventail" then
		return {
			segments = 8,
			amplitude = 0.8,
			frequency = 7.0,
			jitterAmp = 0.35,
			hasCore = true,
			coreColor = Color3.fromRGB(220, 255, 250),
			outerColor = baseColor or Color3.fromRGB(40, 240, 200),
			width = baseWidth or 0.30,
			lifetime = 0.08,
			branches = 0,
		}
	elseif id == "OverdriveWeapon" then
		return {
			segments = 12,
			amplitude = 1.6,
			frequency = 10.0,
			jitterAmp = 0.50,
			hasCore = true,
			coreColor = Color3.fromRGB(255, 210, 230),
			outerColor = baseColor or Color3.fromRGB(255, 45, 85),
			width = baseWidth or 0.38,
			lifetime = 0.10,
			branches = 1,
		}
	elseif id == "RocketShrapnel" then
		return {
			segments = 5,
			amplitude = 0.5,
			frequency = 5.0,
			jitterAmp = 0.25,
			hasCore = false,
			outerColor = baseColor or Color3.fromRGB(255, 120, 25),
			width = baseWidth or 0.20,
			lifetime = 0.06,
			branches = 0,
		}
	else
		-- StarterGun or generic instant shot
		return {
			segments = 8,
			amplitude = 0.45,
			frequency = 5.5,
			jitterAmp = 0.20,
			hasCore = true,
			coreColor = Color3.fromRGB(230, 255, 255),
			outerColor = color,
			width = width,
			lifetime = 0.08,
			branches = 0,
		}
	end
end

-- Helper: create an uncollidable neon segment between two 3D points
local function createNeonSegment(pA: Vector3, pB: Vector3, color: Color3, thickness: number, parent: Instance): BasePart?
	local seg = pB - pA
	local len = seg.Magnitude
	if len <= 0.05 then return nil end

	local part = Instance.new("Part")
	part.Name = "LightningSeg"
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.02
	part.Size = Vector3.new(thickness, thickness, len)
	part.CFrame = CFrame.lookAt((pA + pB) * 0.5, pB)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

-- Helper: create impact spark burst particles at hit location
local function createImpactSparks(hitPos: Vector3, normal: Vector3, color: Color3, parent: Instance)
	local sparkCount = 4
	local sparkLen = 1.4
	for _ = 1, sparkCount do
		local rndDir = (normal + Vector3.new(
			(math.random() - 0.5) * 2,
			(math.random() - 0.5) * 2,
			(math.random() - 0.5) * 2
		)).Unit
		local pB = hitPos + rndDir * sparkLen
		createNeonSegment(hitPos, pB, color, 0.10, parent)
	end
end

-- Main function to construct a procedural Perlin noise lightning bolt
function ProceduralLightning.CreateBolt(
	startPos: Vector3,
	endPos: Vector3,
	weaponId: string?,
	baseColor: Color3?,
	baseWidth: number?
)
	local ray = endPos - startPos
	local dist = ray.Magnitude
	if dist <= 0.25 then return end

	local dir = ray / dist
	local config = getBoltConfig(weaponId, baseColor, baseWidth)

	-- Compute orthonormal perpendicular basis vectors (right & up)
	local upRef = if math.abs(dir.Y) > 0.85 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	local right = dir:Cross(upRef).Unit
	local up = right:Cross(dir).Unit

	local model = Instance.new("Model")
	model.Name = "Bolt_" .. (weaponId or "Shot")
	model.Parent = getVfxFolder()

	local partsToFade: { BasePart } = {}

	-- 1. Muzzle Flash at origin
	local muzzleFlash = Instance.new("Part")
	muzzleFlash.Name = "MuzzleFlash"
	muzzleFlash.Shape = Enum.PartType.Ball
	muzzleFlash.Size = Vector3.new(config.width * 2.8, config.width * 2.8, config.width * 2.8)
	muzzleFlash.Position = startPos
	muzzleFlash.Color = config.outerColor
	muzzleFlash.Material = Enum.Material.Neon
	muzzleFlash.Transparency = 0.05
	muzzleFlash.Anchored = true
	muzzleFlash.CanCollide = false
	muzzleFlash.CanTouch = false
	muzzleFlash.CanQuery = false
	muzzleFlash.CastShadow = false
	muzzleFlash.Parent = model
	table.insert(partsToFade, muzzleFlash)

	local muzzleLight = Instance.new("PointLight")
	muzzleLight.Color = config.outerColor
	muzzleLight.Brightness = 3.5
	muzzleLight.Range = 12
	muzzleLight.Shadows = false
	muzzleLight.Parent = muzzleFlash

	-- 2. Impact point flash
	local impactFlash = Instance.new("Part")
	impactFlash.Name = "ImpactFlash"
	impactFlash.Shape = Enum.PartType.Ball
	impactFlash.Size = Vector3.new(config.width * 3.2, config.width * 3.2, config.width * 3.2)
	impactFlash.Position = endPos
	impactFlash.Color = config.outerColor
	impactFlash.Material = Enum.Material.Neon
	impactFlash.Transparency = 0.05
	impactFlash.Anchored = true
	impactFlash.CanCollide = false
	impactFlash.CanTouch = false
	impactFlash.CanQuery = false
	impactFlash.CastShadow = false
	impactFlash.Parent = model
	table.insert(partsToFade, impactFlash)

	createImpactSparks(endPos, -dir, config.outerColor, model)

	-- 3. Procedural trajectory calculation
	if config.isSniperRifle then
		-- Rifle Gauss Sniper: Central straight high-piercing beam + 2 spiraling electric plasma arcs
		local coreSeg = createNeonSegment(startPos, endPos, config.outerColor, config.width, model)
		if coreSeg then table.insert(partsToFade, coreSeg) end

		if config.hasCore and config.coreColor then
			local innerSeg = createNeonSegment(startPos, endPos, config.coreColor, config.width * 0.45, model)
			if innerSeg then table.insert(partsToFade, innerSeg) end
		end

		-- Generate 2 helical ionized crackle arcs coiling around the sniper path
		local helixSegments = 16
		local helixSeed1 = math.random() * 100
		local helixSeed2 = math.random() * 100
		local prevH1 = startPos
		local prevH2 = startPos

		for i = 1, helixSegments do
			local t = i / helixSegments
			local envelope = math.sin(t * math.pi)
			local angle = t * math.pi * 5 -- 2.5 full twists along the beam
			local radius = (0.5 + 0.3 * math.noise(t * 8 + helixSeed1, 0.5, 0.5)) * envelope

			local base = startPos + ray * t
			local spiral1 = right * math.cos(angle) * radius + up * math.sin(angle) * radius
			local spiral2 = right * math.cos(angle + math.pi) * radius + up * math.sin(angle + math.pi) * radius

			local curH1 = base + spiral1
			local curH2 = base + spiral2

			local segH1 = createNeonSegment(prevH1, curH1, config.outerColor, config.width * 0.4, model)
			if segH1 then table.insert(partsToFade, segH1) end

			local segH2 = createNeonSegment(prevH2, curH2, config.coreColor or config.outerColor, config.width * 0.3, model)
			if segH2 then table.insert(partsToFade, segH2) end

			prevH1 = curH1
			prevH2 = curH2
		end

	else
		-- Standard procedural Perlin noise lightning path
		local n = config.segments
		local seedX = math.random() * 200
		local seedY = math.random() * 200
		local seedZ = math.random() * 200

		local points: { Vector3 } = table.create(n + 1)
		points[1] = startPos

		for i = 1, n - 1 do
			local t = i / n
			local envelope = math.sin(t * math.pi)

			local nx = math.noise(t * config.frequency + seedX, 0.42, 0.17)
			local ny = math.noise(t * config.frequency + seedY, 0.84, 0.59)
			local nz = math.noise(t * config.frequency + seedZ, 0.13, 0.77)

			local jx = (math.random() - 0.5) * 2 * config.jitterAmp
			local jy = (math.random() - 0.5) * 2 * config.jitterAmp
			local jz = (math.random() - 0.5) * 2 * config.jitterAmp

			local perpDisp = (right * (nx * config.amplitude + jx) + up * (ny * config.amplitude + jy) + dir * (nz * 0.4 + jz)) * envelope
			local pt = startPos + ray * t + perpDisp
			points[i + 1] = pt
		end
		points[n + 1] = endPos

		-- Draw the main lightning segments
		for i = 1, n do
			local pA = points[i]
			local pB = points[i + 1]

			local outerSeg = createNeonSegment(pA, pB, config.outerColor, config.width, model)
			if outerSeg then table.insert(partsToFade, outerSeg) end

			if config.hasCore and config.coreColor then
				local innerSeg = createNeonSegment(pA, pB, config.coreColor, config.width * 0.45, model)
				if innerSeg then table.insert(partsToFade, innerSeg) end
			end

			-- Secondary branching fork logic for electric weapons (Taser, DarkStorm, Overdrive)
			if config.branches > 0 and (i == math.floor(n * 0.35) or i == math.floor(n * 0.65)) then
				if math.random() > 0.35 then
					local branchDir = (dir + right * (math.random() > 0.5 and 0.85 or -0.85) + up * (math.random() - 0.5)).Unit
					local branchPt = pA
					local branchLen = (dist / n) * 1.1
					local branchCount = math.random(2, 3)

					for _ = 1, branchCount do
						local nextBranchPt = branchPt + branchDir * branchLen + Vector3.new(
							(math.random() - 0.5) * 0.6,
							(math.random() - 0.5) * 0.6,
							(math.random() - 0.5) * 0.6
						)
						local bSeg = createNeonSegment(branchPt, nextBranchPt, config.outerColor, config.width * 0.55, model)
						if bSeg then table.insert(partsToFade, bSeg) end
						branchPt = nextBranchPt
					end
				end
			end
		end
	end

	-- 4. Fast high-energy fadeout animation and cleanup
	local fadeDuration = math.max(0.04, config.lifetime - 0.02)
	task.delay(0.02, function()
		if not model.Parent then return end

		for _, part in ipairs(partsToFade) do
			if part and part.Parent then
				local targetSize = Vector3.new(0.02, 0.02, part.Size.Z)
				if part.Shape == Enum.PartType.Ball then
					targetSize = part.Size * 1.6
				end
				local tw = TweenService:Create(part, TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 1,
					Size = targetSize,
				})
				tw:Play()
			end
		end

		if muzzleLight and muzzleLight.Parent then
			local lightTw = TweenService:Create(muzzleLight, TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Brightness = 0,
			})
			lightTw:Play()
		end

		task.delay(fadeDuration + 0.01, function()
			if model and model.Parent then
				model:Destroy()
			end
		end)
	end)
end

-- Procedural Burn Transfer Arc (replaces static line with dynamic flame plasma arc)
function ProceduralLightning.CreateBurnArc(startPos: Vector3, endPos: Vector3)
	ProceduralLightning.CreateBolt(
		startPos,
		endPos,
		"BurnTransfer",
		Color3.fromRGB(255, 110, 15),
		0.36
	)
end

return ProceduralLightning
