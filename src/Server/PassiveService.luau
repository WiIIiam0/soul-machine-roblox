--!strict
-- PassiveService.luau: Reactive event accumulator and execution engine for passive upgrades

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
		},
		currentThresholds = {},
	}
	playerPassiveStates[player] = state
end

function PassiveService.AddPassive(player: Player, passive: PassivesData.PassiveDefinition)
	local state = playerPassiveStates[player]
	if not state then return end

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

function PassiveService.Cleanup(player: Player)
	playerPassiveStates[player] = nil
end

Players.PlayerRemoving:Connect(PassiveService.Cleanup)

return PassiveService
