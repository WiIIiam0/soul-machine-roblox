--!strict
-- StatTypes.luau: Statistics definitions, exact Unity SampleScene.unity icons & statColors, and calculation helpers

export type StatType =
	"MaxHP"
	| "Speed"
	| "DamageMultiplier"
	| "FireRateMultiplier"
	| "Armor"
	| "CriticalChance"
	| "PickupRadius"
	| "LifeSteal"
	| "BurnDamage"
	| "RangeMultiplier"

export type PlayerStats = {
	MaxHP: number,
	Speed: number,
	DamageMultiplier: number,
	FireRateMultiplier: number,
	Armor: number,
	CriticalChance: number,
	PickupRadius: number,
	LifeSteal: number,
	BurnDamage: number,
	RangeMultiplier: number,
}

local StatTypes = {}

local DEFAULT_STATS: PlayerStats = {
	MaxHP = 100,
	Speed = 22,               -- Default Roblox Humanoid WalkSpeed is 16, 22 gives dynamic mecha feel
	DamageMultiplier = 1.0,   -- 100%
	FireRateMultiplier = 1.0, -- 100%
	Armor = 0,                -- 0% damage reduction
	CriticalChance = 5,       -- 5%
	PickupRadius = 18,        -- 18 studs pickup vacuum
	LifeSteal = 0.0,          -- 0%
	BurnDamage = 3.0,         -- 3 damage per burn tick
	RangeMultiplier = 1.0,    -- 100%
}
StatTypes.DEFAULT_STATS = DEFAULT_STATS

-- Exact RGB colors from Unity SampleScene.unity UIManager.statColors
local STAT_COLORS: { [string]: Color3 } = {
	MaxHP = Color3.fromRGB(136, 215, 134),
	MaxHealth = Color3.fromRGB(136, 215, 134),
	Speed = Color3.fromRGB(123, 118, 238),
	DamageMultiplier = Color3.fromRGB(236, 142, 142),
	FireRateMultiplier = Color3.fromRGB(133, 222, 236),
	Armor = Color3.fromRGB(145, 122, 95),
	CriticalChance = Color3.fromRGB(255, 250, 96),
	PickupRadius = Color3.fromRGB(255, 177, 82),
	LifeSteal = Color3.fromRGB(255, 153, 247),
	BurnDamage = Color3.fromRGB(178, 34, 34),
	RangeMultiplier = Color3.fromRGB(151, 88, 209),
}
StatTypes.STAT_COLORS = STAT_COLORS

function StatTypes.GetStatColor(statKey: string?): Color3?
	if not statKey or statKey == "None" or statKey == "" then
		return nil
	end
	return STAT_COLORS[statKey]
end

-- Exact Sprite GUID mappings from Unity SampleScene.unity RewardManager
local STAT_CONFIG: { [StatType]: { name: string, icon: string, iconFile: string, color: Color3, tag: string, perLevelBonus: number, format: (val: number) -> string, desc: string } } = {
	MaxHP = {
		name = "Points de Vie Max",
		icon = "rbxassetid://10709791437",
		iconFile = "CSFSimpleSkill3_C_256_55.png",
		color = STAT_COLORS.MaxHP,
		tag = "PV+",
		perLevelBonus = 20,
		format = function(v) return string.format("+%.0f PV", v) end,
		desc = "Augmente les points de vie maximaux de ton Mécha.",
	},
	Speed = {
		name = "Propulsion / Vitesse",
		icon = "rbxassetid://10709791130",
		iconFile = "CSFSimpleSkill3_C_256_05.png",
		color = STAT_COLORS.Speed,
		tag = "VIT+",
		perLevelBonus = 2.0,
		format = function(v) return string.format("+%.1f Vitesse", v) end,
		desc = "Permet d'esquiver plus facilement les essaims.",
	},
	DamageMultiplier = {
		name = "Puissance de Feu",
		icon = "rbxassetid://10709791557",
		iconFile = "CSFSimpleSkill3_C_256_23.png",
		color = STAT_COLORS.DamageMultiplier,
		tag = "DMG+",
		perLevelBonus = 0.12,
		format = function(v) return string.format("+%.0f%% Dégâts", v * 100) end,
		desc = "Multiplie les dégâts infligés par toutes les armes.",
	},
	FireRateMultiplier = {
		name = "Cadence de Tir",
		icon = "rbxassetid://10709791334",
		iconFile = "CSFSimpleSkill3_C_256_50.png",
		color = STAT_COLORS.FireRateMultiplier,
		tag = "CAD+",
		perLevelBonus = 0.08,
		format = function(v) return string.format("+%.0f%% Cadence", v * 100) end,
		desc = "Réduit le temps de recharge entre chaque rafale.",
	},
	Armor = {
		name = "Blindage / Armure",
		icon = "rbxassetid://10709791281",
		iconFile = "CSFSimpleSkill3_C_256_81.png",
		color = STAT_COLORS.Armor,
		tag = "ARM+",
		perLevelBonus = 12,
		format = function(v) return string.format("+%.0f Armure", v) end,
		desc = "100 d'armure réduit les dégâts subis de 50%.",
	},
	CriticalChance = {
		name = "Chances de Critique",
		icon = "rbxassetid://10709791223",
		iconFile = "CSFSimpleSkill3_C_256_80.png",
		color = STAT_COLORS.CriticalChance,
		tag = "CRT+",
		perLevelBonus = 4,
		format = function(v) return string.format("+%.0f%% Critique", v) end,
		desc = "Chances d'infliger le double de dégâts (x2).",
	},
	PickupRadius = {
		name = "Rayon Magnétique",
		icon = "rbxassetid://10709791054",
		iconFile = "CSFSimpleSkill3_C_256_68.png",
		color = STAT_COLORS.PickupRadius,
		tag = "AIM+",
		perLevelBonus = 4,
		format = function(v) return string.format("+%.0f Studs Rayon", v) end,
		desc = "Aspire les gemmes d'XP de plus loin.",
	},
	LifeSteal = {
		name = "Drain d'Énergie",
		icon = "rbxassetid://10709791480",
		iconFile = "CSFSimpleSkill3_C_256_32.png",
		color = STAT_COLORS.LifeSteal,
		tag = "VOL+",
		perLevelBonus = 0.02,
		format = function(v) return string.format("+%.1f%% Vol de Vie", v * 100) end,
		desc = "Convertit une partie des dégâts infligés en réparation de coque.",
	},
	BurnDamage = {
		name = "Surcharge Thermique",
		icon = "rbxassetid://10709791612",
		iconFile = "CSFSimpleSkill3_C_256_84.png",
		color = STAT_COLORS.BurnDamage,
		tag = "FEU+",
		perLevelBonus = 2.0,
		format = function(v) return string.format("+%.1f Dégâts Brûlure", v) end,
		desc = "Renforce les dégâts continus de feu par tic.",
	},
	RangeMultiplier = {
		name = "Portée des Radars",
		icon = "rbxassetid://10709791667",
		iconFile = "CSFSimpleSkill3_C_256_63.png",
		color = STAT_COLORS.RangeMultiplier,
		tag = "PRT+",
		perLevelBonus = 0.15,
		format = function(v) return string.format("+%.0f%% Portée", v * 100) end,
		desc = "Permet de verrouiller et toucher les ennemis à plus grande distance.",
	},
}
StatTypes.STAT_CONFIG = STAT_CONFIG

function StatTypes.CalculateDamageAfterArmor(rawDamage: number, armor: number): number
	if armor <= 0 then
		return rawDamage
	end
	-- Formule TheSwarm : 100 armure = 50% de réduction (Dégâts * 100 / (100 + armor))
	local reduction = 100 / (100 + armor)
	return math.max(1, rawDamage * reduction)
end

function StatTypes.CloneStats(stats: PlayerStats): PlayerStats
	return {
		MaxHP = stats.MaxHP,
		Speed = stats.Speed,
		DamageMultiplier = stats.DamageMultiplier,
		FireRateMultiplier = stats.FireRateMultiplier,
		Armor = stats.Armor,
		CriticalChance = stats.CriticalChance,
		PickupRadius = stats.PickupRadius,
		LifeSteal = stats.LifeSteal,
		BurnDamage = stats.BurnDamage,
		RangeMultiplier = stats.RangeMultiplier,
	}
end

return StatTypes
