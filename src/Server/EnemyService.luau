--!strict
-- EnemyService.luau: Spawns, runs AI behaviors, handles collision, contact damage, burn ticks, and deaths

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnemiesData = require(Shared:WaitForChild("EnemiesData"))
local GameEvents = require(Shared:WaitForChild("GameEvents"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerStatsManager = require(script.Parent.PlayerStatsManager)

export type DashState = "NONE" | "PREP" | "CHARGING"

export type SpawnOverrides = {
	hpMult: number?,
	damageMult: number?,
	xpMult: number?,
	playerScale: number?,
}

export type ActiveEnemy = {
	model: Model,
	rootPart: BasePart,
	config: EnemiesData.EnemyConfig,
	currentHealth: number,
	maxHealth: number,
	contactDamage: number,
	bulletDamage: number,
	xpValue: number,
	metaClusterCount: number,
	isDead: boolean,
	lastContactTime: number,
	lastShootTime: number,
	burnStacks: number,
	burnTimer: number,
	targetPlayer: Player?,

	-- Exact kinematic position tracker (guarantees zero drift/jitter)
	currentPos: Vector3,

	-- AI Dash State Machine (TheSwarm EnemyAI)
	dashState: DashState,
	dashTimer: number,
	dashCooldownTimer: number,
	dashDirection: Vector3,
	dashDistanceTraveled: number,

	-- AI Shoot Charge State Machine
	shootCharging: boolean,
	shootChargeTimer: number,

	-- Visual Telegraph (Laser beam / ground strip)
	telegraphPart: BasePart?,
}

local EnemyService = {}
local activeEnemies: { [Model]: ActiveEnemy } = {}
local enemiesFolder: Folder

local function getEnemiesFolder(): Folder
	if not enemiesFolder or not enemiesFolder.Parent then
		local found = Workspace:FindFirstChild("ActiveEnemies") :: Folder?
		if not found then
			found = Instance.new("Folder")
			found.Name = "ActiveEnemies"
			found.Parent = Workspace
		end
		enemiesFolder = found
	end
	return enemiesFolder
end

local cachedTemplates: { [string]: Model? } = {}

local KEYWORD_MAPPINGS: { [string]: { string } } = {
	ScoutDrone = { "drone_worker", "droneworker", "cockpit_worker", "worker", "farmer", "scout", "minion_blue_melee", "minion_red_melee", "minion_melee", "enemy1" },
	AssaultMecha = { "drone_fighter", "dronefighter", "copter_fighter", "fighter", "assault", "gunner", "shooter", "minion_blue_ranged", "minion_red_ranged", "minion_ranged", "enemy3" },
	SniperBot = { "space_drone", "spacedrone", "sniper", "turret", "laserbot", "blaster", "shocker", "enemy2", "enemy5", "enemy6" },
	HeavyJuggernaut = { "spider", "tank", "heavy", "juggernaut", "brute", "colosse", "enemy4" },
	KamikazeRoller = { "roller", "kamikaze", "sphere", "bomb" },
	OverlordBoss = { "boss", "goliath", "overlord", "titan" },
	MetaDrone = { "enemyfarm", "base_turret", "metadrone", "goldendrone", "golddrone", "lootdrone" },
}

local function findCustomTemplate(enemyId: string): Model?
	if cachedTemplates[enemyId] ~= nil then
		return cachedTemplates[enemyId]
	end

	local keywords = KEYWORD_MAPPINGS[enemyId]
	if not keywords then
		cachedTemplates[enemyId] = nil
		return nil
	end

	local function matches(name: string): boolean
		local lower = string.lower(name)
		for _, kw in ipairs(keywords) do
			if string.find(lower, kw, 1, true) then
				return true
			end
		end
		return false
	end

	local containers = { ReplicatedStorage, ServerStorage, Workspace }
	for _, container in ipairs(containers) do
		for _, desc in ipairs(container:GetDescendants()) do
			if not desc:FindFirstAncestor("ActiveEnemies") and matches(desc.Name) then
				if desc:IsA("Model") then
					print(string.format("[EnemyService] Custom 3D Model detected for '%s': %s (%s)", enemyId, desc.Name, desc:GetFullName()))
					cachedTemplates[enemyId] = desc
					return desc
				elseif desc:IsA("Folder") then
					local m = Instance.new("Model")
					m.Name = desc.Name
					for _, c in ipairs(desc:GetChildren()) do
						c:Clone().Parent = m
					end
					print(string.format("[EnemyService] Custom 3D Folder converted for '%s': %s (%s)", enemyId, desc.Name, desc:GetFullName()))
					cachedTemplates[enemyId] = m
					return m
				elseif desc:IsA("MeshPart") and not desc.Parent:IsA("Model") then
					local m = Instance.new("Model")
					m.Name = desc.Name
					desc:Clone().Parent = m
					print(string.format("[EnemyService] Custom 3D MeshPart converted for '%s': %s (%s)", enemyId, desc.Name, desc:GetFullName()))
					cachedTemplates[enemyId] = m
					return m
				end
			end
		end
	end

	cachedTemplates[enemyId] = nil
	return nil
end

local function getEnemyFixedY(enemyId: string, sizeY: number): number
	if enemyId == "ScoutDrone" or enemyId == "MetaDrone" then
		return 3.0 + (sizeY * 0.5)
	end
	return sizeY * 0.5 + 0.05
end

local function createHealthUI(adornee: BasePart, heightOffset: number, isBoss: boolean): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthUI"
	billboard.Adornee = adornee
	billboard.Size = if isBoss then UDim2.new(0, 110, 0, 10) else UDim2.new(0, 70, 0, 8)
	billboard.StudsOffset = Vector3.new(0, heightOffset + 1.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = adornee

	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = bg

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.new(1, 0, 1, 0)
	bar.BackgroundColor3 = if isBoss then Color3.fromRGB(255, 45, 65) else Color3.fromRGB(80, 255, 120)
	bar.BorderSizePixel = 0
	bar.Parent = bg

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0.5, 0)
	barCorner.Parent = bar

	return billboard
end

local function buildProceduralEnemy(config: EnemiesData.EnemyConfig, spawnPos: Vector3): (Model, BasePart, Vector3)
	local model = Instance.new("Model")
	model.Name = config.name

	local fixedY = getEnemyFixedY(config.id, config.size.Y)
	local centeredSpawn = Vector3.new(spawnPos.X, fixedY, spawnPos.Z)

	-- Root Part
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = config.size
	root.CFrame = CFrame.new(centeredSpawn)
	root.Color = config.color
	root.Material = Enum.Material.Metal
	root.CanCollide = false
	root.Anchored = true
	root.Parent = model
	model.PrimaryPart = root

	local id = config.id

	if id == "ScoutDrone" then
		root.Size = Vector3.new(1.8, 1.2, 1.8)
		root.Color = Color3.fromRGB(35, 40, 50)

		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.6, 0.4, 0.5)
		eye.CFrame = CFrame.new(centeredSpawn + Vector3.new(0, 0, -0.85))
		eye.Color = Color3.fromRGB(255, 30, 40)
		eye.Material = Enum.Material.Neon
		eye.CanCollide = false
		eye.Anchored = true
		eye.Parent = model

		local wingL = Instance.new("Part")
		wingL.Name = "WingL"
		wingL.Size = Vector3.new(0.8, 0.15, 1.2)
		wingL.CFrame = CFrame.new(centeredSpawn + Vector3.new(-1.1, 0.1, 0))
		wingL.Color = Color3.fromRGB(255, 50, 60)
		wingL.Material = Enum.Material.Neon
		wingL.CanCollide = false
		wingL.Anchored = true
		wingL.Parent = model

		local wingR = Instance.new("Part")
		wingR.Name = "WingR"
		wingR.Size = Vector3.new(0.8, 0.15, 1.2)
		wingR.CFrame = CFrame.new(centeredSpawn + Vector3.new(1.1, 0.1, 0))
		wingR.Color = Color3.fromRGB(255, 50, 60)
		wingR.Material = Enum.Material.Neon
		wingR.CanCollide = false
		wingR.Anchored = true
		wingR.Parent = model

	elseif id == "AssaultMecha" then
		root.Size = Vector3.new(2.2, 3.0, 1.8)
		root.Color = Color3.fromRGB(45, 50, 62)

		local visor = Instance.new("Part")
		visor.Name = "Visor"
		visor.Size = Vector3.new(1.4, 0.5, 0.5)
		visor.CFrame = CFrame.new(centeredSpawn + Vector3.new(0, 0.9, -0.85))
		visor.Color = Color3.fromRGB(255, 130, 20)
		visor.Material = Enum.Material.Neon
		visor.CanCollide = false
		visor.Anchored = true
		visor.Parent = model

		local core = Instance.new("Part")
		core.Name = "Core"
		core.Size = Vector3.new(1.0, 1.0, 0.3)
		core.CFrame = CFrame.new(centeredSpawn + Vector3.new(0, 0.1, -0.9))
		core.Color = Color3.fromRGB(255, 80, 20)
		core.Material = Enum.Material.Neon
		core.CanCollide = false
		core.Anchored = true
		core.Parent = model

		local gunL = Instance.new("Part")
		gunL.Name = "GunL"
		gunL.Size = Vector3.new(0.4, 0.4, 2.0)
		gunL.CFrame = CFrame.new(centeredSpawn + Vector3.new(-1.4, 0.5, -0.5))
		gunL.Color = Color3.fromRGB(20, 22, 28)
		gunL.Material = Enum.Material.Metal
		gunL.CanCollide = false
		gunL.Anchored = true
		gunL.Parent = model

		local gunR = Instance.new("Part")
		gunR.Name = "GunR"
		gunR.Size = Vector3.new(0.4, 0.4, 2.0)
		gunR.CFrame = CFrame.new(centeredSpawn + Vector3.new(1.4, 0.5, -0.5))
		gunR.Color = Color3.fromRGB(20, 22, 28)
		gunR.Material = Enum.Material.Metal
		gunR.CanCollide = false
		gunR.Anchored = true
		gunR.Parent = model
		gunR.Material = Enum.Material.Metal
		gunR.CanCollide = false
		gunR.Anchored = true
		gunR.Parent = model

	elseif id == "SniperBot" then
		root.Size = Vector3.new(2.2, 3.8, 2.2)
		root.Color = Color3.fromRGB(38, 30, 52)

		local barrel = Instance.new("Part")
		barrel.Name = "LaserBarrel"
		barrel.Size = Vector3.new(0.4, 0.4, 3.6)
		barrel.CFrame = CFrame.new(centeredSpawn + Vector3.new(0, 0.8, -1.6))
		barrel.Color = Color3.fromRGB(210, 40, 255)
		barrel.Material = Enum.Material.Neon
		barrel.CanCollide = false
		barrel.Anchored = true
		barrel.Parent = model

		local eye = Instance.new("Part")
		eye.Name = "SniperEye"
		eye.Size = Vector3.new(0.8, 0.8, 0.6)
		eye.CFrame = CFrame.new(centeredSpawn + Vector3.new(0, 1.3, -0.9))
		eye.Color = Color3.fromRGB(230, 80, 255)
		eye.Material = Enum.Material.Neon
		eye.CanCollide = false
		eye.Anchored = true
		eye.Parent = model

	elseif id == "HeavyJuggernaut" then
		root.Size = Vector3.new(4.8, 5.0, 4.8)
		root.Color = Color3.fromRGB(28, 30, 38)

		local shield = Instance.new("Part")
		shield.Name = "Shield"
		shield.Size = Vector3.new(5.0, 3.8, 0.8)
		shield.CFrame = CFrame.new(centeredSpawn + Vector3.new(0, 0, -2.4))
		shield.Color = Color3.fromRGB(42, 48, 58)
		shield.Material = Enum.Material.DiamondPlate
		shield.CanCollide = false
		shield.Anchored = true
		shield.Parent = model

		local core = Instance.new("Part")
		core.Name = "PowerCore"
		core.Size = Vector3.new(2.0, 2.0, 0.8)
		core.CFrame = CFrame.new(centeredSpawn + Vector3.new(0, 0.4, -2.5))
		core.Color = Color3.fromRGB(255, 40, 60)
		core.Material = Enum.Material.Neon
		core.CanCollide = false
		core.Anchored = true
		core.Parent = model

	elseif id == "KamikazeRoller" then
		root.Size = Vector3.new(2.6, 2.6, 2.6)
		root.Shape = Enum.PartType.Ball
		root.Color = Color3.fromRGB(220, 25, 25)
		root.Material = Enum.Material.Metal

		local pulse = Instance.new("Part")
		pulse.Name = "PulseCore"
		pulse.Size = Vector3.new(1.6, 1.6, 1.6)
		pulse.Shape = Enum.PartType.Ball
		pulse.CFrame = CFrame.new(centeredSpawn)
		pulse.Color = Color3.fromRGB(255, 220, 30)
		pulse.Material = Enum.Material.Neon
		pulse.CanCollide = false
		pulse.Anchored = true
		pulse.Parent = model

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 50, 20)
		light.Brightness = 3
		light.Range = 12
		light.Parent = pulse

	elseif id == "OverlordBoss" then
		root.Size = Vector3.new(7.6, 8.2, 7.6)
		root.Color = Color3.fromRGB(16, 18, 25)

		local bossCore = Instance.new("Part")
		bossCore.Name = "BossCore"
		bossCore.Size = Vector3.new(3.4, 3.4, 1.6)
		bossCore.CFrame = CFrame.new(centeredSpawn + Vector3.new(0, 0.5, -3.6))
		bossCore.Color = Color3.fromRGB(255, 0, 80)
		bossCore.Material = Enum.Material.Neon
		bossCore.CanCollide = false
		bossCore.Anchored = true
		bossCore.Parent = model

		local cannonL = Instance.new("Part")
		cannonL.Name = "CannonL"
		cannonL.Size = Vector3.new(1.2, 1.2, 5.0)
		cannonL.CFrame = CFrame.new(centeredSpawn + Vector3.new(-4.0, 1.8, -1.5))
		cannonL.Color = Color3.fromRGB(30, 35, 45)
		cannonL.Material = Enum.Material.Metal
		cannonL.CanCollide = false
		cannonL.Anchored = true
		cannonL.Parent = model

		local cannonR = Instance.new("Part")
		cannonR.Name = "CannonR"
		cannonR.Size = Vector3.new(1.2, 1.2, 5.0)
		cannonR.CFrame = CFrame.new(centeredSpawn + Vector3.new(4.0, 1.8, -1.5))
		cannonR.Color = Color3.fromRGB(30, 35, 45)
		cannonR.Material = Enum.Material.Metal
		cannonR.CanCollide = false
		cannonR.Anchored = true
		cannonR.Parent = model

		local bLight = Instance.new("PointLight")
		bLight.Color = Color3.fromRGB(255, 20, 60)
		bLight.Brightness = 4
		bLight.Range = 28
		bLight.Parent = bossCore

	elseif id == "MetaDrone" then
		root.Size = Vector3.new(2.8, 2.8, 2.8)
		root.Shape = Enum.PartType.Ball
		root.Color = Color3.fromRGB(255, 215, 0)
		root.Material = Enum.Material.Neon

		local ring = Instance.new("Part")
		ring.Name = "GoldRing"
		ring.Size = Vector3.new(4.2, 0.25, 4.2)
		ring.Shape = Enum.PartType.Cylinder
		ring.Orientation = Vector3.new(0, 0, 90)
		ring.CFrame = CFrame.new(centeredSpawn)
		ring.Color = Color3.fromRGB(255, 180, 0)
		ring.Material = Enum.Material.Neon
		ring.CanCollide = false
		ring.Anchored = true
		ring.Parent = model

		local mLight = Instance.new("PointLight")
		mLight.Color = Color3.fromRGB(255, 220, 50)
		mLight.Brightness = 3
		mLight.Range = 16
		mLight.Parent = root
	end

	createHealthUI(root, config.size.Y * 0.7, config.isBoss)
	model.Parent = getEnemiesFolder()

	return model, root, centeredSpawn
end

local function createEnemyModel(config: EnemiesData.EnemyConfig, spawnPos: Vector3): (Model, BasePart, Vector3)
	local customTemplate = findCustomTemplate(config.id)

	if customTemplate then
		local model = customTemplate:Clone()
		model.Name = config.name

		-- Anchor all parts immediately
		for _, desc in ipairs(model:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.CanCollide = false
				desc.Anchored = true
			end
		end

		-- CRITICAL: Auto-scale the imported FBX down to match config.size!
		local rawExtents = model:GetExtentsSize()
		local maxRaw = math.max(rawExtents.X, rawExtents.Y, rawExtents.Z)
		local targetMax = math.max(config.size.X, config.size.Y, config.size.Z)

		if maxRaw > 0.05 and targetMax > 0.05 then
			local scaleRatio = targetMax / maxRaw
			model:ScaleTo(scaleRatio)
			print(string.format("[EnemyService] Scaled '%s' model by %.4f (from %.1f to %.1f studs)", config.id, scaleRatio, maxRaw, targetMax))
		end

		local bbCFrame, bbSize = model:GetBoundingBox()

		-- Clean, centered HumanoidRootPart directly at the model's true geometric center
		local existingHrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		local root: BasePart
		if existingHrp then
			root = existingHrp
			root.Size = config.size
		else
			root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Size = config.size
			root.CFrame = bbCFrame
			root.Transparency = 1
			root.CanCollide = false
			root.Anchored = true
			root.Parent = model
		end

		model.PrimaryPart = root
		model.WorldPivot = root.CFrame
		root.PivotOffset = CFrame.identity

		local isFlying = (config.id == "ScoutDrone" or config.id == "MetaDrone")
		local fixedY = if isFlying then (3.0 + config.size.Y * 0.5) else (config.size.Y * 0.5 + 0.05)
		local centeredSpawn = Vector3.new(spawnPos.X, fixedY, spawnPos.Z)

		model:PivotTo(CFrame.new(centeredSpawn))
		createHealthUI(root, config.size.Y * 0.7, config.isBoss)
		model.Parent = getEnemiesFolder()

		return model, root, centeredSpawn
	end

	return buildProceduralEnemy(config, spawnPos)
end

function EnemyService.SpawnEnemy(configId: string, spawnPosition: Vector3, overrides: SpawnOverrides?): ActiveEnemy?
	local config = EnemiesData.GetEnemy(configId)
	if not config then return nil end

	local model, rootPart, centeredSpawn = createEnemyModel(config, spawnPosition)

	local hpMult = if overrides and overrides.hpMult then overrides.hpMult else 1.0
	local dmgMult = if overrides and overrides.damageMult then overrides.damageMult else 1.0
	local xpMult = if overrides and overrides.xpMult then overrides.xpMult else 1.0
	local playerScale = if overrides and overrides.playerScale then math.max(1, overrides.playerScale) else 1

	local scaledMaxHP = math.max(1, math.floor(config.maxHealth * hpMult * (if config.isBoss then playerScale else 1)))
	local scaledContactDmg = config.contactDamage * dmgMult
	local scaledBulletDmg = config.bulletDamage * dmgMult
	local scaledXP = if config.isMetaEnemy then config.xpValue else (config.xpValue * xpMult * (if config.isBoss then playerScale else 1))
	local scaledMetaClusters = 6 * playerScale

	local enemy: ActiveEnemy = {
		model = model,
		rootPart = rootPart,
		config = config,
		currentHealth = scaledMaxHP,
		maxHealth = scaledMaxHP,
		contactDamage = scaledContactDmg,
		bulletDamage = scaledBulletDmg,
		xpValue = scaledXP,
		metaClusterCount = scaledMetaClusters,
		isDead = false,
		lastContactTime = 0,
		lastShootTime = 0,
		burnStacks = 0,
		burnTimer = 0,
		targetPlayer = nil,

		currentPos = centeredSpawn,

		dashState = "NONE",
		dashTimer = 0,
		dashCooldownTimer = math.random() * 1.5,
		dashDirection = Vector3.zero,
		dashDistanceTraveled = 0,

		shootCharging = false,
		shootChargeTimer = 0,

		telegraphPart = nil,
	}

	activeEnemies[model] = enemy
	return enemy
end

function EnemyService.ClearAllEnemies()
	for model, enemy in pairs(activeEnemies) do
		enemy.isDead = true
		if enemy.telegraphPart then
			enemy.telegraphPart:Destroy()
			enemy.telegraphPart = nil
		end
		if model and model.Parent then
			model:Destroy()
		end
		activeEnemies[model] = nil
	end
end

function EnemyService.GetActiveEnemies(): { [Model]: ActiveEnemy }
	return activeEnemies
end

function EnemyService.GetClosestEnemy(fromPos: Vector3, maxRange: number): ActiveEnemy?
	local closest: ActiveEnemy? = nil
	local closestDistSq = maxRange * maxRange

	for _, enemy in pairs(activeEnemies) do
		if not enemy.isDead and enemy.rootPart and enemy.rootPart.Parent then
			local ePos = enemy.currentPos or enemy.rootPart.Position
			local dx = ePos.X - fromPos.X
			local dz = ePos.Z - fromPos.Z
			local distSq = dx * dx + dz * dz
			if distSq < closestDistSq then
				closestDistSq = distSq
				closest = enemy
			end
		end
	end

	return closest
end

function EnemyService.GetClosestEnemies(fromPos: Vector3, maxRange: number, maxCount: number): { ActiveEnemy }
	local list = {}
	local rSq = maxRange * maxRange

	for _, enemy in pairs(activeEnemies) do
		if not enemy.isDead and enemy.rootPart and enemy.rootPart.Parent then
			local ePos = enemy.currentPos or enemy.rootPart.Position
			local dx = ePos.X - fromPos.X
			local dz = ePos.Z - fromPos.Z
			local distSq = dx * dx + dz * dz
			if distSq <= rSq then
				table.insert(list, { enemy = enemy, distSq = distSq })
			end
		end
	end
	table.sort(list, function(a, b) return a.distSq < b.distSq end)

	local result = {}
	for i = 1, math.min(maxCount, #list) do
		table.insert(result, list[i].enemy)
	end
	return result
end

function EnemyService.GetFocusedEnemies(fromPos: Vector3, maxRange: number, maxCount: number): { ActiveEnemy }
	if maxCount <= 0 then return {} end
	local inRange = {}
	local firstEnemy: ActiveEnemy? = nil
	local minFirstDistSq = maxRange * maxRange

	for _, enemy in pairs(activeEnemies) do
		if not enemy.isDead and enemy.rootPart and enemy.rootPart.Parent then
			local ePos = enemy.currentPos or enemy.rootPart.Position
			local dx = ePos.X - fromPos.X
			local dz = ePos.Z - fromPos.Z
			local distSq = dx * dx + dz * dz
			if distSq <= (maxRange * maxRange) then
				table.insert(inRange, enemy)
				if distSq < minFirstDistSq then
					minFirstDistSq = distSq
					firstEnemy = enemy
				end
			end
		end
	end

	if not firstEnemy or not firstEnemy.rootPart then return {} end

	local result = { firstEnemy }
	if maxCount == 1 or #inRange <= 1 then
		return result
	end

	local firstPos = firstEnemy.currentPos or firstEnemy.rootPart.Position
	local others = {}
	for _, e in ipairs(inRange) do
		if e ~= firstEnemy and e.rootPart then
			local ePos = e.currentPos or e.rootPart.Position
			local dx = ePos.X - firstPos.X
			local dz = ePos.Z - firstPos.Z
			table.insert(others, { enemy = e, distSq = dx * dx + dz * dz })
		end
	end
	table.sort(others, function(a, b) return a.distSq < b.distSq end)

	for i = 1, math.min(maxCount - 1, #others) do
		table.insert(result, others[i].enemy)
	end
	return result
end

function EnemyService.GetEnemiesInRange(fromPos: Vector3, radius: number): { ActiveEnemy }
	local result: { ActiveEnemy } = {}
	local rSq = radius * radius

	for _, enemy in pairs(activeEnemies) do
		if not enemy.isDead and enemy.rootPart and enemy.rootPart.Parent then
			local ePos = enemy.currentPos or enemy.rootPart.Position
			local dx = ePos.X - fromPos.X
			local dz = ePos.Z - fromPos.Z
			if (dx * dx + dz * dz) <= rSq then
				table.insert(result, enemy)
			end
		end
	end

	return result
end

function EnemyService.TakeDamage(enemy: ActiveEnemy, amount: number, isCrit: boolean, attacker: Player?)
	if enemy.isDead then return end

	enemy.currentHealth = math.max(0, enemy.currentHealth - amount)

	-- Update Health Bar UI
	if enemy.rootPart and enemy.rootPart.Parent then
		local billboard = enemy.rootPart:FindFirstChild("HealthUI")
		if billboard then
			local bg = billboard:FindFirstChild("BG")
			if bg then
				local bar = bg:FindFirstChild("Bar") :: Frame?
				if bar then
					bar.Size = UDim2.new(math.clamp(enemy.currentHealth / enemy.maxHealth, 0, 1), 0, 1, 0)
				end
			end
		end

		-- Floating Combat Text
		local fPos = enemy.rootPart.Position + Vector3.new(0, enemy.config.size.Y * 0.5 + 1.5, 0)
		local textColor = if isCrit then Color3.fromRGB(255, 180, 20) else Color3.fromRGB(255, 255, 255)
		local text = if isCrit then string.format("CRIT! %.0f", amount) else string.format("%.0f", amount)
		Remotes.GetEvent("FloatingText"):FireAllClients(fPos, text, textColor, isCrit)
	end

	if attacker then
		GameEvents.OnDamageDealt:Fire(attacker, amount, isCrit, enemy)
		if isCrit then
			GameEvents.OnCritHit:Fire(attacker, amount, enemy)
		end

		-- LifeSteal calculation
		local pData = PlayerStatsManager.GetPlayerData(attacker)
		if pData and pData.currentStats.LifeSteal > 0 then
			local healAmount = amount * pData.currentStats.LifeSteal
			if healAmount >= 1 then
				PlayerStatsManager.Heal(attacker, healAmount)
			end
		end
	end

	if enemy.currentHealth <= 0 then
		EnemyService.KillEnemy(enemy, attacker)
	end
end

function EnemyService.ApplyBurn(enemy: ActiveEnemy, stacks: number, player: Player?)
	if enemy.isDead then return end
	enemy.burnStacks += stacks
end

function EnemyService.KillEnemy(enemy: ActiveEnemy, killer: Player?)
	if enemy.isDead then return end
	enemy.isDead = true

	if enemy.telegraphPart then
		enemy.telegraphPart:Destroy()
		enemy.telegraphPart = nil
	end

	activeEnemies[enemy.model] = nil

	local deathPos = if enemy.rootPart then enemy.rootPart.Position else Vector3.zero

	-- Death visual
	Remotes.GetEvent("VFXEvent"):FireAllClients("EnemyDeath", deathPos, enemy.config.color, enemy.config.isBoss)

	-- Signal event
	GameEvents.OnEnemyKilled:Fire(enemy.config, killer)

	-- Burn Transfer: If dying enemy was burning, propagate stacks to nearest alive foe
	if enemy.burnStacks > 0 and deathPos ~= Vector3.zero then
		local closestEnemy: ActiveEnemy? = nil
		local closestDist = 30.0 -- 30 studs search radius (matching TheSwarm BurnTransfer 25f)
		for _, other in pairs(activeEnemies) do
			if other ~= enemy and not other.isDead and other.rootPart then
				local dist = (other.rootPart.Position - deathPos).Magnitude
				if dist < closestDist then
					closestDist = dist
					closestEnemy = other
				end
			end
		end

		if closestEnemy and closestEnemy.rootPart then
			closestEnemy.burnStacks += enemy.burnStacks
			Remotes.GetEvent("VFXEvent"):FireAllClients("BurnTransfer", deathPos, closestEnemy.rootPart.Position)
			Remotes.GetEvent("FloatingText"):FireAllClients(
				closestEnemy.rootPart.Position + Vector3.new(0, 3, 0),
				string.format("+%d BRÛLURE", enemy.burnStacks),
				Color3.fromRGB(255, 120, 20),
				false
			)
		end
	end

	-- Spawn XP Gem (using zone-scaled xpValue)
	local XPService = require(script.Parent.XPService)
	XPService.SpawnGem(deathPos, enemy.xpValue, enemy.config.isMetaEnemy)

	if enemy.config.isBoss then
		-- Boss drops extra cluster of gems scaled by playerScale!
		for i = 1, (enemy.metaClusterCount or 6) do
			local offset = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
			XPService.SpawnGem(deathPos + offset, 10, true)
		end
	end

	enemy.model:Destroy()
end

-- Nearest alive player helper
local function getNearestPlayer(pos: Vector3): (Player?, Vector3?, number)
	local nearest: Player? = nil
	local nearestPos: Vector3? = nil
	local minDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local pData = PlayerStatsManager.GetPlayerData(player)
		if pData and not pData.isDead and not PlayerStatsManager.IsPhasedOut(player) then
			local char = player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local pPos = (char:FindFirstChild("HumanoidRootPart") :: BasePart).Position
				local dist = (pPos - pos).Magnitude
				if dist < minDistance then
					minDistance = dist
					nearest = player
					nearestPos = pPos
				end
			end
		end
	end

	return nearest, nearestPos, minDistance
end

local function updateOrCreateDashTelegraph(enemy: ActiveEnemy, startPos: Vector3, dir: Vector3, distance: number, width: number)
	local targetPos = startPos + dir * distance
	local midPos = startPos + dir * (distance * 0.5)

	if enemy.telegraphPart and enemy.telegraphPart.Parent then
		enemy.telegraphPart.Size = Vector3.new(width, 0.05, distance)
		enemy.telegraphPart.CFrame = CFrame.lookAt(Vector3.new(midPos.X, 0.1, midPos.Z), Vector3.new(targetPos.X, 0.1, targetPos.Z))
	else
		local p = Instance.new("Part")
		p.Name = "DashTelegraph"
		p.Size = Vector3.new(width, 0.05, distance)
		p.CFrame = CFrame.lookAt(Vector3.new(midPos.X, 0.1, midPos.Z), Vector3.new(targetPos.X, 0.1, targetPos.Z))
		p.Color = Color3.fromRGB(255, 30, 40)
		p.Material = Enum.Material.Neon
		p.Transparency = 0.50
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.Parent = Workspace
		enemy.telegraphPart = p
	end
end

local function updateOrCreateLaserTelegraph(enemy: ActiveEnemy, startPos: Vector3, targetPos: Vector3)
	local dist = (targetPos - startPos).Magnitude
	local midPos = (startPos + targetPos) * 0.5

	if enemy.telegraphPart and enemy.telegraphPart.Parent then
		enemy.telegraphPart.Size = Vector3.new(0.12, 0.12, dist)
		enemy.telegraphPart.CFrame = CFrame.lookAt(midPos, targetPos)
	else
		local p = Instance.new("Part")
		p.Name = "LaserTelegraph"
		p.Size = Vector3.new(0.12, 0.12, dist)
		p.CFrame = CFrame.lookAt(midPos, targetPos)
		p.Color = Color3.fromRGB(255, 30, 40)
		p.Material = Enum.Material.Neon
		p.Transparency = 0.35
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.Parent = Workspace
		enemy.telegraphPart = p
	end
end

-- Heartbeat AI loop (Modular state machine matching TheSwarm EnemyAI.cs)
RunService.Heartbeat:Connect(function(dt: number)
	local now = os.clock()

	for model, enemy in pairs(activeEnemies) do
		if enemy.isDead or not enemy.rootPart or not enemy.rootPart.Parent then
			if enemy.telegraphPart then
				enemy.telegraphPart:Destroy()
				enemy.telegraphPart = nil
			end
			activeEnemies[model] = nil
			continue
		end

		local root = enemy.rootPart
		local ePos = enemy.currentPos
		local cfg = enemy.config

		-- Burn DoT tick every 0.5s
		if enemy.burnStacks > 0 then
			enemy.burnTimer += dt
			if enemy.burnTimer >= 0.5 then
				enemy.burnTimer = 0
				local burnDmg = math.max(1, enemy.burnStacks * 1.5)
				enemy.currentHealth = math.max(0, enemy.currentHealth - burnDmg)

				local fPos = ePos + Vector3.new(0, cfg.size.Y * 0.5 + 1.2, 0)
				Remotes.GetEvent("FloatingText"):FireAllClients(fPos, string.format("%.0f", burnDmg), Color3.fromRGB(255, 100, 20), false)

				if enemy.currentHealth <= 0 then
					EnemyService.KillEnemy(enemy, enemy.targetPlayer)
					continue
				end
			end
		end

		-- Target nearest player
		local targetPlayer, targetPos, dist = getNearestPlayer(ePos)
		enemy.targetPlayer = targetPlayer

		if not targetPos or not targetPlayer then
			if enemy.telegraphPart then
				enemy.telegraphPart:Destroy()
				enemy.telegraphPart = nil
			end
			continue
		end

		local moveDir = Vector3.zero
		local moveSpeed = cfg.moveSpeed
		local flatDir = Vector3.zero

		local toTarget = (targetPos - ePos)
		local flatDist = Vector2.new(toTarget.X, toTarget.Z).Magnitude
		if flatDist > 0.05 then
			flatDir = Vector3.new(toTarget.X, 0, toTarget.Z).Unit
		end

		-- --- 1. DASH STATE MACHINE (TheSwarm PREP -> CHARGING -> NONE) ---
		if enemy.dashState == "PREP" then
			-- Immobile charging phase: ABSOLUTELY ZERO MOVEMENT
			moveDir = Vector3.zero
			if enemy.dashTimer > cfg.dashLockTime then
				enemy.dashDirection = flatDir -- Continuously track player until lock window
			end
			updateOrCreateDashTelegraph(enemy, ePos, enemy.dashDirection, cfg.dashDistance, 2.2)

			enemy.dashTimer -= dt
			if enemy.dashTimer <= 0 then
				if enemy.telegraphPart then
					enemy.telegraphPart:Destroy()
					enemy.telegraphPart = nil
				end
				enemy.dashState = "CHARGING"
				enemy.dashDistanceTraveled = 0
			end

		elseif enemy.dashState == "CHARGING" then
			-- Surging forward at high velocity along locked direction
			local step = cfg.dashSpeed * dt
			if enemy.dashDistanceTraveled + step > cfg.dashDistance then
				step = cfg.dashDistance - enemy.dashDistanceTraveled
			end
			enemy.dashDistanceTraveled += step
			enemy.currentPos += enemy.dashDirection * step

			-- Contact during dash deals boosted damage (1.5x)
			if flatDist <= (cfg.size.X * 0.5 + 2.5) and (now - enemy.lastContactTime >= 0.3) then
				enemy.lastContactTime = now
				PlayerStatsManager.TakeDamage(targetPlayer, enemy.contactDamage * 1.5, enemy)

				if cfg.behavior == "KAMIKAZE" then
					Remotes.GetEvent("VFXEvent"):FireAllClients("Explosion", ePos, 14, Color3.fromRGB(255, 60, 20))
					EnemyService.KillEnemy(enemy, nil)
					continue
				end
			end

			if enemy.dashDistanceTraveled >= cfg.dashDistance then
				enemy.dashState = "NONE"
				enemy.dashCooldownTimer = cfg.dashCooldown
				if cfg.behavior == "KAMIKAZE" then
					Remotes.GetEvent("VFXEvent"):FireAllClients("Explosion", ePos, 14, Color3.fromRGB(255, 60, 20))
					EnemyService.KillEnemy(enemy, nil)
					continue
				end
			end

		else
			-- Dash state is NONE: Zone AI & trigger checks
			enemy.dashCooldownTimer -= dt

			-- Check if enemy should trigger a Dash
			if cfg.canDash and flatDist <= cfg.dashRange and enemy.dashCooldownTimer <= 0 then
				enemy.dashState = "PREP"
				enemy.dashTimer = cfg.dashPrepTime
				enemy.dashDirection = flatDir
				enemy.dashDistanceTraveled = 0
				updateOrCreateDashTelegraph(enemy, ePos, enemy.dashDirection, cfg.dashDistance, 2.2)

			elseif cfg.canShoot and flatDist <= cfg.shootRange then
				-- SHOOTING BEHAVIOR (SniperBot or OverlordBoss)
				if cfg.fleeRange > 0 and flatDist < cfg.fleeRange then
					-- Too close: retreat to maintain optimal firing distance
					moveDir = -flatDir
					moveSpeed = cfg.fleeSpeed
					if enemy.telegraphPart then
						enemy.telegraphPart:Destroy()
						enemy.telegraphPart = nil
					end
					enemy.shootCharging = false
					enemy.shootChargeTimer = 0
				else
					-- Stand in place and charge sniper laser
					moveDir = Vector3.zero
					if now - enemy.lastShootTime >= cfg.shootCooldown then
						if not enemy.shootCharging then
							enemy.shootCharging = true
							enemy.shootChargeTimer = 0
						end

						enemy.shootChargeTimer += dt
						updateOrCreateLaserTelegraph(enemy, ePos + Vector3.new(0, 1.5, 0), targetPos + Vector3.new(0, 1.5, 0))

						if enemy.shootChargeTimer >= cfg.shootChargeTime then
							if enemy.telegraphPart then
								enemy.telegraphPart:Destroy()
								enemy.telegraphPart = nil
							end
							enemy.shootCharging = false
							enemy.shootChargeTimer = 0
							enemy.lastShootTime = now

							-- Spawn projectile
							local ProjectileService = require(script.Parent.ProjectileService)
							if cfg.behavior == "BOSS" then
								local baseAngle = math.atan2(flatDir.Z, flatDir.X)
								for _, angleOffset in ipairs({ -0.22, 0, 0.22 }) do
									local angle = baseAngle + angleOffset
									local dir = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
									ProjectileService.SpawnEnemyBullet(ePos + Vector3.new(0, 2.5, 0), dir, enemy.bulletDamage, cfg.bulletSpeed)
								end
							else
								ProjectileService.SpawnEnemyBullet(ePos + Vector3.new(0, 1.5, 0), flatDir, enemy.bulletDamage, cfg.bulletSpeed)
							end
						end
					end
				end

			elseif cfg.behavior == "FLEE_LOOT" then
				moveDir = -flatDir

			else
				-- Standard chase
				moveDir = flatDir
			end

			-- Apply standard movement when not charging
			if moveDir.Magnitude > 0.05 then
				enemy.currentPos += (moveDir.Unit * (moveSpeed * dt))
			end
		end

		-- Enforce fixed Y plane (guarantees model never bobs into or above ground)
		local fixedY = getEnemyFixedY(cfg.id, cfg.size.Y)
		enemy.currentPos = Vector3.new(enemy.currentPos.X, fixedY, enemy.currentPos.Z)

		-- Facing direction strictly aligns with attack telegraph or motion
		local facingDir: Vector3? = nil
		if enemy.dashState == "CHARGING" or enemy.dashState == "PREP" then
			facingDir = enemy.dashDirection
		elseif enemy.shootCharging then
			facingDir = flatDir
		elseif moveDir.Magnitude > 0.05 then
			facingDir = moveDir
		elseif flatDir.Magnitude > 0.05 then
			facingDir = flatDir
		end

		if facingDir and facingDir.Magnitude > 0.05 then
			enemy.model:PivotTo(CFrame.lookAt(enemy.currentPos, enemy.currentPos + facingDir))
		else
			enemy.model:PivotTo(CFrame.new(enemy.currentPos))
		end

		-- Contact Damage to player (tested on 2D XZ plane)
		if flatDist <= (cfg.size.X * 0.5 + 2.5) and (now - enemy.lastContactTime >= 0.5) then
			enemy.lastContactTime = now
			PlayerStatsManager.TakeDamage(targetPlayer, enemy.contactDamage, enemy)
		end
	end
end)

return EnemyService
