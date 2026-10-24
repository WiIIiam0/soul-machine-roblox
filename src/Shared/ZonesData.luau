--!strict
-- ZonesData.luau: Configuration des zones multi-serveurs (Sub-Places Roblox), paliers de niveau, et difficulté fixe par zone

export type ZoneConfig = {
	zoneId: number,
	name: string,
	subtitle: string,
	placeId: number,
	minLevel: number,
	nextZoneId: number?,
	nextZoneRequiredLevel: number?,
	themeColor: Color3,
	floorTint: Color3,
	enemyHpMult: number,
	enemyDamageMult: number,
	enemyXpMult: number,
	baseCreditsPerWave: number,
	baseSpawnRatePerPlayer: number,
	eligibleEnemies: { string },
	bossId: string,
	bossEscortId: string,
}

local ZonesData = {}

-- Renseigner ici les PlaceIds Roblox des 4 Places de l'Univers une fois publiées.
-- Tant qu'un PlaceId vaut 0 (ou en test Roblox Studio), ZoneService bascule automatiquement en simulation locale.
local PLACE_IDS: { [number]: number } = {
	[1] = 0, -- Zone 1 : Place principale d'entrée (Niveau 1+)
	[2] = 0, -- Zone 2 : Sous-Place Secteur Beta (Niveau 5+)
	[3] = 0, -- Zone 3 : Sous-Place Secteur Gamma (Niveau 10+)
	[4] = 0, -- Zone 4 : Sous-Place Secteur Oméga (Niveau 15+)
}
ZonesData.PLACE_IDS = PLACE_IDS

ZonesData.BOSS_WAVE_INTERVAL = 10 -- Un boss toutes les 10 vagues, sans montée de niveau par vague

local ZONES: { [number]: ZoneConfig } = {
	[1] = {
		zoneId = 1,
		name = "ZONE 1 : SECTEUR ALPHA",
		subtitle = "Périphérie d'Atterrissage",
		placeId = PLACE_IDS[1],
		minLevel = 1,
		nextZoneId = 2,
		nextZoneRequiredLevel = 5,
		themeColor = Color3.fromRGB(0, 195, 255),
		floorTint = Color3.fromRGB(50, 48, 55),
		enemyHpMult = 1.0,
		enemyDamageMult = 1.0,
		enemyXpMult = 1.0,
		baseCreditsPerWave = 45,
		baseSpawnRatePerPlayer = 14.0,
		eligibleEnemies = { "ScoutDrone", "AssaultMecha" },
		bossId = "OverlordBoss",
		bossEscortId = "AssaultMecha",
	},

	[2] = {
		zoneId = 2,
		name = "ZONE 2 : SECTEUR BETA",
		subtitle = "Complexe d'Assemblage",
		placeId = PLACE_IDS[2],
		minLevel = 5,
		nextZoneId = 3,
		nextZoneRequiredLevel = 10,
		themeColor = Color3.fromRGB(255, 165, 30),
		floorTint = Color3.fromRGB(58, 48, 42),
		enemyHpMult = 2.4,
		enemyDamageMult = 1.6,
		enemyXpMult = 2.2,
		baseCreditsPerWave = 75,
		baseSpawnRatePerPlayer = 22.0,
		eligibleEnemies = { "ScoutDrone", "AssaultMecha", "SniperBot" },
		bossId = "OverlordBoss",
		bossEscortId = "SniperBot",
	},

	[3] = {
		zoneId = 3,
		name = "ZONE 3 : SECTEUR GAMMA",
		subtitle = "Fonderie Cybernétique",
		placeId = PLACE_IDS[3],
		minLevel = 10,
		nextZoneId = 4,
		nextZoneRequiredLevel = 15,
		themeColor = Color3.fromRGB(190, 55, 255),
		floorTint = Color3.fromRGB(48, 40, 62),
		enemyHpMult = 5.5,
		enemyDamageMult = 2.4,
		enemyXpMult = 4.5,
		baseCreditsPerWave = 110,
		baseSpawnRatePerPlayer = 32.0,
		eligibleEnemies = { "AssaultMecha", "SniperBot", "HeavyJuggernaut", "KamikazeRoller" },
		bossId = "OverlordBoss",
		bossEscortId = "HeavyJuggernaut",
	},

	[4] = {
		zoneId = 4,
		name = "ZONE 4 : SECTEUR OMÉGA",
		subtitle = "Cœur Suprême de l'Essaim",
		placeId = PLACE_IDS[4],
		minLevel = 15,
		nextZoneId = nil,
		nextZoneRequiredLevel = nil,
		themeColor = Color3.fromRGB(255, 35, 65),
		floorTint = Color3.fromRGB(60, 36, 42),
		enemyHpMult = 12.0,
		enemyDamageMult = 3.5,
		enemyXpMult = 9.0,
		baseCreditsPerWave = 160,
		baseSpawnRatePerPlayer = 45.0,
		eligibleEnemies = { "AssaultMecha", "SniperBot", "HeavyJuggernaut", "KamikazeRoller" },
		bossId = "OverlordBoss",
		bossEscortId = "HeavyJuggernaut",
	},
}
ZonesData.ZONES = ZONES

function ZonesData.GetZone(zoneId: number): ZoneConfig
	return ZONES[zoneId] or ZONES[1]
end

function ZonesData.GetPlaceId(zoneId: number): number
	return PLACE_IDS[zoneId] or 0
end

function ZonesData.ResolveZoneIdFromPlaceId(placeId: number): number?
	if placeId <= 0 then
		return nil
	end
	for zId, configuredPlaceId in pairs(PLACE_IDS) do
		if configuredPlaceId > 0 and configuredPlaceId == placeId then
			return zId
		end
	end
	return nil
end

return ZonesData
