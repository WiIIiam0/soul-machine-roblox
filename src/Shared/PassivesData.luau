--!strict
-- PassivesData.luau: Combinatorial Dynamic Passives (Trigger x Effect) with 100% exact Unity SampleScene.unity icons & scaling colors

export type TriggerCondition =
	| "OnEnemyKilled"
	| "OnDamageDealt"
	| "OnDamageTaken"
	| "OnHeal"
	| "OnMove"
	| "OnStandStill"
	| "OnCritHit"
	| "OnLevelUp"
	| "OnOverdrive"
	| "OnGainXP"
	| "OnWaveStart"
	| "OnWeaponFire"

export type PassiveEffect =
	| "Heal"
	| "GainMaxHP"
	| "GainStatDamage"
	| "GainStatSpeed"
	| "GainStatFireRate"
	| "GainCritChance"
	| "GainStatArmor"
	| "GainLifeSteal"
	| "ChargeOverdrive"
	| "GainXP"

export type PassiveDefinition = {
	id: string,
	name: string,
	description: string,
	trigger: TriggerCondition,
	effect: PassiveEffect,
	threshold: number,
	effectPower: number,
	icon: string,
	iconFile: string,
	triggerIconFile: string,
	effectIconFile: string,
	triggerScalingStat: string,
	effectScalingStat: string,
}

local PassivesData = {}

-- French translations directly from TheSwarm translations.csv
local TRIGGER_LABELS: { [TriggerCondition]: string } = {
	OnEnemyKilled = "À l'élimination",
	OnDamageDealt = "Dégâts infligés",
	OnDamageTaken = "Dégâts reçus",
	OnHeal = "Au soin",
	OnMove = "Au déplacement",
	OnStandStill = "À l'immobilité",
	OnCritHit = "Au coup critique",
	OnLevelUp = "Niveau supérieur",
	OnOverdrive = "Lors de l'Overdrive",
	OnGainXP = "Au gain d'XP",
	OnWaveStart = "Début de vague",
	OnWeaponFire = "Au tir d'arme",
}
PassivesData.TRIGGER_LABELS = TRIGGER_LABELS

local EFFECT_LABELS: { [PassiveEffect]: string } = {
	Heal = "Soin direct",
	GainMaxHP = "+PV Max",
	GainStatDamage = "+Dégâts",
	GainStatSpeed = "+Vitesse",
	GainStatFireRate = "+Cadence",
	GainCritChance = "+Critique",
	GainStatArmor = "+Armure",
	GainLifeSteal = "+Vol de Vie",
	ChargeOverdrive = "Charge Overdrive",
	GainXP = "+XP Bonus",
}
PassivesData.EFFECT_LABELS = EFFECT_LABELS

-- Exact bucket threshold per trigger from PassiveManager.cs
local TRIGGER_THRESHOLDS: { [TriggerCondition]: number } = {
	OnEnemyKilled = 3,
	OnDamageDealt = 10,
	OnDamageTaken = 4,
	OnHeal = 10,
	OnMove = 10,
	OnStandStill = 3,
	OnCritHit = 1,
	OnLevelUp = 1,
	OnOverdrive = 1,
	OnGainXP = 5,
	OnWaveStart = 1,
	OnWeaponFire = 10,
}
PassivesData.TRIGGER_THRESHOLDS = TRIGGER_THRESHOLDS

-- Trigger rarity/frequency multipliers from RewardManager.cs
local TRIGGER_MULTIPLIERS: { [TriggerCondition]: number } = {
	OnLevelUp = 6.0,
	OnWaveStart = 10.0,
	OnEnemyKilled = 0.2,
	OnWeaponFire = 0.01,
	OnDamageTaken = 5.0,
	OnHeal = 1.0,
	OnStandStill = 5.0,
	OnCritHit = 1.0,
	OnMove = 0.001,
	OnGainXP = 0.1,
	OnOverdrive = 5.0,
	OnDamageDealt = 0.1,
}

-- Base consequence powers from RewardManager.cs
local EFFECT_BASES: { [PassiveEffect]: number } = {
	Heal = 2.0,
	GainMaxHP = 0.5,
	GainStatDamage = 0.02,     -- +2% per unit
	GainStatSpeed = 0.10,      -- +0.1 speed
	GainStatFireRate = 0.02,   -- +2% fire rate
	GainCritChance = 1.0,      -- +1% crit
	GainStatArmor = 1.0,       -- +1 armor
	GainLifeSteal = 0.005,     -- +0.5% life steal
	ChargeOverdrive = 5.0,     -- +5% overdrive
	GainXP = 2.0,              -- +2 XP
}

-- 100% Exact Trigger Sprite GUID mappings from Unity SampleScene.unity RewardManager.triggerIcons
local TRIGGER_ICON_FILES: { [TriggerCondition]: string } = {
	OnEnemyKilled = "CSFSimpleSkill3_C_256_71.png",
	OnDamageDealt = "CSFSimpleSkill3_C_256_23.png",
	OnDamageTaken = "CSFSimpleSkill3_C_256_67.png",
	OnHeal = "CSFSimpleSkill3_C_256_30.png",
	OnLevelUp = "CSFSimpleSkill3_C_256_42.png",
	OnMove = "CSFSimpleSkill3_C_256_05.png",
	OnOverdrive = "CSFSimpleSkill3_C_256_68.png",
	OnWaveStart = "CSFSimpleSkill3_C_256_68.png",
	OnCritHit = "CSFSimpleSkill3_C_256_63.png",
	OnGainXP = "CSFSimpleSkill3_C_256_56.png",
	OnStandStill = "CSFSimpleSkill3_C_256_43.png",
	OnWeaponFire = "CSFSimpleSkill3_C_256_45.png",
}
PassivesData.TRIGGER_ICON_FILES = TRIGGER_ICON_FILES

-- 100% Exact Effect Sprite GUID mappings from Unity SampleScene.unity RewardManager.effectIcons
local EFFECT_ICON_FILES: { [PassiveEffect]: string } = {
	Heal = "CSFSimpleSkill3_C_256_30.png",
	GainMaxHP = "CSFSimpleSkill3_C_256_55.png",
	GainStatDamage = "CSFSimpleSkill3_C_256_23.png",
	GainStatSpeed = "CSFSimpleSkill3_C_256_05.png",
	ChargeOverdrive = "CSFSimpleSkill3_C_256_68.png",
	GainXP = "CSFSimpleSkill3_C_256_56.png",
	GainStatArmor = "CSFSimpleSkill3_C_256_81.png",
	GainStatFireRate = "CSFSimpleSkill3_C_256_50.png",
	GainCritChance = "CSFSimpleSkill3_C_256_80.png",
	GainLifeSteal = "CSFSimpleSkill3_C_256_32.png",
}
PassivesData.EFFECT_ICON_FILES = EFFECT_ICON_FILES

local EFFECT_ICONS: { [PassiveEffect]: string } = {
	Heal = "rbxassetid://10709791480",
	GainMaxHP = "rbxassetid://10709791437",
	GainStatDamage = "rbxassetid://10709791557",
	GainStatSpeed = "rbxassetid://10709791130",
	ChargeOverdrive = "rbxassetid://10709791130",
	GainXP = "rbxassetid://10709791054",
	GainStatArmor = "rbxassetid://10709791281",
	GainStatFireRate = "rbxassetid://10709791334",
	GainCritChance = "rbxassetid://10709791223",
	GainLifeSteal = "rbxassetid://10709791480",
}

local TRIGGER_ICONS: { [TriggerCondition]: string } = {
	OnEnemyKilled = "rbxassetid://10709791557",
	OnDamageDealt = "rbxassetid://10709791334",
	OnDamageTaken = "rbxassetid://10709791281",
	OnHeal = "rbxassetid://10709791480",
	OnLevelUp = "rbxassetid://10709791667",
	OnMove = "rbxassetid://10709791130",
	OnOverdrive = "rbxassetid://10709791130",
	OnWaveStart = "rbxassetid://10709791667",
	OnCritHit = "rbxassetid://10709791223",
	OnGainXP = "rbxassetid://10709791054",
	OnStandStill = "rbxassetid://10709791437",
	OnWeaponFire = "rbxassetid://10709791334",
}

-- Exact ScalingStat color refs from Unity RewardManager.cs GetTriggerScalingStat / GetEffectScalingStat
local TRIGGER_SCALING_STATS: { [TriggerCondition]: string } = {
	OnCritHit = "CriticalChance",
}

local EFFECT_SCALING_STATS: { [PassiveEffect]: string } = {
	GainStatArmor = "Armor",
	GainStatDamage = "DamageMultiplier",
	GainStatSpeed = "Speed",
	GainMaxHP = "MaxHP",
	GainStatFireRate = "FireRateMultiplier",
	GainCritChance = "CriticalChance",
	GainLifeSteal = "LifeSteal",
}

function PassivesData.GetTriggerIconFile(trigger: TriggerCondition): string
	return TRIGGER_ICON_FILES[trigger] or "CSFSimpleSkill3_C_256_48.png"
end

function PassivesData.GetEffectIconFile(effect: PassiveEffect): string
	return EFFECT_ICON_FILES[effect] or "CSFSimpleSkill3_C_256_48.png"
end

function PassivesData.GetTriggerScalingStat(trigger: TriggerCondition): string
	return TRIGGER_SCALING_STATS[trigger] or "None"
end

function PassivesData.GetEffectScalingStat(effect: PassiveEffect): string
	return EFFECT_SCALING_STATS[effect] or "None"
end

function PassivesData.CalculateDynamicPassiveValue(trigger: TriggerCondition, effect: PassiveEffect): number
	local tMult = TRIGGER_MULTIPLIERS[trigger] or 1.0
	local eBase = EFFECT_BASES[effect] or 1.0
	return tMult * eBase
end

function PassivesData.CreateDynamicPassive(trigger: TriggerCondition, effect: PassiveEffect): PassiveDefinition
	local val = PassivesData.CalculateDynamicPassiveValue(trigger, effect)
	local tName = TRIGGER_LABELS[trigger] or trigger
	local eName = EFFECT_LABELS[effect] or effect

	local valFormatted: string
	if effect == "GainStatDamage" or effect == "GainStatFireRate" or effect == "GainLifeSteal" then
		valFormatted = string.format("+%.1f%%", val * 100)
	else
		valFormatted = string.format("+%.1f", val)
	end

	local tIconFile = PassivesData.GetTriggerIconFile(trigger)
	local eIconFile = PassivesData.GetEffectIconFile(effect)

	return {
		id = string.format("Dyn_%s_%s", trigger, effect),
		name = string.format("%s\n▼\n%s", tName, eName),
		description = string.format("(%s)", valFormatted),
		trigger = trigger,
		effect = effect,
		threshold = TRIGGER_THRESHOLDS[trigger] or 5,
		effectPower = val,
		icon = EFFECT_ICONS[effect] or "rbxassetid://10709791437",
		iconFile = eIconFile,
		triggerIcon = TRIGGER_ICONS[trigger] or "rbxassetid://10709791557",
		effectIcon = EFFECT_ICONS[effect] or "rbxassetid://10709791437",
		triggerIconFile = tIconFile,
		effectIconFile = eIconFile,
		triggerScalingStat = PassivesData.GetTriggerScalingStat(trigger),
		effectScalingStat = PassivesData.GetEffectScalingStat(effect),
	}
end

-- Default base unlock pools matching Unity SampleScene.unity freeUnlocks
PassivesData.BASE_UNLOCKED_TRIGGERS = {
	"OnEnemyKilled", "OnDamageDealt", "OnMove", "OnWeaponFire", "OnDamageTaken",
}

PassivesData.BASE_UNLOCKED_EFFECTS = {
	"Heal", "GainStatDamage", "ChargeOverdrive", "GainMaxHP", "GainStatSpeed",
}

return PassivesData
