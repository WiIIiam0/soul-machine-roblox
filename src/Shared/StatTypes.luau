--!strict
-- StatTypes.luau: Statistics definitions, scaling values, and calculation helpers

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

StatTypes.DEFAULT_STATS: PlayerStats = {
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

StatTypes.STAT_CONFIG: { [StatType]: { name: string, icon: string, perLevelBonus: number, format: (val: number) -> string, desc: string } } = {
	MaxHP = {
		name = "Points de Vie Max",
		icon = "rbxassetid://10709791437",
		perLevelBonus = 20,
		format = function(v) return string.format("+%.0f PV", v) end,
		desc = "Augmente les points de vie maximaux de ton Mécha.",
	},
	Speed = {
		name = "Propulsion / Vitesse",
		icon = "rbxassetid://10709791130",
		perLevelBonus = 2.0,
		format = function(v) return string.format("+%.1f Vitesse", v) end,
		desc = "Permet d'esquiver plus facilement les essaims.",
	},
	DamageMultiplier = {
		name = "Puissance de Feu",
		icon = "rbxassetid://10709791557",
		perLevelBonus = 0.12,
		format = function(v) return string.format("+%.0f%% Dégâts", v * 100) end,
		desc = "Multiplie les dégâts infligés par toutes les armes.",
	},
	FireRateMultiplier = {
		name = "Cadence de Tir",
		icon = "rbxassetid://10709791334",
		perLevelBonus = 0.08,
		format = function(v) return string.format("+%.0f%% Cadence", v * 100) end,
		desc = "Réduit le temps de recharge entre chaque rafale.",
	},
	Armor = {
		name = "Blindage / Armure",
		icon = "rbxassetid://10709791281",
		perLevelBonus = 12,
		format = function(v) return string.format("+%.0f Armure", v) end,
		desc = "100 d'armure réduit les dégâts subis de 50%.",
	},
	CriticalChance = {
		name = "Chances de Critique",
		icon = "rbxassetid://10709791223",
		perLevelBonus = 4,
		format = function(v) return string.format("+%.0f%% Critique", v) end,
		desc = "Chances d'infliger le double de dégâts (x2).",
	},
	PickupRadius = {
		name = "Rayon Magnétique",
		icon = "rbxassetid://10709791054",
		perLevelBonus = 4,
		format = function(v) return string.format("+%.0f Studs Rayon", v) end,
		desc = "Aspire les gemmes d'XP de plus loin.",
	},
	LifeSteal = {
		name = "Drain d'Énergie",
		icon = "rbxassetid://10709791480",
		perLevelBonus = 0.02,
		format = function(v) return string.format("+%.1f%% Vol de Vie", v * 100) end,
		desc = "Convertit une partie des dégâts infligés en réparation de coque.",
	},
	BurnDamage = {
		name = "Surcharge Thermique",
		icon = "rbxassetid://10709791612",
		perLevelBonus = 2.0,
		format = function(v) return string.format("+%.1f Dégâts Brûlure", v) end,
		desc = "Renforce les dégâts continus de feu par tic.",
	},
	RangeMultiplier = {
		name = "Portée des Radars",
		icon = "rbxassetid://10709791667",
		perLevelBonus = 0.15,
		format = function(v) return string.format("+%.0f%% Portée", v * 100) end,
		desc = "Permet de verrouiller et toucher les ennemis à plus grande distance.",
	},
}

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
