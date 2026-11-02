--!strict
-- HumanoidEnemyBuilder.luau: Builds stylized classic Roblox humanoid enemy characters
-- Features distinct archetype scales, combat palettes, role badges, and equipped weapons in hand.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnemiesData = require(Shared:WaitForChild("EnemiesData"))

local HumanoidEnemyBuilder = {}

export type BuiltEnemyData = {
	model: Model,
	rootPart: BasePart,
	fixedY: number,
	leftHip: Motor6D?,
	rightHip: Motor6D?,
	leftShoulder: Motor6D?,
	rightShoulder: Motor6D?,
	defaultLeftHipC0: CFrame,
	defaultRightHipC0: CFrame,
	defaultLeftShoulderC0: CFrame,
	defaultRightShoulderC0: CFrame,
	holdsWeaponRight: boolean,
	holdsWeaponLeft: boolean,
}

local ARCHETYPE_CONFIGS = {
	ScoutDrone = {
		scale = 0.82,
		roleBadge = "⚡",
		bodyColor = Color3.fromRGB(235, 45, 55),
		accentColor = Color3.fromRGB(35, 38, 48),
		visorColor = Color3.fromRGB(255, 60, 70),
		hasDualBlades = true,
		holdsRifle = false,
		holdsSniper = false,
		hasShield = false,
		hasBombPack = false,
		isBoss = false,
		isGold = false,
	},
	AssaultMecha = {
		scale = 1.05,
		roleBadge = "🔫",
		bodyColor = Color3.fromRGB(42, 85, 168),
		accentColor = Color3.fromRGB(45, 50, 62),
		visorColor = Color3.fromRGB(255, 140, 25),
		hasDualBlades = false,
		holdsRifle = true,
		holdsSniper = false,
		hasShield = false,
		hasBombPack = false,
		isBoss = false,
		isGold = false,
	},
	SniperBot = {
		scale = 1.18,
		roleBadge = "🎯",
		bodyColor = Color3.fromRGB(24, 25, 34),
		accentColor = Color3.fromRGB(60, 45, 80),
		visorColor = Color3.fromRGB(205, 45, 255),
		hasDualBlades = false,
		holdsRifle = false,
		holdsSniper = true,
		hasShield = false,
		hasBombPack = false,
		isBoss = false,
		isGold = false,
	},
	HeavyJuggernaut = {
		scale = 1.70,
		roleBadge = "🛡️",
		bodyColor = Color3.fromRGB(48, 54, 65),
		accentColor = Color3.fromRGB(28, 30, 36),
		visorColor = Color3.fromRGB(255, 35, 45),
		hasDualBlades = false,
		holdsRifle = false,
		holdsSniper = false,
		hasShield = true,
		hasBombPack = false,
		isBoss = false,
		isGold = false,
	},
	KamikazeRoller = {
		scale = 0.88,
		roleBadge = "💣",
		bodyColor = Color3.fromRGB(22, 24, 30),
		accentColor = Color3.fromRGB(255, 80, 20),
		visorColor = Color3.fromRGB(255, 100, 20),
		hasDualBlades = false,
		holdsRifle = false,
		holdsSniper = false,
		hasShield = false,
		hasBombPack = true,
		isBoss = false,
		isGold = false,
	},
	OverlordBoss = {
		scale = 2.45,
		roleBadge = "👑",
		bodyColor = Color3.fromRGB(85, 18, 28),
		accentColor = Color3.fromRGB(28, 30, 38),
		visorColor = Color3.fromRGB(255, 20, 60),
		hasDualBlades = false,
		holdsRifle = false,
		holdsSniper = false,
		hasShield = false,
		hasBombPack = false,
		isBoss = true,
		isGold = false,
	},
	MetaDrone = {
		scale = 0.88,
		roleBadge = "💰",
		bodyColor = Color3.fromRGB(255, 215, 0),
		accentColor = Color3.fromRGB(255, 240, 160),
		visorColor = Color3.fromRGB(255, 255, 120),
		hasDualBlades = false,
		holdsRifle = false,
		holdsSniper = false,
		hasShield = false,
		hasBombPack = false,
		isBoss = false,
		isGold = true,
	},
}

local function createPart(name: string, size: Vector3, color: Color3, material: Enum.Material, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.Anchored = false
	p.Massless = true
	p.CastShadow = true
	p.Parent = parent
	return p
end

local function createMotor6D(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame, parent: Instance): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1
	m.Parent = parent
	return m
end

local function weldTo(p0: BasePart, p1: BasePart, offset: CFrame)
	p1.CFrame = p0.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = p0
	w.Part1 = p1
	w.Parent = p1
end

function HumanoidEnemyBuilder.GetFixedY(enemyId: string): number
	local arch = ARCHETYPE_CONFIGS[enemyId]
	local scale = if arch then arch.scale else 1.0
	return 3.0 * scale
end

function HumanoidEnemyBuilder.GetRoleBadge(enemyId: string): string
	local arch = ARCHETYPE_CONFIGS[enemyId]
	return if arch then arch.roleBadge else "👾"
end

function HumanoidEnemyBuilder.Build(config: EnemiesData.EnemyConfig, spawnPos: Vector3): BuiltEnemyData
	local arch = ARCHETYPE_CONFIGS[config.id] or ARCHETYPE_CONFIGS.AssaultMecha
	local scale = arch.scale
	local fixedY = 3.0 * scale
	local centeredSpawn = Vector3.new(spawnPos.X, fixedY, spawnPos.Z)

	local model = Instance.new("Model")
	model.Name = config.name

	-- Humanoid (configured without default floating name to prevent UI overlap)
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = config.maxHealth
	humanoid.Health = config.maxHealth
	humanoid.WalkSpeed = config.moveSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	-- 1. HumanoidRootPart (Anchored root that receives Heartbeat CFrame updates)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * scale
	root.CFrame = CFrame.new(centeredSpawn)
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = true
	root.Massless = true
	root.Parent = model
	model.PrimaryPart = root

	-- 2. Torso
	local torsoMaterial = if arch.hasShield then Enum.Material.DiamondPlate else Enum.Material.Metal
	local torso = createPart("Torso", Vector3.new(2, 2, 1) * scale, arch.bodyColor, torsoMaterial, model)
	createMotor6D("RootJoint", root, torso, CFrame.identity, CFrame.identity, root)

	-- 3. Head & Cyber Visor
	local head = createPart("Head", Vector3.new(1.25, 1.25, 1.25) * scale, arch.accentColor, Enum.Material.SmoothPlastic, model)
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.2, 1.2, 1.2)
	headMesh.Parent = head
	createMotor6D("Neck", torso, head, CFrame.new(0, 1.5 * scale, 0), CFrame.new(0, 0, 0), torso)

	-- Glowing Visor
	local visor = createPart("Visor", Vector3.new(1.1, 0.35, 0.45) * scale, arch.visorColor, Enum.Material.Neon, model)
	weldTo(head, visor, CFrame.new(0, 0.1 * scale, -0.55 * scale))

	-- 4. Limbs
	local limbMaterial = Enum.Material.Metal
	local leftArm = createPart("LeftArm", Vector3.new(1, 2, 1) * scale, arch.accentColor, limbMaterial, model)
	local rightArm = createPart("RightArm", Vector3.new(1, 2, 1) * scale, arch.accentColor, limbMaterial, model)
	local leftLeg = createPart("LeftLeg", Vector3.new(1, 2, 1) * scale, arch.bodyColor, limbMaterial, model)
	local rightLeg = createPart("RightLeg", Vector3.new(1, 2, 1) * scale, arch.bodyColor, limbMaterial, model)

	-- Motor6D Joints
	local defLeftHipC0 = CFrame.new(-0.5 * scale, -1.0 * scale, 0)
	local defRightHipC0 = CFrame.new(0.5 * scale, -1.0 * scale, 0)
	local defLeftShoulderC0 = CFrame.new(-1.5 * scale, 0.5 * scale, 0)
	local defRightShoulderC0 = CFrame.new(1.5 * scale, 0.5 * scale, 0)

	local leftHip = createMotor6D("LeftHip", torso, leftLeg, defLeftHipC0, CFrame.new(0, 1.0 * scale, 0), torso)
	local rightHip = createMotor6D("RightHip", torso, rightLeg, defRightHipC0, CFrame.new(0, 1.0 * scale, 0), torso)
	local leftShoulder = createMotor6D("LeftShoulder", torso, leftArm, defLeftShoulderC0, CFrame.new(0, 0.5 * scale, 0), torso)
	local rightShoulder = createMotor6D("RightShoulder", torso, rightArm, defRightShoulderC0, CFrame.new(0, 0.5 * scale, 0), torso)

	local holdsWeaponRight = false
	local holdsWeaponLeft = false

	-- 5. Archetype Weaponry & Gear in hand
	if arch.hasDualBlades then
		-- Scout Drone: Dual glowing energy daggers
		local bladeR = createPart("EnergyBladeR", Vector3.new(0.25, 0.4, 2.4) * scale, arch.visorColor, Enum.Material.Neon, model)
		weldTo(rightArm, bladeR, CFrame.new(0, -1.0 * scale, -0.8 * scale))
		local bladeL = createPart("EnergyBladeL", Vector3.new(0.25, 0.4, 2.4) * scale, arch.visorColor, Enum.Material.Neon, model)
		weldTo(leftArm, bladeL, CFrame.new(0, -1.0 * scale, -0.8 * scale))

	elseif arch.holdsRifle then
		-- Assault Trooper: Blaster rifle held in right hand, aiming forward
		holdsWeaponRight = true
		defRightShoulderC0 = CFrame.new(1.2 * scale, 0.5 * scale, -0.2 * scale) * CFrame.Angles(math.rad(80), 0, math.rad(-15))
		rightShoulder.C0 = defRightShoulderC0

		local rifle = createPart("BlasterRifle", Vector3.new(0.45, 0.7, 2.4) * scale, Color3.fromRGB(25, 28, 35), Enum.Material.Metal, model)
		weldTo(rightArm, rifle, CFrame.new(0, -0.9 * scale, -0.8 * scale))
		local rifleGlow = createPart("RifleGlow", Vector3.new(0.25, 0.25, 1.4) * scale, arch.visorColor, Enum.Material.Neon, model)
		weldTo(rifle, rifleGlow, CFrame.new(0, 0.2 * scale, -0.2 * scale))

	elseif arch.holdsSniper then
		-- Sniper Marksman: Long-barrel precision laser sniper rifle
		holdsWeaponRight = true
		defRightShoulderC0 = CFrame.new(1.2 * scale, 0.5 * scale, -0.2 * scale) * CFrame.Angles(math.rad(85), 0, math.rad(-10))
		rightShoulder.C0 = defRightShoulderC0

		local sniperBody = createPart("SniperRifle", Vector3.new(0.4, 0.6, 3.8) * scale, Color3.fromRGB(18, 20, 26), Enum.Material.Metal, model)
		weldTo(rightArm, sniperBody, CFrame.new(0, -0.9 * scale, -1.2 * scale))
		local barrel = createPart("SniperBarrel", Vector3.new(0.25, 0.25, 1.8) * scale, arch.visorColor, Enum.Material.Neon, model)
		weldTo(sniperBody, barrel, CFrame.new(0, 0, -2.2 * scale))
		local scope = createPart("SniperScope", Vector3.new(0.35, 0.45, 0.9) * scale, Color3.fromRGB(35, 38, 50), Enum.Material.Metal, model)
		weldTo(sniperBody, scope, CFrame.new(0, 0.45 * scale, 0))

	elseif arch.hasShield then
		-- Heavy Juggernaut: Riot shield in left arm + heavy war club in right arm
		holdsWeaponLeft = true
		defLeftShoulderC0 = CFrame.new(-1.3 * scale, 0.5 * scale, -0.3 * scale) * CFrame.Angles(math.rad(30), math.rad(25), 0)
		leftShoulder.C0 = defLeftShoulderC0

		local shield = createPart("RiotShield", Vector3.new(2.4, 3.4, 0.5) * scale, Color3.fromRGB(36, 40, 50), Enum.Material.DiamondPlate, model)
		weldTo(leftArm, shield, CFrame.new(-0.3 * scale, 0, -0.6 * scale))
		local shieldCore = createPart("ShieldCore", Vector3.new(1.2, 1.2, 0.2) * scale, arch.visorColor, Enum.Material.Neon, model)
		weldTo(shield, shieldCore, CFrame.new(0, 0, -0.3 * scale))

		local club = createPart("HeavyClub", Vector3.new(0.6, 2.8, 0.6) * scale, Color3.fromRGB(25, 28, 35), Enum.Material.Metal, model)
		weldTo(rightArm, club, CFrame.new(0, -0.9 * scale, -0.4 * scale))

	elseif arch.hasBombPack then
		-- Kamikaze: Volatile reactor strapped to back + pulsing hazard core
		local tank = createPart("BombTank", Vector3.new(1.6, 2.2, 1.2) * scale, Color3.fromRGB(30, 32, 40), Enum.Material.Metal, model)
		weldTo(torso, tank, CFrame.new(0, 0.1 * scale, 0.85 * scale))
		local core = createPart("PulseCore", Vector3.new(1.1, 1.1, 1.1) * scale, arch.visorColor, Enum.Material.Neon, model)
		weldTo(tank, core, CFrame.new(0, 0, 0))

		local bLight = Instance.new("PointLight")
		bLight.Color = arch.visorColor
		bLight.Brightness = 3
		bLight.Range = 14 * scale
		bLight.Parent = core

		-- Flailing arms forward stance
		defLeftShoulderC0 = defLeftShoulderC0 * CFrame.Angles(math.rad(45), 0, math.rad(-15))
		defRightShoulderC0 = defRightShoulderC0 * CFrame.Angles(math.rad(45), 0, math.rad(15))
		leftShoulder.C0 = defLeftShoulderC0
		rightShoulder.C0 = defRightShoulderC0

	elseif arch.isBoss then
		-- Overlord Boss: Crown crest + twin dorsal shoulder cannons + dual blasters
		holdsWeaponRight = true
		holdsWeaponLeft = true
		defRightShoulderC0 = CFrame.new(1.5 * scale, 0.6 * scale, -0.2 * scale) * CFrame.Angles(math.rad(70), 0, math.rad(-10))
		defLeftShoulderC0 = CFrame.new(-1.5 * scale, 0.6 * scale, -0.2 * scale) * CFrame.Angles(math.rad(70), 0, math.rad(10))
		rightShoulder.C0 = defRightShoulderC0
		leftShoulder.C0 = defLeftShoulderC0

		local cannonL = createPart("ShoulderCannonL", Vector3.new(0.8, 0.8, 3.8) * scale, Color3.fromRGB(22, 25, 32), Enum.Material.Metal, model)
		weldTo(torso, cannonL, CFrame.new(-1.4 * scale, 1.2 * scale, 0.3 * scale))
		local cannonR = createPart("ShoulderCannonR", Vector3.new(0.8, 0.8, 3.8) * scale, Color3.fromRGB(22, 25, 32), Enum.Material.Metal, model)
		weldTo(torso, cannonR, CFrame.new(1.4 * scale, 1.2 * scale, 0.3 * scale))

		local gunL = createPart("HandCannonL", Vector3.new(0.6, 0.8, 2.8) * scale, Color3.fromRGB(30, 32, 40), Enum.Material.Metal, model)
		weldTo(leftArm, gunL, CFrame.new(0, -1.0 * scale, -0.8 * scale))
		local gunR = createPart("HandCannonR", Vector3.new(0.6, 0.8, 2.8) * scale, Color3.fromRGB(30, 32, 40), Enum.Material.Metal, model)
		weldTo(rightArm, gunR, CFrame.new(0, -1.0 * scale, -0.8 * scale))

		local bossLight = Instance.new("PointLight")
		bossLight.Color = arch.visorColor
		bossLight.Brightness = 4
		bossLight.Range = 28 * scale
		bossLight.Parent = torso

	elseif arch.isGold then
		-- Meta Loot Goblin: Golden loot pack + gold crystal staff
		local goldPack = createPart("GoldPack", Vector3.new(1.5, 1.8, 1.1) * scale, Color3.fromRGB(255, 215, 0), Enum.Material.SmoothPlastic, model)
		weldTo(torso, goldPack, CFrame.new(0, 0, 0.8 * scale))
		local crystal = createPart("LootCrystal", Vector3.new(0.8, 0.8, 0.8) * scale, Color3.fromRGB(255, 255, 120), Enum.Material.Neon, model)
		weldTo(goldPack, crystal, CFrame.new(0, 0, 0))

		local staff = createPart("GoldStaff", Vector3.new(0.25, 2.8, 0.25) * scale, Color3.fromRGB(220, 180, 0), Enum.Material.Metal, model)
		weldTo(rightArm, staff, CFrame.new(0, -0.8 * scale, -0.2 * scale))

		local gLight = Instance.new("PointLight")
		gLight.Color = Color3.fromRGB(255, 230, 80)
		gLight.Brightness = 3
		gLight.Range = 16 * scale
		gLight.Parent = crystal
	end

	return {
		model = model,
		rootPart = root,
		fixedY = fixedY,
		leftHip = leftHip,
		rightHip = rightHip,
		leftShoulder = leftShoulder,
		rightShoulder = rightShoulder,
		defaultLeftHipC0 = defLeftHipC0,
		defaultRightHipC0 = defRightHipC0,
		defaultLeftShoulderC0 = defLeftShoulderC0,
		defaultRightShoulderC0 = defRightShoulderC0,
		holdsWeaponRight = holdsWeaponRight,
		holdsWeaponLeft = holdsWeaponLeft,
	}
end

return HumanoidEnemyBuilder
