--!strict
-- PassiveService.luau: Reactive event accumulator and execution engine for passive upgrades

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PassivesData = require(Shared:WaitForChild("PassivesData"))
local GameEvents = require(Shared:WaitForChild("GameEvents"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerStatsManager = require(script.Parent.PlayerStatsManager)

export type PlayerPassiveState = {
	passives: { PassivesData.PassiveDefinition },
	accumulators: { [PassivesData.TriggerCondition]: number },
	currentThresholds: { [string]: number }, -- passive.id -> scaled threshold
}

local PassiveService = {}
local playerPassiveStates: { [Player]: PlayerPassiveState } = {}
local playerLastPositions: { [Player]: Vector3 } = {}
local playerStandTimers: { [Player]: number } = {}

function PassiveService.InitPlayer(player: Player)
	local state: PlayerPassiveState = {
		passives = {},
		accumulators = {
			OnEnemyKilled = 0,
			OnDamageDealt = 0,
			OnDamageTaken = 0,
			OnHeal = 0,
			OnMove = 0,
			OnStandStill = 0,
			OnCritHit = 0,
			OnLevelUp = 0,
			OnOverdrive = 0,
			OnGainXP = 0,
			OnWaveStart = 0,
			OnWeaponFire = 0,
		},
		currentThresholds = {},
	}
	playerPassiveStates[player] = state
	playerLastPositions[player] = nil
	playerStandTimers[player] = 0
end

function PassiveService.ExportState(player: Player): any?
	local state = playerPassiveStates[player]
	if not state then return nil end

	local pairsList: { { trigger: string, effect: string } } = {}
	for _, p in ipairs(state.passives) do
		table.insert(pairsList, {
			trigger = p.trigger,
			effect = p.effect,
		})
	end

	local accCopy: { [string]: number } = {}
	for k, v in pairs(state.accumulators) do
		accCopy[k] = v
	end

	local threshCopy: { [string]: number } = {}
	for k, v in pairs(state.currentThresholds) do
		threshCopy[k] = v
	end

	return {
		pairs = pairsList,
		accumulators = accCopy,
		currentThresholds = threshCopy,
	}
end

function PassiveService.ImportState(player: Player, saved: any)
	if type(saved) ~= "table" then return end
	PassiveService.InitPlayer(player)
	local state = playerPassiveStates[player]
	if not state then return end

	if type(saved.pairs) == "table" then
		for _, entry in ipairs(saved.pairs) do
			if type(entry) == "table" and type(entry.trigger) == "string" and type(entry.effect) == "string" then
				local pDef = PassivesData.CreateDynamicPassive(
					entry.trigger :: PassivesData.TriggerCondition,
					entry.effect :: PassivesData.PassiveEffect
				)
				table.insert(state.passives, pDef)
				state.currentThresholds[pDef.id] = pDef.threshold
			end
		end
	end

	if type(saved.accumulators) == "table" then
		for k, v in pairs(saved.accumulators) do
			if type(k) == "string" and type(v) == "number" then
				(state.accumulators :: any)[k] = v
			end
		end
	end

	if type(saved.currentThresholds) == "table" then
		for k, v in pairs(saved.currentThresholds) do
			if type(k) == "string" and type(v) == "number" then
				state.currentThresholds[k] = v
			end
		end
	end

	Remotes.GetEvent("StateSync"):FireClient(player, {
		passives = state.passives,
	})
end

function PassiveService.AddPassive(player: Player, passive: PassivesData.PassiveDefinition)
	local state = playerPassiveStates[player]
	if not state then return end

	local MetaProgressionService = require(script.Parent.MetaProgressionService)
	local meta = MetaProgressionService.GetPlayerMeta(player)
	if #state.passives >= meta.passiveSlots then
		warn(string.format("[PassiveService] Player %s has reached maximum passive slots (%d)", player.Name, meta.passiveSlots))
		return
	end

	table.insert(state.passives, passive)
	state.currentThresholds[passive.id] = passive.threshold

	Remotes.GetEvent("StateSync"):FireClient(player, {
		passives = state.passives,
	})
end

function PassiveService.GetPlayerPassives(player: Player): { PassivesData.PassiveDefinition }
	local state = playerPassiveStates[player]
	if state then
		return state.passives
	end
	return {}
end

local function applyPassiveEffect(player: Player, passive: PassivesData.PassiveDefinition)
	local effect = passive.effect
	local power = passive.effectPower

	if effect == "Heal" then
		PlayerStatsManager.Heal(player, power)
	elseif effect == "GainMaxHP" then
		PlayerStatsManager.AddStat(player, "MaxHP", power)
	elseif effect == "GainStatDamage" then
		PlayerStatsManager.AddStat(player, "DamageMultiplier", power)
	elseif effect == "GainStatSpeed" then
		PlayerStatsManager.AddStat(player, "Speed", power)
	elseif effect == "GainStatFireRate" then
		PlayerStatsManager.AddStat(player, "FireRateMultiplier", power)
	elseif effect == "GainCritChance" then
		PlayerStatsManager.AddStat(player, "CriticalChance", power)
	elseif effect == "GainStatArmor" then
		PlayerStatsManager.AddStat(player, "Armor", power)
	elseif effect == "GainLifeSteal" then
		PlayerStatsManager.AddStat(player, "LifeSteal", power)
	elseif effect == "ChargeOverdrive" then
		PlayerStatsManager.ChargeOverdrive(player, power)
	elseif effect == "GainXP" then
		local XPService = require(script.Parent.XPService)
		XPService.AddXP(player, power, false)
	end

	-- Notify client with passive trigger pulse
	Remotes.GetEvent("VFXEvent"):FireClient(player, "PassiveTrigger", passive.name)
end

local function feedTrigger(player: Player, trigger: PassivesData.TriggerCondition, amount: number)
	local state = playerPassiveStates[player]
	if not state then return end

	local currentAcc = (state.accumulators[trigger] or 0) + amount
	state.accumulators[trigger] = currentAcc

	for _, passive in ipairs(state.passives) do
		if passive.trigger == trigger then
			local threshold = state.currentThresholds[passive.id] or passive.threshold
			if currentAcc >= threshold then
				state.accumulators[trigger] = currentAcc - threshold
				-- Anti-snowball: threshold scales by 2%
				state.currentThresholds[passive.id] = threshold * 1.02
				applyPassiveEffect(player, passive)
			end
		end
	end
end

-- Hook GameEvents to Passive Engine
GameEvents.OnEnemyKilled:Connect(function(enemyConfig, killerPlayer)
	if killerPlayer then
		feedTrigger(killerPlayer, "OnEnemyKilled", 1)
	end
end)

GameEvents.OnDamageDealt:Connect(function(player, amount, isCrit, enemy)
	feedTrigger(player, "OnDamageDealt", amount)
end)

GameEvents.OnDamageTaken:Connect(function(player, amount, attacker)
	feedTrigger(player, "OnDamageTaken", amount)
end)

GameEvents.OnHeal:Connect(function(player, amount)
	feedTrigger(player, "OnHeal", amount)
end)

GameEvents.OnCritHit:Connect(function(player, damage, enemy)
	feedTrigger(player, "OnCritHit", 1)
end)

GameEvents.OnLevelUp:Connect(function(player, newLevel)
	feedTrigger(player, "OnLevelUp", 1)
end)

GameEvents.OnOverdriveTriggered:Connect(function(player)
	feedTrigger(player, "OnOverdrive", 1)
end)

GameEvents.OnXPCollected:Connect(function(player, amount, isMeta)
	feedTrigger(player, "OnGainXP", amount)
end)

GameEvents.OnMove:Connect(function(player: Player, distanceTraveled: number)
	feedTrigger(player, "OnMove", distanceTraveled)
end)

GameEvents.OnStandStill:Connect(function(player: Player, duration: number)
	feedTrigger(player, "OnStandStill", duration)
end)

GameEvents.OnWeaponFired:Connect(function(player: Player, _weaponId: string)
	feedTrigger(player, "OnWeaponFire", 1)
end)

GameEvents.OnWaveStart:Connect(function(_waveNumber: number)
	for _, p in ipairs(Players:GetPlayers()) do
		feedTrigger(p, "OnWaveStart", 1)
	end
end)

-- Track physical mecha movement and immobility to feed OnMove and OnStandStill passives
RunService.Heartbeat:Connect(function(dt: number)
	for player, _ in pairs(playerPassiveStates) do
		local pData = PlayerStatsManager.GetPlayerData(player)
		if not pData or pData.isDead or pData.isLevelUpPhase then
			playerLastPositions[player] = nil
			playerStandTimers[player] = 0
			continue
		end

		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				local pos = hrp.Position
				local prevPos = playerLastPositions[player]
				if prevPos then
					local dist = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(prevPos.X, 0, prevPos.Z)).Magnitude
					if dist > 0.08 then
						GameEvents.OnMove:Fire(player, dist)
						playerStandTimers[player] = 0
					else
						local stand = (playerStandTimers[player] or 0) + dt
						if stand >= 1.0 then
							GameEvents.OnStandStill:Fire(player, 1.0)
							playerStandTimers[player] = 0
						else
							playerStandTimers[player] = stand
						end
					end
				end
				playerLastPositions[player] = pos
			end
		end
	end
end)

function PassiveService.Cleanup(player: Player)
	playerPassiveStates[player] = nil
	playerLastPositions[player] = nil
	playerStandTimers[player] = nil
end

Players.PlayerRemoving:Connect(PassiveService.Cleanup)

return PassiveService
