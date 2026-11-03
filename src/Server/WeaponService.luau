--!strict
-- WeaponService.luau: Manages player weapon inventories, ranks, targeting scanners, and shot pattern execution

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponsData = require(Shared:WaitForChild("WeaponsData"))
local GameEvents = require(Shared:WaitForChild("GameEvents"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local EnemyService = require(script.Parent.EnemyService)
local PlayerStatsManager = require(script.Parent.PlayerStatsManager)
local ProjectileService = require(script.Parent.ProjectileService)

export type PlayerWeaponState = {
	weapons: { [string]: number }, -- weaponId -> currentRank (1 to 5)
	cooldowns: { [string]: number },
	overdriveCooldown: number,
}

local WeaponService = {}
local playerWeaponsMap: { [Player]: PlayerWeaponState } = {}

function WeaponService.InitPlayer(player: Player)
	local state: PlayerWeaponState = {
		weapons = {},
		cooldowns = {},
		overdriveCooldown = 0,
	}
	playerWeaponsMap[player] = state

	-- Give default starter weapon
	WeaponService.AddOrUpgradeWeapon(player, "StarterGun")
end

function WeaponService.GetPlayerWeapons(player: Player): { [string]: number }
	local state = playerWeaponsMap[player]
	if state then
		return state.weapons
	end
	return {}
end

function WeaponService.AddOrUpgradeWeapon(player: Player, weaponId: string): boolean
	local def = WeaponsData.GetWeapon(weaponId)
	if not def then return false end

	local state = playerWeaponsMap[player]
	if not state then return false end

	local currentRank = state.weapons[weaponId] or 0
	if currentRank >= #def.ranks then
		return false -- Maxed out
	end

	-- Check maximum weapon slots for new weapons
	if currentRank == 0 and weaponId ~= "StarterGun" then
		local MetaProgressionService = require(script.Parent.MetaProgressionService)
		local meta = MetaProgressionService.GetPlayerMeta(player)
		local numWeapons = 0
		for w, _ in pairs(state.weapons) do
			if w ~= "StarterGun" then
				numWeapons += 1
			end
		end
		if numWeapons >= meta.weaponSlots then
			warn(string.format("[WeaponService] Player %s has reached maximum weapon slots (%d)", player.Name, meta.weaponSlots))
			return false
		end
	end

	-- RULE: When unlocking the first real weapon (not StarterGun), remove StarterGun!
	if weaponId ~= "StarterGun" and state.weapons["StarterGun"] ~= nil then
		state.weapons["StarterGun"] = nil
		state.cooldowns["StarterGun"] = nil
		print(string.format("[WeaponService] First real weapon '%s' acquired by %s: StarterGun removed!", weaponId, player.Name))
	end

	state.weapons[weaponId] = currentRank + 1
	if not state.cooldowns[weaponId] then
		state.cooldowns[weaponId] = 0
	end

	-- Notify client HUD of updated inventory
	Remotes.GetEvent("StateSync"):FireClient(player, {
		weapons = state.weapons,
	})

	return true
end

-- Infinite Critical Chance Logic matching Unity TheSwarm
local function calculateCrit(critChance: number): (boolean, number)
	if critChance <= 0 then return false, 1 end
	local tier = math.floor(critChance / 100)
	local remainder = critChance % 100
	if math.random(1, 100) <= remainder then
		tier += 1
	end
	if tier > 0 then
		return true, (1 + tier)
	end
	return false, 1
end

-- AOE Explosion for impact/rocket damage
local function triggerExplosionAOE(player: Player, center: Vector3, radius: number, damage: number, color: Color3)
	Remotes.GetEvent("VFXEvent"):FireAllClients("Explosion", center, radius, color)
	local victims = EnemyService.GetEnemiesInRange(center, radius)
	for _, victim in ipairs(victims) do
		EnemyService.TakeDamage(victim, damage, false, player)
	end
end

-- Rocket recursive radial sub-chain burst matching Unity ShotRocket2
local function triggerRocketRadialBurst(player: Player, burstPos: Vector3, rank: WeaponsData.WeaponRank, shrapnelDmg: number)
	local numRays = 8
	local angleStep = (math.pi * 2) / numRays
	local rRange = 16

	for i = 1, numRays do
		local angle = i * angleStep
		local rDir = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
		local rEnd = burstPos + rDir * rRange

		-- Damage victims along each radial line
		local midPoint = burstPos + rDir * (rRange * 0.5)
		local victims = EnemyService.GetEnemiesInRange(midPoint, rRange * 0.5)
		for _, v in ipairs(victims) do
			EnemyService.TakeDamage(v, shrapnelDmg, false, player)
		end

		Remotes.GetEvent("VFXEvent"):FireAllClients("LaserTracer", burstPos, rEnd, Color3.fromRGB(255, 120, 30), 0.20, "RocketShrapnel")
	end
end

-- Instant Hitscan Raycast Execution matching Unity ExecuteInstantShot
local function executeInstantShot(
	player: Player,
	originPos: Vector3,
	dir: Vector3,
	weaponDef: WeaponsData.WeaponDefinition,
	rank: WeaponsData.WeaponRank,
	finalDamage: number,
	finalRange: number,
	isCrit: boolean
)
	local hits = {}
	local active = EnemyService.GetActiveEnemies()

	for _, enemy in pairs(active) do
		if not enemy.isDead and enemy.rootPart and enemy.rootPart.Parent then
			local ePos = enemy.currentPos or enemy.rootPart.Position
			local v = ePos - originPos
			local t = v:Dot(dir)
			if t > 0 and t <= finalRange then
				local projPoint = originPos + dir * t
				local perpDist = (ePos - projPoint).Magnitude
				local hitRadius = (enemy.config.size.X * 0.5) + 1.2
				if perpDist <= hitRadius then
					table.insert(hits, { enemy = enemy, distance = t, hitPoint = projPoint })
				end
			end
		end
	end

	table.sort(hits, function(a, b) return a.distance < b.distance end)

	local finalPoint = originPos + dir * finalRange
	local pierceLimit = rank.pierceCount
	local hitCount = 0

	for _, h in ipairs(hits) do
		local enemy = h.enemy
		if enemy and not enemy.isDead then
			EnemyService.TakeDamage(enemy, finalDamage, isCrit, player)

			if rank.inflictsBurn then
				EnemyService.ApplyBurn(enemy, rank.burnStacks, player)
			end

			if rank.explosionRadius > 0 then
				triggerExplosionAOE(player, h.hitPoint, rank.explosionRadius, finalDamage * 0.75, rank.color)
			end

			hitCount += 1
			if hitCount > pierceLimit then
				finalPoint = h.hitPoint
				if weaponDef.id == "Rocket" then
					triggerRocketRadialBurst(player, finalPoint, rank, finalDamage * 0.5)
				end
				break
			end
		end
	end

	-- Broadcast instant laser visual tracer to clients
	Remotes.GetEvent("VFXEvent"):FireAllClients("LaserTracer", originPos, finalPoint, rank.color, 0.35, weaponDef.id)
end

local function fireShotPattern(player: Player, weaponDef: WeaponsData.WeaponDefinition, rank: WeaponsData.WeaponRank, originPos: Vector3, aimDir: Vector3)
	local pData = PlayerStatsManager.GetPlayerData(player)
	if not pData then return end

	local stats = pData.currentStats

	-- Calculate final damage with scaling ratio and critical hit
	local scalingMult = PlayerStatsManager.GetWeaponScalingMultiplier(player, weaponDef.scalingStat, weaponDef.scalingRatio)
	local baseDamage = rank.damage * stats.DamageMultiplier * scalingMult
	local finalRange = rank.range * stats.RangeMultiplier

	local isCrit, critMultiplier = calculateCrit(stats.CriticalChance)
	local finalDamage = baseDamage * critMultiplier

	local behavior = weaponDef.behavior
	local count = rank.projectileCount

	local function dispatchShot(dir: Vector3)
		if rank.isInstant then
			executeInstantShot(player, originPos, dir, weaponDef, rank, finalDamage, finalRange, isCrit)
		else
			ProjectileService.SpawnPlayerProjectile(
				player,
				originPos,
				dir,
				finalDamage,
				finalRange,
				rank.speed,
				rank.pierceCount,
				rank.isHoming,
				rank.homingTurnSpeed,
				rank.inflictsBurn,
				rank.burnStacks,
				rank.explosionRadius,
				rank.color,
				rank.bulletSize
			)
		end
	end

	if behavior == "RADIAL" then
		local angleStep = (math.pi * 2) / count
		for i = 1, count do
			local angle = i * angleStep
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
			dispatchShot(dir)
		end

	elseif behavior == "CONE" then
		if count == 1 then
			dispatchShot(aimDir)
		else
			local spreadRad = math.rad(rank.spreadAngle)
			local startAngle = -spreadRad * (count - 1) * 0.5
			local baseAngle = math.atan2(aimDir.Z, aimDir.X)
			for i = 1, count do
				local angle = baseAngle + (startAngle + (i - 1) * spreadRad)
				local dir = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
				dispatchShot(dir)
			end
		end

	elseif behavior == "TRUE_SHOTGUN" then
		-- First shot straight along aimDir, remainder randomized within spreadAngle
		dispatchShot(aimDir)
		for _ = 2, count do
			local sign = if math.random() > 0.5 then 1 else -1
			local rndDeg = sign * (1 + math.random() * (math.max(2, rank.spreadAngle) - 1))
			local angle = math.atan2(aimDir.Z, aimDir.X) + math.rad(rndDeg)
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
			dispatchShot(dir)
		end

	elseif behavior == "TARGETED" then
		local targets = EnemyService.GetClosestEnemies(originPos, finalRange, count)
		if #targets > 0 then
			for _, target in ipairs(targets) do
				if target.rootPart then
					local toT = (target.rootPart.Position - originPos)
					local dir = Vector3.new(toT.X, 0, toT.Z).Unit
					dispatchShot(dir)
				end
			end
		else
			for _ = 1, count do
				local rndAngle = math.random() * math.pi * 2
				local dir = Vector3.new(math.cos(rndAngle), 0, math.sin(rndAngle)).Unit
				dispatchShot(dir)
			end
		end

	elseif behavior == "FOCUSED" then
		local targets = EnemyService.GetFocusedEnemies(originPos, finalRange, count)
		if #targets > 0 then
			for _, target in ipairs(targets) do
				if target.rootPart then
					local toT = (target.rootPart.Position - originPos)
					local dir = Vector3.new(toT.X, 0, toT.Z).Unit
					dispatchShot(dir)
				end
			end
		else
			dispatchShot(aimDir)
		end

	else
		-- HOMING (Physical missiles)
		if count == 1 then
			dispatchShot(aimDir)
		else
			local spreadRad = math.rad(rank.spreadAngle > 0 and rank.spreadAngle or 15)
			local baseAngle = math.atan2(aimDir.Z, aimDir.X)
			local halfSpread = spreadRad * 0.5
			local step = spreadRad / (count - 1)
			for i = 1, count do
				local currentAngle = (baseAngle - halfSpread) + ((i - 1) * step)
				local dir = Vector3.new(math.cos(currentAngle), 0, math.sin(currentAngle)).Unit
				dispatchShot(dir)
			end
		end
	end

	GameEvents.OnWeaponFired:Fire(player, weaponDef.id)
end

-- Weapon cooldown tick loop
RunService.Heartbeat:Connect(function(dt: number)
	for player, state in pairs(playerWeaponsMap) do
		local pData = PlayerStatsManager.GetPlayerData(player)
		if not pData or pData.isDead or pData.isLevelUpPhase then continue end

		local char = player.Character
		if not char or not char:FindFirstChild("HumanoidRootPart") then continue end

		local pPos = (char:FindFirstChild("HumanoidRootPart") :: BasePart).Position
		local rightHand = char:FindFirstChild("RightHand") :: BasePart? or char:FindFirstChild("Right Arm") :: BasePart?
		local fireOrigin = if rightHand then (rightHand.Position + Vector3.new(0, 0.2, 0)) else (pPos + Vector3.new(0, 1.2, 0))
		local stats = pData.currentStats
		local fireRateMultiplier = math.max(0.2, stats.FireRateMultiplier)

		-- Overdrive Frenzy Weapon (auto-triggers when full & enemy in range, matching Unity WeaponManager.cs)
		if not pData.isOverdriveActive and pData.currentOverdrive >= pData.maxOverdrive then
			local odDef = WeaponsData.GetWeapon("OverdriveWeapon")
			local odRange = if odDef and #odDef.ranks > 0 then odDef.ranks[1].range * stats.RangeMultiplier else 40
			if EnemyService.GetClosestEnemy(pPos, odRange) ~= nil then
				PlayerStatsManager.TryActivateOverdrive(player)
			end
		end

		if pData.isOverdriveActive then
			state.overdriveCooldown -= dt
			if state.overdriveCooldown <= 0 then
				local odDef = WeaponsData.GetWeapon("OverdriveWeapon")
				if odDef and #odDef.ranks > 0 then
					local odRank = odDef.ranks[1]
					state.overdriveCooldown = odRank.fireRate
					fireShotPattern(player, odDef, odRank, fireOrigin, Vector3.new(0, 0, 1))
				end
			end
		end

		-- Standard Equipped Weapons
		for weaponId, rankIndex in pairs(state.weapons) do
			local weaponDef = WeaponsData.GetWeapon(weaponId)
			if not weaponDef or rankIndex <= 0 or rankIndex > #weaponDef.ranks then continue end

			local rank = weaponDef.ranks[rankIndex]
			local cd = state.cooldowns[weaponId] or 0
			cd -= dt * fireRateMultiplier
			state.cooldowns[weaponId] = cd

			if cd <= 0 then
				local effectiveRange = rank.range * stats.RangeMultiplier
				local targetEnemy = EnemyService.GetClosestEnemy(pPos, effectiveRange)

				if targetEnemy and targetEnemy.rootPart then
					local toEnemy = (targetEnemy.rootPart.Position - fireOrigin)
					local flatDir = Vector3.new(toEnemy.X, 0, toEnemy.Z).Unit

					state.cooldowns[weaponId] = rank.fireRate
					fireShotPattern(player, weaponDef, rank, fireOrigin, flatDir)
				end
			end
		end
	end
end)

function WeaponService.ExportState(player: Player): { [string]: number }?
	local state = playerWeaponsMap[player]
	if not state then return nil end
	local copy: { [string]: number } = {}
	for wId, rank in pairs(state.weapons) do
		copy[wId] = rank
	end
	return copy
end

function WeaponService.ImportState(player: Player, savedWeapons: any)
	if type(savedWeapons) ~= "table" then return end
	local state: PlayerWeaponState = {
		weapons = {},
		cooldowns = {},
		overdriveCooldown = 0,
	}
	local count = 0
	for wId, rank in pairs(savedWeapons) do
		if type(wId) == "string" and type(rank) == "number" then
			local def = WeaponsData.GetWeapon(wId)
			if def and rank >= 1 then
				state.weapons[wId] = math.clamp(math.floor(rank), 1, #def.ranks)
				state.cooldowns[wId] = 0
				count += 1
			end
		end
	end
	if count == 0 then
		state.weapons["StarterGun"] = 1
		state.cooldowns["StarterGun"] = 0
	end
	playerWeaponsMap[player] = state
	Remotes.GetEvent("StateSync"):FireClient(player, {
		weapons = state.weapons,
	})
end

function WeaponService.Cleanup(player: Player)
	playerWeaponsMap[player] = nil
end

Players.PlayerRemoving:Connect(WeaponService.Cleanup)

return WeaponService
