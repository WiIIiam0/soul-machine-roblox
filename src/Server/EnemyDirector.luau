--!strict
-- EnemyDirector.luau: Economy-based Game Director managing wave state machine, credit rate, and bestiary unlocks

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameEvents = require(Shared:WaitForChild("GameEvents"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local EnemyService = require(script.Parent.EnemyService)
local PlayerStatsManager = require(script.Parent.PlayerStatsManager)

export type WaveState = "SPAWNING" | "CLEARING" | "RESTING" | "BOSS"

local EnemyDirector = {}

local currentWave = 1
local waveState: WaveState = "RESTING"
local stateTimer = 5.0 -- 5s initial countdown

-- Economy parameters
local currentCredits = 40.0
local baseSpawnRate = 12.0 -- Credits gained per second
local spawnAcceleration = 0.20 -- Rate grows per second
local currentSpawnRate = 12.0

local SPAWN_DURATION = 40.0 -- 40 seconds of intense wave spawning
local REST_DURATION = 5.0   -- 5 seconds pause between waves

-- Meta Enemy timer
local metaEnemyInterval = 45.0
local metaEnemyTimer = 0.0

local function getEligibleEnemies(): { string }
	if currentWave == 1 then
		return { "ScoutDrone", "AssaultMecha" }
	elseif currentWave == 2 then
		return { "ScoutDrone", "AssaultMecha", "SniperBot" }
	elseif currentWave == 3 then
		return { "ScoutDrone", "AssaultMecha", "SniperBot", "HeavyJuggernaut" }
	else
		return { "ScoutDrone", "AssaultMecha", "SniperBot", "HeavyJuggernaut", "KamikazeRoller" }
	end
end

local function spawnEnemyAroundPlayers(enemyId: string)
	local alivePlayers: { Player } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local pData = PlayerStatsManager.GetPlayerData(p)
		if pData and not pData.isDead and p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			table.insert(alivePlayers, p)
		end
	end

	if #alivePlayers == 0 then return end

	local chosenPlayer = alivePlayers[math.random(1, #alivePlayers)]
	local hrp = chosenPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart
	local centerPos = hrp.Position

	-- Random angle on outer ring (radius 45 to 60 studs)
	local angle = math.random() * math.pi * 2
	local dist = math.random(42, 58)
	local spawnPos = centerPos + Vector3.new(math.cos(angle) * dist, 0.5, math.sin(angle) * dist)

	-- Clamp within arena boundaries (-140 to 140)
	spawnPos = Vector3.new(
		math.clamp(spawnPos.X, -130, 130),
		1.5,
		math.clamp(spawnPos.Z, -130, 130)
	)

	EnemyService.SpawnEnemy(enemyId, spawnPos)
end

function EnemyDirector.Start()
	waveState = "RESTING"
	stateTimer = REST_DURATION
end

local function broadcastWaveState()
	local activeEnemies = EnemyService.GetActiveEnemies()
	local enemyCount = 0
	for _ in pairs(activeEnemies) do enemyCount += 1 end

	for _, player in ipairs(Players:GetPlayers()) do
		Remotes.GetEvent("StateSync"):FireClient(player, {
			wave = currentWave,
			waveState = waveState,
			waveTimer = math.ceil(stateTimer),
			activeEnemies = enemyCount,
		})
	end
end

RunService.Heartbeat:Connect(function(dt: number)
	stateTimer -= dt
	metaEnemyTimer += dt

	-- Periodic Meta Enemy Spawn
	if metaEnemyTimer >= metaEnemyInterval then
		metaEnemyTimer = 0
		spawnEnemyAroundPlayers("MetaDrone")
	end

	if waveState == "RESTING" then
		if stateTimer <= 0 then
			-- Transition to next wave
			currentWave += 1
			GameEvents.OnWaveStart:Fire(currentWave)

			if currentWave % 5 == 0 then
				-- Boss Wave!
				waveState = "BOSS"
				stateTimer = 60.0
				spawnEnemyAroundPlayers("OverlordBoss")
				for _ = 1, 4 do
					spawnEnemyAroundPlayers("HeavyJuggernaut")
				end
			else
				waveState = "SPAWNING"
				stateTimer = SPAWN_DURATION
				currentCredits = 30 + (currentWave * 15)
				currentSpawnRate = baseSpawnRate + (currentWave * 2.5)
			end
		end

	elseif waveState == "SPAWNING" then
		-- Economy credit accumulation
		currentSpawnRate += spawnAcceleration * dt
		currentCredits += currentSpawnRate * dt

		-- Spend credits to spawn enemies
		local eligible = getEligibleEnemies()
		local attempts = 0
		while currentCredits >= 25 and attempts < 10 do
			attempts += 1
			local chosenId = eligible[math.random(1, #eligible)]
			local conf = require(Shared:WaitForChild("EnemiesData")).GetEnemy(chosenId)
			if conf and currentCredits >= conf.cost then
				currentCredits -= conf.cost
				spawnEnemyAroundPlayers(chosenId)
			else
				break
			end
		end

		if stateTimer <= 0 then
			waveState = "CLEARING"
			stateTimer = 30.0 -- Max time to clear remaining enemies
		end

	elseif waveState == "CLEARING" or waveState == "BOSS" then
		local active = EnemyService.GetActiveEnemies()
		local count = 0
		for _ in pairs(active) do count += 1 end

		if count == 0 or stateTimer <= 0 then
			-- Wave complete!
			GameEvents.OnWaveCompleted:Fire(currentWave)
			waveState = "RESTING"
			stateTimer = REST_DURATION
		end
	end

	broadcastWaveState()
end)

return EnemyDirector
