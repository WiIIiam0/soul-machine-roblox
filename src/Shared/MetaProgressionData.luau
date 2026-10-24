--!strict
-- MetaProgressionData.luau: Global account leveling, slot unlocks, weapon & passive unlock tables

export type LevelUnlock = {
	level: number,
	xpRequired: number,
	weaponSlots: number,
	passiveSlots: number,
	newWeapons: { string },
	newPassives: { string },
	title: string,
	description: string,
}

local MetaProgressionData = {}

-- Progressive global progression tiers
local LEVEL_UNLOCKS: { [number]: LevelUnlock } = {
	[1] = {
		level = 1,
		xpRequired = 80,
		weaponSlots = 4,
		passiveSlots = 4,
		newWeapons = { "StarterGun", "Rifle", "Pompe", "Eventail" },
		newPassives = { "VampiricProtocol", "KineticCapacitor", "EmergencyReactor", "ArmoredReinforcement" },
		title = "Recrue Mécha",
		description = "ArsenaI initial : 4 emplacements d'armes et 4 passifs débloqués.",
	},
	[2] = {
		level = 2,
		xpRequired = 180,
		weaponSlots = 4,
		passiveSlots = 5,
		newWeapons = { "Rocket" },
		newPassives = { "ScavengerNanites" },
		title = "Opérateur Tactique",
		description = "+1 Emplacement Passif (5 au total). Débloque le Lance-Missiles Titan et les Nanites Récupérateurs.",
	},
	[3] = {
		level = 3,
		xpRequired = 320,
		weaponSlots = 5,
		passiveSlots = 5,
		newWeapons = { "FireMissile" },
		newPassives = { "HyperchargeCrit" },
		title = "Vanguard Lourd",
		description = "+1 Emplacement d'Arme (5 au total). Débloque le Missile Incendiaire Pyros et la Surcharge Critique.",
	},
	[4] = {
		level = 4,
		xpRequired = 500,
		weaponSlots = 5,
		passiveSlots = 6,
		newWeapons = { "DarkStorm" },
		newPassives = { "SiegeModule" },
		title = "Commandant d'Assaut",
		description = "+1 Emplacement Passif MAX (6 au total). Débloque la Tempête Noire (DarkStorm) et le Module de Siège.",
	},
	[5] = {
		level = 5,
		xpRequired = 750,
		weaponSlots = 6,
		passiveSlots = 6,
		newWeapons = { "MissileMultiShot" },
		newPassives = { "OverdriveSurge" },
		title = "Maître de Guerre",
		description = "+1 Emplacement d'Arme MAX (6 au total). Débloque la Batterie Micro-Essaim et la Décharge Overdrive.",
	},
	[6] = {
		level = 6,
		xpRequired = 1100,
		weaponSlots = 6,
		passiveSlots = 6,
		newWeapons = { "Taser" },
		newPassives = {},
		title = "Titan Cybernétique",
		description = "Débloque le Déchargeur Tesla haute fréquence.",
	},
}
MetaProgressionData.LEVEL_UNLOCKS = LEVEL_UNLOCKS

function MetaProgressionData.GetXPForLevel(level: number): number
	local unlock = LEVEL_UNLOCKS[level]
	if unlock then
		return unlock.xpRequired
	end
	-- Infinite scaling beyond defined levels: +35% per level
	return math.floor(1100 * (1.35 ^ (level - 6)))
end

function MetaProgressionData.GetWeaponSlots(level: number): number
	if level >= 5 then
		return 6
	elseif level >= 3 then
		return 5
	else
		return 4
	end
end

function MetaProgressionData.GetPassiveSlots(level: number): number
	if level >= 4 then
		return 6
	elseif level >= 2 then
		return 5
	else
		return 4
	end
end

function MetaProgressionData.GetUnlockInfoForLevel(level: number): LevelUnlock?
	return LEVEL_UNLOCKS[level]
end

function MetaProgressionData.IsWeaponUnlocked(level: number, weaponId: string): boolean
	for lvl = 1, level do
		local conf = LEVEL_UNLOCKS[lvl]
		if conf then
			for _, wId in ipairs(conf.newWeapons) do
				if wId == weaponId then
					return true
				end
			end
		end
	end
	return false
end

function MetaProgressionData.IsPassiveUnlocked(level: number, passiveId: string): boolean
	for lvl = 1, level do
		local conf = LEVEL_UNLOCKS[lvl]
		if conf then
			for _, pId in ipairs(conf.newPassives) do
				if pId == passiveId then
					return true
				end
			end
		end
	end
	return false
end

function MetaProgressionData.GetAllUnlockedWeapons(level: number): { [string]: boolean }
	local unlocked: { [string]: boolean } = {}
	for lvl = 1, level do
		local conf = LEVEL_UNLOCKS[lvl]
		if conf then
			for _, wId in ipairs(conf.newWeapons) do
				unlocked[wId] = true
			end
		end
	end
	return unlocked
end

function MetaProgressionData.GetAllUnlockedPassives(level: number): { [string]: boolean }
	local unlocked: { [string]: boolean } = {}
	for lvl = 1, level do
		local conf = LEVEL_UNLOCKS[lvl]
		if conf then
			for _, pId in ipairs(conf.newPassives) do
				unlocked[pId] = true
			end
		end
	end
	return unlocked
end

return MetaProgressionData
