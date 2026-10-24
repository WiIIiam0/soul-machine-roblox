--!strict
-- MetaProgressionData.luau
-- 100% faithful port of Unity TheSwarm MetaProgressionManager.cs & SampleScene.unity
-- Governs persistent account progression (ADN / totalXP), slot capacities, rank caps, and unlock pools.

export type MetaUnlockType =
	| "WeaponSlot"
	| "PassiveSlot"
	| "StatSlot"
	| "WeaponItem"
	| "StatItem"
	| "WeaponMaxRank"
	| "StatMaxRank"
	| "PassiveTrigger"
	| "PassiveEffect"

export type MetaUnlock = {
	unlockName: string,
	unlockType: MetaUnlockType,
	requiredXP: number,
	weaponUnlock: string?,
	statUnlock: string?,
	triggerUnlock: string?,
	effectUnlock: string?,
	description: string?,
}

local MetaProgressionData = {}

local BASE_SLOTS = 0
local MAX_SLOTS = 8

-- 1. ARSENAL DE BASE (0 XP ADN) - Matches freeUnlocks in Unity SampleScene.unity
local FREE_UNLOCKS: { MetaUnlock } = {
	{ unlockName = "FreeWeaponSlot", unlockType = "WeaponSlot", requiredXP = 0 },
	{ unlockName = "FreePassiveSlot", unlockType = "PassiveSlot", requiredXP = 0 },
	{ unlockName = "FreeStatSlot", unlockType = "StatSlot", requiredXP = 0 },
	{ unlockName = "FreeWeaponMaxRank", unlockType = "WeaponMaxRank", requiredXP = 0 },
	{ unlockName = "FreeStatMaxRank", unlockType = "StatMaxRank", requiredXP = 0 },

	-- Base weapons unlocked at start
	{ unlockName = "Rifle", unlockType = "WeaponItem", requiredXP = 0, weaponUnlock = "Rifle" },
	{ unlockName = "Pompe", unlockType = "WeaponItem", requiredXP = 0, weaponUnlock = "Pompe" },
	{ unlockName = "Taser", unlockType = "WeaponItem", requiredXP = 0, weaponUnlock = "Taser" },

	-- Base stats unlocked at start
	{ unlockName = "DamageMultiplier", unlockType = "StatItem", requiredXP = 0, statUnlock = "DamageMultiplier" },
	{ unlockName = "Speed", unlockType = "StatItem", requiredXP = 0, statUnlock = "Speed" },
	{ unlockName = "FireRateMultiplier", unlockType = "StatItem", requiredXP = 0, statUnlock = "FireRateMultiplier" },
	{ unlockName = "MaxHP", unlockType = "StatItem", requiredXP = 0, statUnlock = "MaxHP" },

	-- Base passive triggers & effects unlocked at start
	{ unlockName = "OnKill", unlockType = "PassiveTrigger", requiredXP = 0, triggerUnlock = "OnKill" },
	{ unlockName = "OnDamageTaken", unlockType = "PassiveTrigger", requiredXP = 0, triggerUnlock = "OnDamageTaken" },
	{ unlockName = "OnLowHP", unlockType = "PassiveTrigger", requiredXP = 0, triggerUnlock = "OnLowHP" },

	{ unlockName = "DamageBoost", unlockType = "PassiveEffect", requiredXP = 0, effectUnlock = "GainStatDamage" },
	{ unlockName = "Heal", unlockType = "PassiveEffect", requiredXP = 0, effectUnlock = "Heal" },
	{ unlockName = "SpeedBoost", unlockType = "PassiveEffect", requiredXP = 0, effectUnlock = "GainStatSpeed" },
}

-- 2. FRISE DE PROGRESSION ADN - Matches timelineUnlocks in Unity SampleScene.unity
local TIMELINE_UNLOCKS: { MetaUnlock } = {
	{ unlockName = "Palier 1: StatSlot", unlockType = "StatSlot", requiredXP = 1, description = "+1 Emplacement Stat (Total: 2)" },
	{ unlockName = "Palier 2: StatMaxRank", unlockType = "StatMaxRank", requiredXP = 3, description = "Rang Max Stat augmenté (+3)" },
	{ unlockName = "Palier 3: DarkStorm", unlockType = "WeaponItem", requiredXP = 6, weaponUnlock = "DarkStorm", description = "Arme débloquée : Tempête Noire (DarkStorm)" },
	{ unlockName = "Palier 4: WeaponSlot", unlockType = "WeaponSlot", requiredXP = 10, description = "+1 Emplacement Arme (Total: 2)" },
	{ unlockName = "Palier 5: Armor", unlockType = "StatItem", requiredXP = 13, statUnlock = "Armor", description = "Stat débloquée : Blindage (Armor)" },
	{ unlockName = "Palier 6: Bleed", unlockType = "PassiveEffect", requiredXP = 18, effectUnlock = "Bleed", description = "Effet passif débloqué : Saignement" },
	{ unlockName = "Palier 7: PassiveSlot", unlockType = "PassiveSlot", requiredXP = 22, description = "+1 Emplacement Passif (Total: 2)" },
	{ unlockName = "Palier 8: OnCrit", unlockType = "PassiveTrigger", requiredXP = 28, triggerUnlock = "OnCrit", description = "Déclencheur passif : Sur Coup Critique" },
	{ unlockName = "Palier 9: WeaponMaxRank", unlockType = "WeaponMaxRank", requiredXP = 35, description = "Rang Max Arme augmenté (+1)" },
	{ unlockName = "Palier 10: OnDodge", unlockType = "PassiveTrigger", requiredXP = 42, triggerUnlock = "OnDodge", description = "Déclencheur passif : Sur Esquive / Dash" },
	{ unlockName = "Palier 11: Shield", unlockType = "PassiveEffect", requiredXP = 51, effectUnlock = "Shield", description = "Effet passif débloqué : Bouclier d'Énergie" },
	{ unlockName = "Palier 12: StatMaxRank", unlockType = "StatMaxRank", requiredXP = 61, description = "Rang Max Stat augmenté (+3)" },
	{ unlockName = "Palier 13: OnWaveStart", unlockType = "PassiveTrigger", requiredXP = 72, triggerUnlock = "OnWaveStart", description = "Déclencheur passif : Début de Vague" },
	{ unlockName = "Palier 14: CriticalChance", unlockType = "StatItem", requiredXP = 85, statUnlock = "CriticalChance", description = "Stat débloquée : Chances Critiques" },
	{ unlockName = "Palier 15: Eventail", unlockType = "WeaponItem", requiredXP = 100, weaponUnlock = "Eventail", description = "Arme débloquée : Fusil Éventail" },
	{ unlockName = "Palier 16: Explosion", unlockType = "PassiveEffect", requiredXP = 118, effectUnlock = "Explosion", description = "Effet passif débloqué : Explosion Réactive" },
	{ unlockName = "Palier 17: OnKillStreak", unlockType = "PassiveTrigger", requiredXP = 138, triggerUnlock = "OnKillStreak", description = "Déclencheur passif : Série de Victimes" },
	{ unlockName = "Palier 18: StatSlot", unlockType = "StatSlot", requiredXP = 160, description = "+1 Emplacement Stat (Total: 3)" },
	{ unlockName = "Palier 19: LifeSteal", unlockType = "StatItem", requiredXP = 187, statUnlock = "LifeSteal", description = "Stat débloquée : Vol de Vie" },
	{ unlockName = "Palier 20: OnOverdrive", unlockType = "PassiveTrigger", requiredXP = 217, triggerUnlock = "OnOverdrive", description = "Déclencheur passif : Activation Overdrive" },
	{ unlockName = "Palier 21: WeaponSlot", unlockType = "WeaponSlot", requiredXP = 252, description = "+1 Emplacement Arme (Total: 3)" },
	{ unlockName = "Palier 22: OnShieldBreak", unlockType = "PassiveTrigger", requiredXP = 292, triggerUnlock = "OnShieldBreak", description = "Déclencheur passif : Rupture de Bouclier" },
	{ unlockName = "Palier 23: OnTimer", unlockType = "PassiveTrigger", requiredXP = 338, triggerUnlock = "OnTimer", description = "Déclencheur passif : Périodique (Chrono)" },
	{ unlockName = "Palier 24: FireMissile", unlockType = "WeaponItem", requiredXP = 391, weaponUnlock = "FireMissile", description = "Arme débloquée : Missile Incendiaire Pyros" },
	{ unlockName = "Palier 25: ChainLightning", unlockType = "PassiveEffect", requiredXP = 452, effectUnlock = "ChainLightning", description = "Effet passif débloqué : Éclair en Chaîne" },
	{ unlockName = "Palier 26: OnLevelUp", unlockType = "PassiveTrigger", requiredXP = 522, triggerUnlock = "OnLevelUp", description = "Déclencheur passif : Montée de Niveau" },
}

MetaProgressionData.FREE_UNLOCKS = FREE_UNLOCKS
MetaProgressionData.TIMELINE_UNLOCKS = TIMELINE_UNLOCKS
MetaProgressionData.BASE_SLOTS = BASE_SLOTS
MetaProgressionData.MAX_SLOTS = MAX_SLOTS

-- Calculate slots count for a category, capped at MAX_SLOTS (8)
function MetaProgressionData.CalculateSlotsForCategory(totalXP: number, category: MetaUnlockType): number
	local slots = BASE_SLOTS
	for _, u in ipairs(FREE_UNLOCKS) do
		if u.unlockType == category then
			slots += 1
		end
	end
	for _, u in ipairs(TIMELINE_UNLOCKS) do
		if u.unlockType == category and totalXP >= u.requiredXP then
			slots += 1
		end
	end
	return math.min(slots, MAX_SLOTS)
end

function MetaProgressionData.GetMaxWeaponSlots(totalXP: number): number
	return MetaProgressionData.CalculateSlotsForCategory(totalXP, "WeaponSlot")
end

function MetaProgressionData.GetMaxPassiveSlots(totalXP: number): number
	return MetaProgressionData.CalculateSlotsForCategory(totalXP, "PassiveSlot")
end

function MetaProgressionData.GetMaxStatSlots(totalXP: number): number
	return MetaProgressionData.CalculateSlotsForCategory(totalXP, "StatSlot")
end

-- Weapon rank cap (starts at 1, +1 per WeaponMaxRank unlock)
function MetaProgressionData.GetMaxWeaponRank(totalXP: number): number
	local rank = 0
	for _, u in ipairs(FREE_UNLOCKS) do
		if u.unlockType == "WeaponMaxRank" then rank += 1 end
	end
	for _, u in ipairs(TIMELINE_UNLOCKS) do
		if u.unlockType == "WeaponMaxRank" and totalXP >= u.requiredXP then rank += 1 end
	end
	return math.max(1, rank)
end

-- Stat rank cap (starts at 3, +3 per StatMaxRank unlock, default minimum 1)
function MetaProgressionData.GetMaxStatRank(totalXP: number): number
	local rank = 0
	for _, u in ipairs(FREE_UNLOCKS) do
		if u.unlockType == "StatMaxRank" then rank += 3 end
	end
	for _, u in ipairs(TIMELINE_UNLOCKS) do
		if u.unlockType == "StatMaxRank" and totalXP >= u.requiredXP then rank += 3 end
	end
	return math.max(1, rank)
end

-- Check weapon unlock status
function MetaProgressionData.IsWeaponUnlocked(totalXP: number, weaponId: string): boolean
	if weaponId == "StarterGun" then return true end
	for _, u in ipairs(FREE_UNLOCKS) do
		if u.unlockType == "WeaponItem" and u.weaponUnlock == weaponId then return true end
	end
	for _, u in ipairs(TIMELINE_UNLOCKS) do
		if u.unlockType == "WeaponItem" and u.weaponUnlock == weaponId and totalXP >= u.requiredXP then
			return true
		end
	end
	return false
end

-- Check stat unlock status
function MetaProgressionData.IsStatUnlocked(totalXP: number, statType: string): boolean
	for _, u in ipairs(FREE_UNLOCKS) do
		if u.unlockType == "StatItem" and u.statUnlock == statType then return true end
	end
	for _, u in ipairs(TIMELINE_UNLOCKS) do
		if u.unlockType == "StatItem" and u.statUnlock == statType and totalXP >= u.requiredXP then
			return true
		end
	end
	return false
end

-- Check passive trigger unlock status
function MetaProgressionData.IsPassiveTriggerUnlocked(totalXP: number, trigger: string): boolean
	for _, u in ipairs(FREE_UNLOCKS) do
		if u.unlockType == "PassiveTrigger" and u.triggerUnlock == trigger then return true end
	end
	for _, u in ipairs(TIMELINE_UNLOCKS) do
		if u.unlockType == "PassiveTrigger" and u.triggerUnlock == trigger and totalXP >= u.requiredXP then
			return true
		end
	end
	return false
end

-- Check passive effect unlock status
function MetaProgressionData.IsPassiveEffectUnlocked(totalXP: number, effect: string): boolean
	for _, u in ipairs(FREE_UNLOCKS) do
		if u.unlockType == "PassiveEffect" and u.effectUnlock == effect then return true end
	end
	for _, u in ipairs(TIMELINE_UNLOCKS) do
		if u.unlockType == "PassiveEffect" and u.effectUnlock == effect and totalXP >= u.requiredXP then
			return true
		end
	end
	return false
end

-- Check if premade passive is unlocked based on its triggers and effects
function MetaProgressionData.IsPassiveUnlocked(totalXP: number, passiveId: string): boolean
	-- Basic starter passives are unlocked at 0 XP
	local starterPassives: { [string]: boolean } = {
		VampiricProtocol = true,
		KineticCapacitor = true,
		EmergencyReactor = true,
		ArmoredReinforcement = true,
	}
	if starterPassives[passiveId] then return true end

	if passiveId == "ScavengerNanites" then
		return totalXP >= 18
	elseif passiveId == "HyperchargeCrit" then
		return totalXP >= 28
	elseif passiveId == "SiegeModule" then
		return totalXP >= 51
	elseif passiveId == "OverdriveSurge" then
		return totalXP >= 217
	end
	return totalXP >= 100
end

-- Max timeline milestone XP (for calibrating the timeline progress bar)
function MetaProgressionData.GetMaxTimelineXP(): number
	local maxXP = 1
	for _, u in ipairs(TIMELINE_UNLOCKS) do
		if u.requiredXP > maxXP then
			maxXP = u.requiredXP
		end
	end
	return maxXP
end

-- Next upcoming milestone XP (the upcoming padlock)
function MetaProgressionData.GetNextUpcomingXP(): number
	local current = 1
	for i = 1, #TIMELINE_UNLOCKS + 1 do
		if i == 1 then
			current = 1
		else
			current = (current + 2) * 1.15
		end
	end
	return math.round(current)
end

-- Get newly unlocked milestones between startingXP and totalXP
function MetaProgressionData.GetNewlyUnlockedItems(startingXP: number, totalXP: number): { MetaUnlock }
	local newly: { MetaUnlock } = {}
	for _, u in ipairs(TIMELINE_UNLOCKS) do
		if u.requiredXP > startingXP and u.requiredXP <= totalXP then
			table.insert(newly, u)
		end
	end
	return newly
end

return MetaProgressionData
