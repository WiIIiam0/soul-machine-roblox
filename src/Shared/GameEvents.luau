--!strict
-- GameEvents.luau: Central decoupled event hub mirroring TheSwarm GameEvents

local Signal = require(script.Parent.Signal)

local GameEvents = {
	OnEnemyKilled = Signal.new(),        -- (enemyData, killerPlayer)
	OnDamageDealt = Signal.new(),        -- (player, amount, isCrit, targetEnemy)
	OnDamageTaken = Signal.new(),        -- (player, amount, attacker)
	OnHeal = Signal.new(),               -- (player, amount)
	OnLevelUp = Signal.new(),            -- (player, newLevel)
	OnWaveStart = Signal.new(),          -- (waveNumber)
	OnWaveCompleted = Signal.new(),      -- (waveNumber)
	OnMaxHpGained = Signal.new(),        -- (player, amount)
	OnOverdriveTriggered = Signal.new(), -- (player)
	OnBurnDamageDealt = Signal.new(),    -- (player, amount, targetEnemy)
	OnGainStat = Signal.new(),           -- (player, statType, amount)
	OnXPCollected = Signal.new(),        -- (player, amount, isMeta)
	OnCritHit = Signal.new(),            -- (player, damage, targetEnemy)
	OnMove = Signal.new(),               -- (player, distanceTraveled)
	OnStandStill = Signal.new(),         -- (player, duration)
	OnWeaponFired = Signal.new(),        -- (player, weaponId)
}

return GameEvents
