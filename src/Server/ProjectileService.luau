--!strict
-- ProjectileService.luau: Fast kinematic simulation of player and enemy projectiles, homing, AOE, piercing

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local EnemyService = require(script.Parent.EnemyService)
local PlayerStatsManager = require(script.Parent.PlayerStatsManager)

export type ActiveProjectile = {
	part: BasePart,
	position: Vector3,
	direction: Vector3,
	speed: number,
	damage: number,
	maxRange: number,
	distanceTraveled: number,
	pierceCount: number,
	hitEnemies: { [Model]: boolean },
	isHoming: boolean,
	homingTurnSpeed: number,
	inflictsBurn: boolean,
	burnStacks: number,
	explosionRadius: number,
	ownerPlayer: Player,
	color: Color3,
}

export type EnemyBullet = {
	part: BasePart,
	position: Vector3,
	direction: Vector3,
	speed: number,
	damage: number,
	maxDistance: number,
	distanceTraveled: number,
}

local ProjectileService = {}
local activeProjectiles: { ActiveProjectile } = {}
local enemyBullets: { EnemyBullet } = {}

local projectilesFolder: Folder

local function getProjectilesFolder(): Folder
	if not projectilesFolder or not projectilesFolder.Parent then
		local found = Workspace:FindFirstChild("GameProjectiles") :: Folder?
		if not found then
			found = Instance.new("Folder")
			found.Name = "GameProjectiles"
			found.Parent = Workspace
		end
		projectilesFolder = found
	end
	return projectilesFolder
end

function ProjectileService.SpawnPlayerProjectile(
	owner: Player,
	startPos: Vector3,
	dir: Vector3,
	damage: number,
	range: number,
	speed: number,
	pierceCount: number,
	isHoming: boolean,
	homingTurnSpeed: number,
	inflictsBurn: boolean,
	burnStacks: number,
	explosionRadius: number,
	color: Color3,
	size: Vector3
)
	local part = Instance.new("Part")
	part.Name = "Bullet"
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon
	part.CanCollide = false
	part.Anchored = true
	part.CastShadow = false
	part.CFrame = CFrame.lookAt(startPos, startPos + dir)
	part.Parent = getProjectilesFolder()

	-- Subtle light for bullet glow
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.5
	light.Range = 8
	light.Parent = part

	local proj: ActiveProjectile = {
		part = part,
		position = startPos,
		direction = dir.Unit,
		speed = speed,
		damage = damage,
		maxRange = range,
		distanceTraveled = 0,
		pierceCount = pierceCount,
		hitEnemies = {},
		isHoming = isHoming,
		homingTurnSpeed = homingTurnSpeed,
		inflictsBurn = inflictsBurn,
		burnStacks = burnStacks,
		explosionRadius = explosionRadius,
		ownerPlayer = owner,
		color = color,
	}

	table.insert(activeProjectiles, proj)
end

function ProjectileService.SpawnEnemyBullet(startPos: Vector3, dir: Vector3, damage: number, speed: number)
	local part = Instance.new("Part")
	part.Name = "EnemyLaser"
	part.Size = Vector3.new(0.6, 0.6, 2.0)
	part.Color = Color3.fromRGB(255, 30, 80)
	part.Material = Enum.Material.Neon
	part.CanCollide = false
	part.Anchored = true
	part.CastShadow = false
	part.CFrame = CFrame.lookAt(startPos, startPos + dir)
	part.Parent = getProjectilesFolder()

	local bullet: EnemyBullet = {
		part = part,
		position = startPos,
		direction = dir.Unit,
		speed = speed,
		damage = damage,
		maxDistance = 80,
		distanceTraveled = 0,
	}

	table.insert(enemyBullets, bullet)
end

local function triggerExplosion(pos: Vector3, radius: number, damage: number, owner: Player, burnStacks: number)
	Remotes.GetEvent("VFXEvent"):FireAllClients("Explosion", pos, radius, Color3.fromRGB(255, 120, 20))

	local enemies = EnemyService.GetEnemiesInRange(pos, radius)
	for _, enemy in ipairs(enemies) do
		-- Crit calculation
		local pData = PlayerStatsManager.GetPlayerData(owner)
		local isCrit = false
		local finalDamage = damage
		if pData then
			local roll = math.random(1, 100)
			if roll <= pData.currentStats.CriticalChance then
				isCrit = true
				finalDamage = damage * 2
			end
		end

		EnemyService.TakeDamage(enemy, finalDamage, isCrit, owner)
		if burnStacks > 0 then
			EnemyService.ApplyBurn(enemy, burnStacks, owner)
		end
	end
end

-- Step loop
RunService.Heartbeat:Connect(function(dt: number)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include

	-- 1. Player Projectiles
	for i = #activeProjectiles, 1, -1 do
		local proj = activeProjectiles[i]
		if not proj.part or not proj.part.Parent then
			table.remove(activeProjectiles, i)
			continue
		end

		-- Homing steering
		if proj.isHoming then
			local target = EnemyService.GetClosestEnemy(proj.position, 60)
			if target and target.rootPart then
				local toEnemy = (target.rootPart.Position - proj.position).Unit
				proj.direction = proj.direction:Lerp(toEnemy, math.clamp(proj.homingTurnSpeed * dt, 0, 1)).Unit
			end
		end

		local moveDist = proj.speed * dt
		local nextPos = proj.position + (proj.direction * moveDist)

		-- Collision test against active enemies
		local enemies = EnemyService.GetEnemiesInRange(nextPos, 4)
		local hitAny = false

		for _, enemy in ipairs(enemies) do
			if not proj.hitEnemies[enemy.model] then
				proj.hitEnemies[enemy.model] = true
				hitAny = true

				-- Crit check
				local pData = PlayerStatsManager.GetPlayerData(proj.ownerPlayer)
				local isCrit = false
				local finalDamage = proj.damage
				if pData then
					local roll = math.random(1, 100)
					if roll <= pData.currentStats.CriticalChance then
						isCrit = true
						finalDamage = proj.damage * 2
					end
				end

				EnemyService.TakeDamage(enemy, finalDamage, isCrit, proj.ownerPlayer)

				if proj.inflictsBurn then
					EnemyService.ApplyBurn(enemy, proj.burnStacks, proj.ownerPlayer)
				end

				if proj.explosionRadius > 0 then
					triggerExplosion(nextPos, proj.explosionRadius, proj.damage, proj.ownerPlayer, proj.burnStacks)
				end

				proj.pierceCount -= 1
				if proj.pierceCount < 0 then
					break
				end
			end
		end

		proj.distanceTraveled += moveDist
		proj.position = nextPos

		if proj.part and proj.part.Parent then
			proj.part.CFrame = CFrame.lookAt(proj.position, proj.position + proj.direction)
		end

		if (proj.pierceCount < 0 and hitAny) or proj.distanceTraveled >= proj.maxRange then
			if proj.explosionRadius > 0 and not hitAny then
				triggerExplosion(proj.position, proj.explosionRadius, proj.damage, proj.ownerPlayer, proj.burnStacks)
			end
			proj.part:Destroy()
			table.remove(activeProjectiles, i)
		end
	end

	-- 2. Enemy Projectiles
	for i = #enemyBullets, 1, -1 do
		local bullet = enemyBullets[i]
		if not bullet.part or not bullet.part.Parent then
			table.remove(enemyBullets, i)
			continue
		end

		local stepDist = bullet.speed * dt
		local nextPos = bullet.position + (bullet.direction * stepDist)

		-- Check hit against players
		local didHitPlayer = false
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local pPos = (char:FindFirstChild("HumanoidRootPart") :: BasePart).Position
				if (pPos - nextPos).Magnitude <= 3.0 then
					PlayerStatsManager.TakeDamage(player, bullet.damage, nil)
					didHitPlayer = true
					break
				end
			end
		end

		bullet.distanceTraveled += stepDist
		bullet.position = nextPos

		if bullet.part and bullet.part.Parent then
			bullet.part.CFrame = CFrame.lookAt(bullet.position, bullet.position + bullet.direction)
		end

		if didHitPlayer or bullet.distanceTraveled >= bullet.maxDistance then
			bullet.part:Destroy()
			table.remove(enemyBullets, i)
		end
	end
end)

function ProjectileService.ClearAll()
	for i = #activeProjectiles, 1, -1 do
		local p = activeProjectiles[i]
		if p.part and p.part.Parent then
			p.part:Destroy()
		end
		table.remove(activeProjectiles, i)
	end
	for i = #enemyBullets, 1, -1 do
		local b = enemyBullets[i]
		if b.part and b.part.Parent then
			b.part:Destroy()
		end
		table.remove(enemyBullets, i)
	end
end

return ProjectileService
