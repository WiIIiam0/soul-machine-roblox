--!strict
-- PassivesData.luau: Combinatorial Dynamic Passives (Trigger x Effect) mirroring TheSwarm RewardManager.cs & PassiveManager.cs

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

local EFFECT_ICONS: { [PassiveEffect]: string } = {
	Heal = "rbxassetid://10709791480",
	GainMaxHP = "rbxassetid://10709791557",
	GainStatDamage = "rbxassetid://10709791334",
	GainStatSpeed = "rbxassetid://10709791667",
	GainStatFireRate = "rbxassetid://10709791281",
	GainCritChance = "rbxassetid://10709791223",
	GainStatArmor = "rbxassetid://10709791612",
	GainLifeSteal = "rbxassetid://10709791480",
	ChargeOverdrive = "rbxassetid://10709791130",
	GainXP = "rbxassetid://10709791054",
}

local EFFECT_ICON_FILES: { [PassiveEffect]: string } = {
	Heal = "CSFSimpleSkill3_C_256_01.png",
	GainMaxHP = "CSFSimpleSkill3_C_256_01.png",
	GainStatDamage = "CSFSimpleSkill3_C_256_02.png",
	GainStatSpeed = "CSFSimpleSkill3_C_256_04.png",
	GainStatFireRate = "CSFSimpleSkill3_C_256_03.png",
	GainCritChance = "CSFSimpleSkill3_C_256_06.png",
	GainStatArmor = "CSFSimpleSkill3_C_256_05.png",
	GainLifeSteal = "CSFSimpleSkill3_C_256_09.png",
	ChargeOverdrive = "CSFSimpleSkill3_C_256_41.png",
	GainXP = "CSFSimpleSkill3_C_256_07.png",
}

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

	return {
		id = string.format("Dyn_%s_%s", trigger, effect),
		name = string.format("%s\n▼\n%s", tName, eName),
		description = string.format("(%s)", valFormatted),
		trigger = trigger,
		effect = effect,
		threshold = TRIGGER_THRESHOLDS[trigger] or 5,
		effectPower = val,
		icon = EFFECT_ICONS[effect] or "rbxassetid://10709791437",
		iconFile = EFFECT_ICON_FILES[effect] or "CSFSimpleSkill3_C_256_08.png",
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
