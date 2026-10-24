--!strict
-- PassivesData.luau: Event-driven reactive passive abilities and procedural combinations

export type TriggerCondition = 
	"OnEnemyKilled"
	| "OnDamageDealt"
	| "OnDamageTaken"
	| "OnHeal"
	| "OnMove"
	| "OnStandStill"
	| "OnCritHit"
	| "OnLevelUp"
	| "OnOverdrive"
	| "OnGainXP"

export type PassiveEffect = 
	"Heal"
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

local TRIGGER_INFO: { [TriggerCondition]: { label: string, baseThreshold: number } } = {
	OnEnemyKilled = { label = "Tous les %d ennemis détruits", baseThreshold = 8 },
	OnDamageDealt = { label = "Tous les %d dégâts infligés", baseThreshold = 140 },
	OnDamageTaken = { label = "Tous les %d dégâts subis", baseThreshold = 30 },
	OnHeal = { label = "Tous les %d PV soignés", baseThreshold = 25 },
	OnMove = { label = "Tous les %d studs parcourus", baseThreshold = 75 },
	OnStandStill = { label = "Toutes les %d s immobile", baseThreshold = 3 },
	OnCritHit = { label = "Tous les %d coups critiques", baseThreshold = 3 },
	OnLevelUp = { label = "À chaque montée de niveau", baseThreshold = 1 },
	OnOverdrive = { label = "À chaque déclenchement d'Overdrive", baseThreshold = 1 },
	OnGainXP = { label = "Tous les %d points d'XP récoltés", baseThreshold = 35 },
}
PassivesData.TRIGGER_INFO = TRIGGER_INFO

local EFFECT_INFO: { [PassiveEffect]: { label: string, basePower: number } } = {
	Heal = { label = "Régénère %.0f PV", basePower = 12 },
	GainMaxHP = { label = "+%.0f PV Max permanent", basePower = 3 },
	GainStatDamage = { label = "+%.0f%% Dégâts permanent", basePower = 0.04 },
	GainStatSpeed = { label = "+%.1f Vitesse permanente", basePower = 0.8 },
	GainStatFireRate = { label = "+%.0f%% Cadence permanente", basePower = 0.03 },
	GainCritChance = { label = "+%.0f%% Critique permanent", basePower = 2 },
	GainStatArmor = { label = "+%.0f Armure permanente", basePower = 4 },
	GainLifeSteal = { label = "+%.1f%% Vol de Vie permanent", basePower = 0.01 },
	ChargeOverdrive = { label = "Recharge l'Overdrive de %.0f%%", basePower = 15 },
	GainXP = { label = "Octroie +%.0f XP bonus", basePower = 18 },
}
PassivesData.EFFECT_INFO = EFFECT_INFO

local PREMADE_PASSIVES: { PassiveDefinition } = {
	{
		id = "VampiricProtocol",
		name = "Protocole Vampirique",
		description = "Tous les 8 ennemis détruits -> Régénère 12 PV.",
		trigger = "OnEnemyKilled",
		effect = "Heal",
		threshold = 8,
		effectPower = 12,
		icon = "rbxassetid://10709791480",
		iconFile = "CSFSimpleSkill3_C_256_09.png",
	},
	{
		id = "KineticCapacitor",
		name = "Condensateur Cinétique",
		description = "Tous les 75 studs parcourus -> Recharge l'Overdrive de 15%.",
		trigger = "OnMove",
		effect = "ChargeOverdrive",
		threshold = 75,
		effectPower = 15,
		icon = "rbxassetid://10709791130",
		iconFile = "CSFSimpleSkill3_C_256_04.png",
	},
	{
		id = "EmergencyReactor",
		name = "Réacteur de Secours",
		description = "Tous les 30 dégâts subis -> Recharge l'Overdrive de 20%.",
		trigger = "OnDamageTaken",
		effect = "ChargeOverdrive",
		threshold = 30,
		effectPower = 20,
		icon = "rbxassetid://10709791612",
		iconFile = "CSFSimpleSkill3_C_256_10.png",
	},
	{
		id = "SiegeModule",
		name = "Tourelle Siège Ancrée",
		description = "Toutes les 3s resté immobile -> Gagne +3% de Dégâts permanents.",
		trigger = "OnStandStill",
		effect = "GainStatDamage",
		threshold = 3,
		effectPower = 0.03,
		icon = "rbxassetid://10709791281",
		iconFile = "CSFSimpleSkill3_C_256_08.png",
	},
	{
		id = "OverdriveSurge",
		name = "Surtension Nucléaire",
		description = "À chaque déclenchement d'Overdrive -> Soigne 25 PV immédiatement.",
		trigger = "OnOverdrive",
		effect = "Heal",
		threshold = 1,
		effectPower = 25,
		icon = "rbxassetid://10709791437",
		iconFile = "CSFSimpleSkill3_C_256_41.png",
	},
	{
		id = "ScavengerNanites",
		name = "Nanites Récupérateurs",
		description = "Tous les 10 ennemis détruits -> +2 PV Max permanents.",
		trigger = "OnEnemyKilled",
		effect = "GainMaxHP",
		threshold = 10,
		effectPower = 2,
		icon = "rbxassetid://10709791054",
		iconFile = "CSFSimpleSkill3_C_256_07.png",
	},
	{
		id = "HyperchargeCrit",
		name = "Surcharge Critique",
		description = "Tous les 4 coups critiques -> +3% de Cadence permanente.",
		trigger = "OnCritHit",
		effect = "GainStatFireRate",
		threshold = 4,
		effectPower = 0.03,
		icon = "rbxassetid://10709791223",
		iconFile = "CSFSimpleSkill3_C_256_06.png",
	},
	{
		id = "ArmoredReinforcement",
		name = "Blindage Réactif",
		description = "Tous les 120 dégâts infligés -> +4 Armure permanente.",
		trigger = "OnDamageDealt",
		effect = "GainStatArmor",
		threshold = 120,
		effectPower = 4,
		icon = "rbxassetid://10709791281",
		iconFile = "CSFSimpleSkill3_C_256_05.png",
	},
}
PassivesData.PREMADE_PASSIVES = PREMADE_PASSIVES

local TRIGGER_PREFIXES: { [TriggerCondition]: string } = {
	OnEnemyKilled = "Exterminateur",
	OnDamageDealt = "Percuteur",
	OnDamageTaken = "Riposte",
	OnHeal = "Régénérateur",
	OnMove = "Cinétique",
	OnStandStill = "Bunker",
	OnCritHit = "Précision",
	OnLevelUp = "Évolution",
	OnOverdrive = "Surtension",
	OnGainXP = "Moissonneur",
}

local EFFECT_SUFFIXES: { [PassiveEffect]: { name: string, iconFile: string } } = {
	Heal = { name = "de Réparation", iconFile = "CSFSimpleSkill3_C_256_01.png" },
	GainMaxHP = { name = "de Vitalité", iconFile = "CSFSimpleSkill3_C_256_01.png" },
	GainStatDamage = { name = "de Puissance", iconFile = "CSFSimpleSkill3_C_256_02.png" },
	GainStatSpeed = { name = "de Vélocité", iconFile = "CSFSimpleSkill3_C_256_04.png" },
	GainStatFireRate = { name = "de Cadence", iconFile = "CSFSimpleSkill3_C_256_03.png" },
	GainCritChance = { name = "Létal", iconFile = "CSFSimpleSkill3_C_256_06.png" },
	GainStatArmor = { name = "de Blindage", iconFile = "CSFSimpleSkill3_C_256_05.png" },
	GainLifeSteal = { name = "Vampirique", iconFile = "CSFSimpleSkill3_C_256_09.png" },
	ChargeOverdrive = { name = "Nucléaire", iconFile = "CSFSimpleSkill3_C_256_41.png" },
	GainXP = { name = "d'Optimisation", iconFile = "CSFSimpleSkill3_C_256_07.png" },
}

function PassivesData.GenerateProceduralPassive(seed: number): PassiveDefinition
	local rng = Random.new(seed)
	local triggers: { TriggerCondition } = {
		"OnEnemyKilled", "OnDamageDealt", "OnDamageTaken", "OnMove", "OnStandStill", "OnCritHit", "OnGainXP",
	}
	local effects: { PassiveEffect } = {
		"Heal", "GainMaxHP", "GainStatDamage", "GainStatSpeed", "GainStatFireRate", "GainCritChance", "GainStatArmor", "ChargeOverdrive",
	}

	local chosenTrigger = triggers[rng:NextInteger(1, #triggers)]
	local chosenEffect = effects[rng:NextInteger(1, #effects)]

	local tInfo = PassivesData.TRIGGER_INFO[chosenTrigger]
	local eInfo = PassivesData.EFFECT_INFO[chosenEffect]

	local threshold = tInfo.baseThreshold
	local power = eInfo.basePower

	local triggerText = string.format(tInfo.label, threshold)
	local effectText: string
	if chosenEffect == "GainStatDamage" or chosenEffect == "GainStatFireRate" then
		effectText = string.format(eInfo.label, power * 100)
	elseif chosenEffect == "GainLifeSteal" then
		effectText = string.format(eInfo.label, power * 100)
	else
		effectText = string.format(eInfo.label, power)
	end

	local desc = triggerText .. " ➔ " .. effectText

	local prefix = TRIGGER_PREFIXES[chosenTrigger] or "Module"
	local effData = EFFECT_SUFFIXES[chosenEffect] or { name = "de Réaction", iconFile = "CSFSimpleSkill3_C_256_41.png" }
	local fullName = string.format("Module %s %s", prefix, effData.name)

	return {
		id = "ProcPassive_" .. tostring(seed),
		name = fullName,
		description = desc,
		trigger = chosenTrigger,
		effect = chosenEffect,
		threshold = threshold,
		effectPower = power,
		icon = "rbxassetid://10709791437",
		iconFile = effData.iconFile,
	}
end

return PassivesData
