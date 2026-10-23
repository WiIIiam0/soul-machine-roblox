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

local function fireShotPattern(player: Player, weaponDef: WeaponsData.WeaponDefinition, rank: WeaponsData.WeaponRank, originPos: Vector3, aimDir: Vector3)
	local pData = PlayerStatsManager.GetPlayerData(player)
	if not pData then return end

	local stats = pData.currentStats

	-- Calculate final damage with scaling ratio
	local finalDamage = rank.damage * stats.DamageMultiplier
	local finalRange = rank.range * stats.RangeMultiplier

	local behavior = weaponDef.behavior
	local count = rank.projectileCount

	if behavior == "RADIAL" then
		-- 360 degree circle
		local angleStep = (math.pi * 2) / count
		for i = 1, count do
			local angle = i * angleStep
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
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

	elseif behavior == "CONE" then
		-- Shotgun fan
		local spreadRad = math.rad(rank.spreadAngle)
		local baseAngle = math.atan2(aimDir.Z, aimDir.X)
		local halfSpread = spreadRad * 0.5
		local step = if count > 1 then spreadRad / (count - 1) else 0

		for i = 1, count do
			local currentAngle = (baseAngle - halfSpread) + ((i - 1) * step)
			local dir = Vector3.new(math.cos(currentAngle), 0, math.sin(currentAngle)).Unit
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

	else
		-- TARGETED or HOMING
		if count == 1 then
			ProjectileService.SpawnPlayerProjectile(
				player,
				originPos,
				aimDir,
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
		else
			-- Small cone spread for multiple shots
			local spreadRad = math.rad(rank.spreadAngle > 0 and rank.spreadAngle or 12)
			local baseAngle = math.atan2(aimDir.Z, aimDir.X)
			local halfSpread = spreadRad * 0.5
			local step = spreadRad / (count - 1)

			for i = 1, count do
				local currentAngle = (baseAngle - halfSpread) + ((i - 1) * step)
				local dir = Vector3.new(math.cos(currentAngle), 0, math.sin(currentAngle)).Unit
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
	end

	GameEvents.OnWeaponFired:Fire(player, weaponDef.id)
end

-- Weapon cooldown tick loop
RunService.Heartbeat:Connect(function(dt: number)
	for player, state in pairs(playerWeaponsMap) do
		local pData = PlayerStatsManager.GetPlayerData(player)
		if not pData or pData.isDead then continue end

		local char = player.Character
		if not char or not char:FindFirstChild("HumanoidRootPart") then continue end

		local pPos = (char:FindFirstChild("HumanoidRootPart") :: BasePart).Position
		local fireOrigin = pPos + Vector3.new(0, 1.2, 0)
		local stats = pData.currentStats
		local fireRateMultiplier = math.max(0.2, stats.FireRateMultiplier)

		-- Overdrive Frenzy Weapon
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

function WeaponService.Cleanup(player: Player)
	playerWeaponsMap[player] = nil
end

Players.PlayerRemoving:Connect(WeaponService.Cleanup)

return WeaponService
