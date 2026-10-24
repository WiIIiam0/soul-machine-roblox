--!strict
-- EnemyDirector.luau: Directeur de spawn continu par vagues infinies, calibré par Zone (sans scaling par vague) et proportionnel au nombre de joueurs (N joueurs = N x spawns)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnemiesData = require(Shared:WaitForChild("EnemiesData"))
local ZonesData = require(Shared:WaitForChild("ZonesData"))
local GameEvents = require(Shared:WaitForChild("GameEvents"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ArenaBuilder = require(script.Parent.ArenaBuilder)
local EnemyService = require(script.Parent.EnemyService)
local PlayerStatsManager = require(script.Parent.PlayerStatsManager)
local ZoneService = require(script.Parent.ZoneService)

export type WaveState = "SPAWNING" | "BOSS"

local EnemyDirector = {}

local NORMAL_WAVE_DURATION = 35.0
local BOSS_WAVE_DURATION = 45.0
local META_ENEMY_BASE_INTERVAL = 45.0

local isRunning = false
local currentWave = 0
local waveState: WaveState = "SPAWNING"
local stateTimer = 0.0
local waveElapsed = 0.0
local currentCredits = 0.0
local metaEnemyTimer = 0.0
local syncTimer = 0.0
local currentBossEnemy: EnemyService.ActiveEnemy? = nil

local function getAlivePlayers(): { Player }
	local alive: { Player } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if not ZoneService.IsPlayerTeleporting(p) then
			local pData = PlayerStatsManager.GetPlayerData(p)
			if pData and not pData.isDead and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
				table.insert(alive, p)
			end
		end
	end
	return alive
end

local function countActiveEnemies(): number
	local count = 0
	for _, e in pairs(EnemyService.GetActiveEnemies()) do
		if not e.isDead then
			count += 1
		end
	end
	return count
end

local function makeZoneStatOverrides(zone: ZonesData.ZoneConfig, playerScale: number?): EnemyService.SpawnOverrides
	return {
		hpMult = zone.enemyHpMult,
		damageMult = zone.enemyDamageMult,
		xpMult = zone.enemyXpMult,
		playerScale = playerScale or 1,
	}
end

local function spawnAroundAlivePlayers(enemyId: string, alivePlayers: { Player }, overrides: EnemyService.SpawnOverrides): EnemyService.ActiveEnemy?
	if #alivePlayers == 0 then
		return nil
	end

	local chosenPlayer = alivePlayers[math.random(1, #alivePlayers)]
	local char = chosenPlayer.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return nil end

	local centerPos = hrp.Position
	local angle = math.random() * math.pi * 2
	local dist = math.random(32, 52)
	local spawnPos = centerPos + Vector3.new(math.cos(angle) * dist, 0.5, math.sin(angle) * dist)

	spawnPos = Vector3.new(
		math.clamp(spawnPos.X, -65, 65),
		1.5,
		math.clamp(spawnPos.Z, -65, 65)
	)

	-- Évite de faire spawner un monstre pile sur le socle du téléporteur Nord
	local portalPos = ArenaBuilder.PORTAL_POSITION
	local dx = spawnPos.X - portalPos.X
	local dz = spawnPos.Z - portalPos.Z
	if (dx * dx + dz * dz) < 100 then
		spawnPos = Vector3.new(spawnPos.X, 1.5, math.min(65, portalPos.Z + 14))
	end

	return EnemyService.SpawnEnemy(enemyId, spawnPos, overrides)
end

local function broadcastWaveState(aliveCount: number)
	local zone = ZoneService.GetCurrentZoneConfig()
	local enemyCount = countActiveEnemies()

	for _, player in ipairs(Players:GetPlayers()) do
		Remotes.GetEvent("StateSync"):FireClient(player, {
			zoneId = zone.zoneId,
			zoneName = zone.name,
			wave = math.max(1, currentWave),
			waveState = waveState,
			waveTimer = math.max(0, math.ceil(stateTimer)),
			activeEnemies = enemyCount,
			alivePlayers = aliveCount,
		})
	end
end

local function startNextWave(alivePlayers: { Player })
	local zone = ZoneService.GetCurrentZoneConfig()
	local aliveCount = math.max(1, #alivePlayers)

	currentWave += 1
	waveElapsed = 0.0
	GameEvents.OnWaveStart:Fire(currentWave)

	if currentWave % ZonesData.BOSS_WAVE_INTERVAL == 0 then
		-- Vague de Boss toutes les 10 vagues (sans montée de niveau par vague, mais calibrée sur la Zone et le nombre de joueurs)
		waveState = "BOSS"
		stateTimer = BOSS_WAVE_DURATION
		currentCredits = (zone.baseCreditsPerWave * 0.5) * aliveCount

		currentBossEnemy = spawnAroundAlivePlayers(
			zone.bossId,
			alivePlayers,
			makeZoneStatOverrides(zone, aliveCount)
		)

		local escortCount = 2 * aliveCount
		local escortOverrides = makeZoneStatOverrides(zone, 1)
		for _ = 1, escortCount do
			spawnAroundAlivePlayers(zone.bossEscortId, alivePlayers, escortOverrides)
		end
	else
		-- Vague normale en flux continu : crédits proportionnels au nombre de joueurs (3 joueurs = 3x spawns)
		waveState = "SPAWNING"
		stateTimer = NORMAL_WAVE_DURATION
		currentBossEnemy = nil
		currentCredits += zone.baseCreditsPerWave * aliveCount
	end

	broadcastWaveState(#alivePlayers)
end

function EnemyDirector.ResetForZone()
	currentWave = 0
	waveState = "SPAWNING"
	stateTimer = 0.0
	waveElapsed = 0.0
	currentCredits = 0.0
	metaEnemyTimer = 0.0
	currentBossEnemy = nil
end

function EnemyDirector.Start()
	EnemyDirector.ResetForZone()
	isRunning = true
end

ZoneService.OnZoneChanged(function(_newZoneId: number)
	EnemyDirector.ResetForZone()
end)

RunService.Heartbeat:Connect(function(dt: number)
	if not isRunning then return end

	local alivePlayers = getAlivePlayers()
	local aliveCount = #alivePlayers

	syncTimer += dt
	if aliveCount == 0 then
		if syncTimer >= 0.5 then
			syncTimer = 0
			broadcastWaveState(0)
		end
		return
	end

	-- Démarrage immédiat de la Vague 1 dès qu'un premier joueur est présent
	if currentWave == 0 then
		startNextWave(alivePlayers)
	end

	local zone = ZoneService.GetCurrentZoneConfig()
	stateTimer -= dt
	waveElapsed += dt

	-- MetaDrone doré : fréquence multipliée par le nombre de joueurs (N joueurs = N x spawns)
	metaEnemyTimer += dt * aliveCount
	while metaEnemyTimer >= META_ENEMY_BASE_INTERVAL do
		metaEnemyTimer -= META_ENEMY_BASE_INTERVAL
		spawnAroundAlivePlayers("MetaDrone", alivePlayers, makeZoneStatOverrides(zone, 1))
	end

	-- Accumulation continue de crédits proportionnelle à aliveCount (strictement aucun scaling par numéro de vague)
	local rateMultiplier = if waveState == "BOSS" then 0.65 else 1.0
	local spawnRate = zone.baseSpawnRatePerPlayer * aliveCount * rateMultiplier
	currentCredits += spawnRate * dt

	-- Dépense des crédits pour faire spawner les ennemis autour des joueurs vivants
	local maxSimultaneousEnemies = math.max(65, 60 * aliveCount)
	local activeCount = countActiveEnemies()
	if activeCount < maxSimultaneousEnemies then
		local eligible = zone.eligibleEnemies
		local minCost = 25
		local maxSpawnsThisTick = 8 * aliveCount
		local attempts = 0
		local overrides = makeZoneStatOverrides(zone, 1)

		while currentCredits >= minCost and attempts < maxSpawnsThisTick and activeCount < maxSimultaneousEnemies do
			attempts += 1
			local chosenId = eligible[math.random(1, #eligible)]
			local conf = EnemiesData.GetEnemy(chosenId)
			if conf and currentCredits >= conf.cost then
				currentCredits -= conf.cost
				local spawned = spawnAroundAlivePlayers(chosenId, alivePlayers, overrides)
				if spawned then
					activeCount += 1
				end
			else
				break
			end
		end
	else
		-- Plafond anti-saturation atteint : on plafonne la réserve de crédits pour éviter une explosion d'un coup
		currentCredits = math.min(currentCredits, zone.baseCreditsPerWave * aliveCount * 1.5)
	end

	-- Fin de vague -> enchaînement infini immédiat sur la vague suivante (y compris après un Boss !)
	local bossDefeatedEarly = (
		waveState == "BOSS"
		and waveElapsed >= 10.0
		and (currentBossEnemy == nil or currentBossEnemy.isDead)
	)

	if stateTimer <= 0 or bossDefeatedEarly then
		GameEvents.OnWaveCompleted:Fire(currentWave)
		startNextWave(alivePlayers)
	elseif syncTimer >= 0.25 then
		syncTimer = 0
		broadcastWaveState(aliveCount)
	end
end)

return EnemyDirector
