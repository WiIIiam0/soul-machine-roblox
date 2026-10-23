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

export type ActiveEnemy = {
	model: Model,
	rootPart: BasePart,
	config: EnemiesData.EnemyConfig,
	currentHealth: number,
	maxHealth: number,
	isDead: boolean,
	lastContactTime: number,
	lastShootTime: number,
	burnStacks: number,
	burnTimer: number,
	targetPlayer: Player?,
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
	ScoutDrone = { "drone_worker", "droneworker", "worker", "farmer", "scout", "minion_blue_melee", "minion_red_melee" },
	AssaultMecha = { "drone_fighter", "dronefighter", "fighter", "assault", "gunner", "shooter", "minion_blue_ranged", "minion_red_ranged" },
	SniperBot = { "sniper", "turret", "laserbot", "blaster" },
	HeavyJuggernaut = { "spider", "tank", "heavy", "juggernaut", "brute", "colosse" },
	KamikazeRoller = { "roller", "kamikaze", "sphere", "bomb" },
	OverlordBoss = { "boss", "goliath", "overlord", "titan" },
	MetaDrone = { "metadrone", "goldendrone", "golddrone", "lootdrone" },
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

	-- Scan containers: ReplicatedStorage, ServerStorage, Workspace (excluding ActiveEnemies)
	local containers = { ReplicatedStorage, ServerStorage, Workspace }
	for _, container in ipairs(containers) do
		for _, desc in ipairs(container:GetDescendants()) do
			if desc:IsA("Model") and not desc:FindFirstAncestor("ActiveEnemies") and matches(desc.Name) then
				print(string.format("[EnemyService] Custom 3D Model detected for '%s': %s (%s)", enemyId, desc.Name, desc:GetFullName()))
				cachedTemplates[enemyId] = desc
				return desc
			end
		end
	end

	cachedTemplates[enemyId] = nil
	return nil
end

local function createHealthUI(adornee: BasePart, heightOffset: number, isBoss: boolean): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthUI"
	billboard.Adornee = adornee
	billboard.Size = UDim2.new(0, 70, 0, 8)
	billboard.StudsOffset = Vector3.new(0, heightOffset + 1.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = adornee

	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = bg

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.new(1, 0, 1, 0)
	bar.BackgroundColor3 = if isBoss then Color3.fromRGB(255, 50, 50) else Color3.fromRGB(80, 255, 120)
	bar.BorderSizePixel = 0
	bar.Parent = bg

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0.5, 0)
	barCorner.Parent = bar

	return billboard
end

local function createEnemyModel(config: EnemiesData.EnemyConfig, spawnPos: Vector3): (Model, BasePart)
	local customTemplate = findCustomTemplate(config.id)

	if customTemplate then
		-- Clone the recognized custom 3D model
		local model = customTemplate:Clone()
		model.Name = config.name

		local root = model.PrimaryPart
		if not root then
			root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		end

		if not root then
			-- Create a root part and weld everything to it
			root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Size = config.size
			root.Transparency = 1
			root.CanCollide = false
			root.Anchored = false
			root.CFrame = CFrame.new(spawnPos)
			root.Parent = model
			model.PrimaryPart = root

			for _, desc in ipairs(model:GetDescendants()) do
				if desc:IsA("BasePart") and desc ~= root then
					desc.CanCollide = false
					desc.Massless = true
					desc.Anchored = false
					local w = Instance.new("WeldConstraint")
					w.Part0 = root
					w.Part1 = desc
					w.Parent = root
				end
			end
		else
			model.PrimaryPart = root
			root.CanCollide = false
			root.Anchored = false
			for _, desc in ipairs(model:GetDescendants()) do
				if desc:IsA("BasePart") and desc ~= root then
					desc.CanCollide = false
					desc.Massless = true
					desc.Anchored = false
				end
			end
		end

		model:PivotTo(CFrame.new(spawnPos))
		createHealthUI(root, config.size.Y * 0.7, config.isBoss)
		model.Parent = getEnemiesFolder()

		return model, root
	end

	-- Fallback procedural neon mecha model
	local model = Instance.new("Model")
	model.Name = config.name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = config.size
	root.Position = spawnPos
	root.Color = config.color
	root.Material = Enum.Material.SmoothPlastic
	root.CanCollide = false
	root.Anchored = false
	root.Massless = false
	root.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 0, 0)
	root.Parent = model

	-- Visual Mecha Core (Neon)
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = config.size * 0.6
	core.Position = spawnPos
	core.Color = if config.isBoss then Color3.fromRGB(255, 0, 80) else (if config.isMetaEnemy then Color3.fromRGB(255, 230, 0) else Color3.fromRGB(0, 255, 220))
	core.Material = Enum.Material.Neon
	core.CanCollide = false
	core.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = core
	weld.Parent = root

	createHealthUI(root, config.size.Y * 0.7, config.isBoss)

	model.PrimaryPart = root
	model.Parent = getEnemiesFolder()

	return model, root
end

function EnemyService.SpawnEnemy(configId: string, spawnPosition: Vector3): ActiveEnemy?
	local config = EnemiesData.GetEnemy(configId)
	if not config then return nil end

	local model, rootPart = createEnemyModel(config, spawnPosition)

	local enemy: ActiveEnemy = {
		model = model,
		rootPart = rootPart,
		config = config,
		currentHealth = config.maxHealth,
		maxHealth = config.maxHealth,
		isDead = false,
		lastContactTime = 0,
		lastShootTime = 0,
		burnStacks = 0,
		burnTimer = 0,
		targetPlayer = nil,
	}

	activeEnemies[model] = enemy
	return enemy
end

function EnemyService.GetActiveEnemies(): { [Model]: ActiveEnemy }
	return activeEnemies
end

function EnemyService.GetClosestEnemy(fromPos: Vector3, maxRange: number): ActiveEnemy?
	local closest: ActiveEnemy? = nil
	local closestDistSq = maxRange * maxRange

	for _, enemy in pairs(activeEnemies) do
		if not enemy.isDead and enemy.rootPart and enemy.rootPart.Parent then
			local distSq = (enemy.rootPart.Position - fromPos).Magnitude
			distSq = distSq * distSq
			if distSq < closestDistSq then
				closestDistSq = distSq
				closest = enemy
			end
		end
	end

	return closest
end

function EnemyService.GetEnemiesInRange(fromPos: Vector3, radius: number): { ActiveEnemy }
	local result: { ActiveEnemy } = {}
	local rSq = radius * radius

	for _, enemy in pairs(activeEnemies) do
		if not enemy.isDead and enemy.rootPart and enemy.rootPart.Parent then
			local d = (enemy.rootPart.Position - fromPos).Magnitude
			if (d * d) <= rSq then
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
			local bar = billboard:FindFirstChild("BG"):FindFirstChild("Bar") :: Frame?
			if bar then
				bar.Size = UDim2.new(math.clamp(enemy.currentHealth / enemy.maxHealth, 0, 1), 0, 1, 0)
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

	activeEnemies[enemy.model] = nil

	local deathPos = if enemy.rootPart then enemy.rootPart.Position else Vector3.zero

	-- Death visual
	Remotes.GetEvent("VFXEvent"):FireAllClients("EnemyDeath", deathPos, enemy.config.color, enemy.config.isBoss)

	-- Signal event
	GameEvents.OnEnemyKilled:Fire(enemy.config, killer)

	-- Spawn XP Gem
	local XPService = require(script.Parent.XPService)
	XPService.SpawnGem(deathPos, enemy.config.xpValue, enemy.config.isMetaEnemy)

	if enemy.config.isBoss then
		-- Boss drops extra cluster of gems!
		for i = 1, 6 do
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
		if pData and not pData.isDead then
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

-- Heartbeat AI loop
RunService.Heartbeat:Connect(function(dt: number)
	local now = os.clock()

	for model, enemy in pairs(activeEnemies) do
		if enemy.isDead or not enemy.rootPart or not enemy.rootPart.Parent then
			activeEnemies[model] = nil
			continue
		end

		local root = enemy.rootPart
		local ePos = root.Position

		-- Burn DoT tick every 0.5s
		if enemy.burnStacks > 0 then
			enemy.burnTimer += dt
			if enemy.burnTimer >= 0.5 then
				enemy.burnTimer = 0
				local burnDmg = math.max(1, enemy.burnStacks * 1.5)
				enemy.currentHealth = math.max(0, enemy.currentHealth - burnDmg)

				local fPos = ePos + Vector3.new(0, enemy.config.size.Y * 0.5 + 1.2, 0)
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
			-- No players, stay idle
			root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
			continue
		end

		local behavior = enemy.config.behavior
		local moveDir = Vector3.zero

		if behavior == "CHASE" or behavior == "BOSS" then
			-- Walk towards player
			local toTarget = (targetPos - ePos)
			toTarget = Vector3.new(toTarget.X, 0, toTarget.Z)
			if toTarget.Magnitude > 0.1 then
				moveDir = toTarget.Unit
				root.CFrame = CFrame.lookAt(ePos, ePos + moveDir)
			end

		elseif behavior == "KITE_SHOOT" then
			local toTarget = (targetPos - ePos)
			local flatDist = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude
			local flatDir = Vector3.new(toTarget.X, 0, toTarget.Z).Unit

			if flatDist < 30 then
				-- Flee
				moveDir = -flatDir
			elseif flatDist > 55 then
				-- Chase
				moveDir = flatDir
			else
				-- Strafe
				moveDir = Vector3.new(-flatDir.Z, 0, flatDir.X)
			end

			root.CFrame = CFrame.lookAt(ePos, ePos + flatDir)

			-- Shoot enemy projectile
			if now - enemy.lastShootTime >= enemy.config.shootCooldown then
				enemy.lastShootTime = now
				local ProjectileService = require(script.Parent.ProjectileService)
				ProjectileService.SpawnEnemyBullet(ePos + Vector3.new(0, 1.5, 0), flatDir, enemy.config.bulletDamage, enemy.config.bulletSpeed)
			end

		elseif behavior == "KAMIKAZE" then
			local toTarget = (targetPos - ePos)
			toTarget = Vector3.new(toTarget.X, 0, toTarget.Z)
			if toTarget.Magnitude > 0.1 then
				moveDir = toTarget.Unit
				root.CFrame = CFrame.lookAt(ePos, ePos + moveDir)
			end

			-- Check detonation
			if dist <= 5.5 then
				-- Detonate!
				Remotes.GetEvent("VFXEvent"):FireAllClients("Explosion", ePos, 12, Color3.fromRGB(255, 60, 20))
				PlayerStatsManager.TakeDamage(targetPlayer, enemy.config.contactDamage, enemy)
				EnemyService.KillEnemy(enemy, nil)
				continue
			end

		elseif behavior == "FLEE_LOOT" then
			-- Runs away from player
			local awayDir = (ePos - targetPos)
			awayDir = Vector3.new(awayDir.X, 0, awayDir.Z)
			if awayDir.Magnitude > 0.1 then
				moveDir = awayDir.Unit
				root.CFrame = CFrame.lookAt(ePos, ePos + moveDir)
			end
		end

		-- Set velocity
		local targetVelocity = moveDir * enemy.config.moveSpeed
		root.AssemblyLinearVelocity = Vector3.new(targetVelocity.X, root.AssemblyLinearVelocity.Y, targetVelocity.Z)

		-- Contact Damage to player
		if dist <= (enemy.config.size.X * 0.5 + 2.5) and (now - enemy.lastContactTime >= 0.5) then
			enemy.lastContactTime = now
			PlayerStatsManager.TakeDamage(targetPlayer, enemy.config.contactDamage, enemy)
		end
	end
end)

return EnemyService
