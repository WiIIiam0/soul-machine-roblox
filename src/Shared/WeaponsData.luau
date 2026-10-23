--!strict
-- WeaponsData.luau: The 10 Soul Machine weapons and their progressive upgrade ranks

export type ShotBehavior = "TARGETED" | "CONE" | "RADIAL" | "HOMING" | "FOCUSED"

export type WeaponRank = {
	fireRate: number,
	damage: number,
	range: number,
	speed: number,
	projectileCount: number,
	pierceCount: number,
	spreadAngle: number,     -- In degrees for CONE
	isHoming: boolean,
	homingTurnSpeed: number,
	inflictsBurn: boolean,
	burnStacks: number,
	explosionRadius: number, -- 0 if no AOE
	color: Color3,
	bulletSize: Vector3,
}

export type WeaponDefinition = {
	id: string,
	name: string,
	description: string,
	icon: string,
	iconFile: string,
	tag: string,
	glyph: string,
	behavior: ShotBehavior,
	scalingStat: string,      -- Bonus scaling with stat
	scalingRatio: number,     -- Percentage bonus per point
	ranks: { WeaponRank },
}

local WeaponsData = {}

local WEAPONS: { [string]: WeaponDefinition } = {
	StarterGun = {
		id = "StarterGun",
		name = "Canon Impulsion",
		description = "Canon mecha automatique tirant des salves d'énergie cinétique.",
		icon = "rbxassetid://10709791557",
		iconFile = "CSFSimpleSkill3_C_256_08.png",
		tag = "[ CANON-IMP ]",
		glyph = "⚡",
		behavior = "TARGETED",
		scalingStat = "DamageMultiplier",
		scalingRatio = 0.01,
		ranks = {
			{ fireRate = 0.65, damage = 18, range = 50, speed = 110, projectileCount = 1, pierceCount = 0, spreadAngle = 0, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(0, 200, 255), bulletSize = Vector3.new(0.6, 0.6, 1.4) },
			{ fireRate = 0.55, damage = 24, range = 55, speed = 115, projectileCount = 1, pierceCount = 1, spreadAngle = 0, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(0, 220, 255), bulletSize = Vector3.new(0.7, 0.7, 1.6) },
			{ fireRate = 0.45, damage = 32, range = 60, speed = 120, projectileCount = 2, pierceCount = 1, spreadAngle = 10, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(0, 240, 255), bulletSize = Vector3.new(0.8, 0.8, 1.8) },
			{ fireRate = 0.38, damage = 42, range = 65, speed = 130, projectileCount = 2, pierceCount = 2, spreadAngle = 10, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(50, 255, 255), bulletSize = Vector3.new(0.9, 0.9, 2.0) },
			{ fireRate = 0.30, damage = 55, range = 70, speed = 140, projectileCount = 3, pierceCount = 2, spreadAngle = 12, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(120, 255, 255), bulletSize = Vector3.new(1.0, 1.0, 2.2) },
		},
	},

	Rifle = {
		id = "Rifle",
		name = "Fusil Gauss Lourd",
		description = "Mitrailleuse cinétique à haute vélocité perçant les lignes ennemies.",
		icon = "rbxassetid://10709791334",
		iconFile = "CSFSimpleSkill3_C_256_36.png",
		tag = "[ GAUSS-MK1 ]",
		glyph = "🎯",
		behavior = "TARGETED",
		scalingStat = "DamageMultiplier",
		scalingRatio = 0.02,
		ranks = {
			{ fireRate = 0.22, damage = 14, range = 75, speed = 160, projectileCount = 1, pierceCount = 1, spreadAngle = 4, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 230, 80), bulletSize = Vector3.new(0.4, 0.4, 2.2) },
			{ fireRate = 0.18, damage = 19, range = 80, speed = 170, projectileCount = 1, pierceCount = 2, spreadAngle = 3, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 240, 100), bulletSize = Vector3.new(0.5, 0.5, 2.5) },
			{ fireRate = 0.15, damage = 26, range = 85, speed = 180, projectileCount = 2, pierceCount = 2, spreadAngle = 6, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 245, 120), bulletSize = Vector3.new(0.5, 0.5, 2.8) },
			{ fireRate = 0.12, damage = 35, range = 90, speed = 190, projectileCount = 2, pierceCount = 3, spreadAngle = 5, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 250, 140), bulletSize = Vector3.new(0.6, 0.6, 3.0) },
			{ fireRate = 0.09, damage = 46, range = 100, speed = 200, projectileCount = 3, pierceCount = 4, spreadAngle = 6, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 255, 180), bulletSize = Vector3.new(0.7, 0.7, 3.2) },
		},
	},

	Pompe = {
		id = "Pompe",
		name = "Canon Dispersion (Pompe)",
		description = "Projette un cône dense de plombs thermiques dévastateur à courte portée.",
		icon = "rbxassetid://10709791480",
		iconFile = "CSFSimpleSkill3_C_256_35.png",
		tag = "[ POMPE-THERM ]",
		glyph = "💥",
		behavior = "CONE",
		scalingStat = "DamageMultiplier",
		scalingRatio = 0.015,
		ranks = {
			{ fireRate = 1.10, damage = 16, range = 35, speed = 90, projectileCount = 5, pierceCount = 0, spreadAngle = 35, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 120, 20), bulletSize = Vector3.new(0.5, 0.5, 0.8) },
			{ fireRate = 0.95, damage = 22, range = 38, speed = 95, projectileCount = 6, pierceCount = 1, spreadAngle = 38, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 130, 30), bulletSize = Vector3.new(0.6, 0.6, 0.9) },
			{ fireRate = 0.80, damage = 29, range = 42, speed = 100, projectileCount = 7, pierceCount = 1, spreadAngle = 40, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 140, 40), bulletSize = Vector3.new(0.7, 0.7, 1.0) },
			{ fireRate = 0.70, damage = 38, range = 45, speed = 105, projectileCount = 8, pierceCount = 2, spreadAngle = 42, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 150, 50), bulletSize = Vector3.new(0.7, 0.7, 1.1) },
			{ fireRate = 0.55, damage = 50, range = 50, speed = 110, projectileCount = 10, pierceCount = 3, spreadAngle = 45, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 160, 60), bulletSize = Vector3.new(0.8, 0.8, 1.2) },
		},
	},

	Eventail = {
		id = "Eventail",
		name = "Lames Plasma Éventail",
		description = "Libère un large arc de lames de plasma perforant des lignes entières de drones.",
		icon = "rbxassetid://10709791667",
		iconFile = "CSFSimpleSkill3_C_256_41.png",
		tag = "[ LAMES-PLAS ]",
		glyph = "✨",
		behavior = "CONE",
		scalingStat = "DamageMultiplier",
		scalingRatio = 0.02,
		ranks = {
			{ fireRate = 1.30, damage = 35, range = 48, speed = 75, projectileCount = 3, pierceCount = 3, spreadAngle = 50, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(0, 255, 160), bulletSize = Vector3.new(2.4, 0.4, 0.8) },
			{ fireRate = 1.15, damage = 48, range = 52, speed = 80, projectileCount = 4, pierceCount = 4, spreadAngle = 55, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(20, 255, 180), bulletSize = Vector3.new(2.8, 0.4, 0.9) },
			{ fireRate = 1.00, damage = 64, range = 56, speed = 85, projectileCount = 5, pierceCount = 5, spreadAngle = 60, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(40, 255, 200), bulletSize = Vector3.new(3.2, 0.4, 1.0) },
			{ fireRate = 0.85, damage = 85, range = 60, speed = 90, projectileCount = 6, pierceCount = 6, spreadAngle = 65, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(60, 255, 220), bulletSize = Vector3.new(3.6, 0.5, 1.1) },
			{ fireRate = 0.70, damage = 115, range = 65, speed = 95, projectileCount = 8, pierceCount = 8, spreadAngle = 70, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(80, 255, 240), bulletSize = Vector3.new(4.0, 0.5, 1.2) },
		},
	},

	Rocket = {
		id = "Rocket",
		name = "Lance-Missiles Titan",
		description = "Tire une roquette lourde provoquant une violente onde de choc explosive.",
		icon = "rbxassetid://10709791612",
		iconFile = "CSFSimpleSkill3_C_256_77.png",
		tag = "[ ROQUETTE ]",
		glyph = "🚀",
		behavior = "TARGETED",
		scalingStat = "DamageMultiplier",
		scalingRatio = 0.03,
		ranks = {
			{ fireRate = 1.80, damage = 70, range = 70, speed = 70, projectileCount = 1, pierceCount = 0, spreadAngle = 0, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 12, color = Color3.fromRGB(255, 60, 20), bulletSize = Vector3.new(1.0, 1.0, 2.5) },
			{ fireRate = 1.60, damage = 100, range = 75, speed = 75, projectileCount = 1, pierceCount = 0, spreadAngle = 0, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 14, color = Color3.fromRGB(255, 70, 20), bulletSize = Vector3.new(1.1, 1.1, 2.7) },
			{ fireRate = 1.40, damage = 140, range = 80, speed = 80, projectileCount = 2, pierceCount = 0, spreadAngle = 15, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 16, color = Color3.fromRGB(255, 80, 20), bulletSize = Vector3.new(1.2, 1.2, 3.0) },
			{ fireRate = 1.20, damage = 190, range = 85, speed = 85, projectileCount = 2, pierceCount = 0, spreadAngle = 15, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 18, color = Color3.fromRGB(255, 90, 20), bulletSize = Vector3.new(1.3, 1.3, 3.2) },
			{ fireRate = 1.00, damage = 260, range = 90, speed = 90, projectileCount = 3, pierceCount = 0, spreadAngle = 18, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 22, color = Color3.fromRGB(255, 100, 20), bulletSize = Vector3.new(1.5, 1.5, 3.5) },
		},
	},

	DarkStorm = {
		id = "DarkStorm",
		name = "Tempête Noire (DarkStorm)",
		description = "Génère un anneau protecteur à 360° d'orbes tachyoniques pulvérisant tout ce qui s'approche.",
		icon = "rbxassetid://10709791223",
		iconFile = "CSFSimpleSkill3_C_256_08.png",
		tag = "[ DARKSTORM ]",
		glyph = "🌪️",
		behavior = "RADIAL",
		scalingStat = "DamageMultiplier",
		scalingRatio = 0.02,
		ranks = {
			{ fireRate = 2.00, damage = 22, range = 40, speed = 60, projectileCount = 8, pierceCount = 1, spreadAngle = 360, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(160, 40, 255), bulletSize = Vector3.new(1.0, 1.0, 1.0) },
			{ fireRate = 1.75, damage = 30, range = 45, speed = 65, projectileCount = 10, pierceCount = 1, spreadAngle = 360, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(180, 50, 255), bulletSize = Vector3.new(1.1, 1.1, 1.1) },
			{ fireRate = 1.50, damage = 40, range = 50, speed = 70, projectileCount = 12, pierceCount = 2, spreadAngle = 360, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(200, 60, 255), bulletSize = Vector3.new(1.2, 1.2, 1.2) },
			{ fireRate = 1.30, damage = 52, range = 55, speed = 75, projectileCount = 14, pierceCount = 2, spreadAngle = 360, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(220, 70, 255), bulletSize = Vector3.new(1.3, 1.3, 1.3) },
			{ fireRate = 1.10, damage = 70, range = 60, speed = 80, projectileCount = 16, pierceCount = 3, spreadAngle = 360, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(240, 80, 255), bulletSize = Vector3.new(1.4, 1.4, 1.4) },
		},
	},

	FireMissile = {
		id = "FireMissile",
		name = "Missile Incendiaire Pyros",
		description = "Roquette traqueuse appliquant de violents dégâts continus de brûlure thermique.",
		icon = "rbxassetid://10709791437",
		iconFile = "CSFSimpleSkill3_C_256_77.png",
		tag = "[ PYROS-FEU ]",
		glyph = "🔥",
		behavior = "HOMING",
		scalingStat = "BurnDamage",
		scalingRatio = 0.05,
		ranks = {
			{ fireRate = 1.40, damage = 25, range = 80, speed = 80, projectileCount = 1, pierceCount = 0, spreadAngle = 0, isHoming = true, homingTurnSpeed = 8, inflictsBurn = true, burnStacks = 4, explosionRadius = 6, color = Color3.fromRGB(255, 90, 0), bulletSize = Vector3.new(0.8, 0.8, 1.8) },
			{ fireRate = 1.20, damage = 35, range = 85, speed = 85, projectileCount = 1, pierceCount = 0, spreadAngle = 0, isHoming = true, homingTurnSpeed = 10, inflictsBurn = true, burnStacks = 6, explosionRadius = 7, color = Color3.fromRGB(255, 100, 0), bulletSize = Vector3.new(0.9, 0.9, 2.0) },
			{ fireRate = 1.00, damage = 48, range = 90, speed = 90, projectileCount = 2, pierceCount = 0, spreadAngle = 20, isHoming = true, homingTurnSpeed = 11, inflictsBurn = true, burnStacks = 8, explosionRadius = 8, color = Color3.fromRGB(255, 110, 0), bulletSize = Vector3.new(1.0, 1.0, 2.2) },
			{ fireRate = 0.85, damage = 65, range = 95, speed = 95, projectileCount = 2, pierceCount = 0, spreadAngle = 20, isHoming = true, homingTurnSpeed = 12, inflictsBurn = true, burnStacks = 10, explosionRadius = 9, color = Color3.fromRGB(255, 120, 0), bulletSize = Vector3.new(1.1, 1.1, 2.4) },
			{ fireRate = 0.70, damage = 90, range = 100, speed = 100, projectileCount = 3, pierceCount = 0, spreadAngle = 25, isHoming = true, homingTurnSpeed = 14, inflictsBurn = true, burnStacks = 14, explosionRadius = 11, color = Color3.fromRGB(255, 140, 0), bulletSize = Vector3.new(1.2, 1.2, 2.6) },
		},
	},

	MissileMultiShot = {
		id = "MissileMultiShot",
		name = "Batterie Micro-Essaim",
		description = "Projette une pluie de micro-missiles autoguidés cherchant chacun une cible différente.",
		icon = "rbxassetid://10709791054",
		iconFile = "CSFSimpleSkill3_C_256_08.png",
		tag = "[ ESSAIM-MK2 ]",
		glyph = "🎆",
		behavior = "HOMING",
		scalingStat = "DamageMultiplier",
		scalingRatio = 0.015,
		ranks = {
			{ fireRate = 1.60, damage = 18, range = 70, speed = 75, projectileCount = 4, pierceCount = 0, spreadAngle = 60, isHoming = true, homingTurnSpeed = 12, inflictsBurn = false, burnStacks = 0, explosionRadius = 4, color = Color3.fromRGB(255, 200, 40), bulletSize = Vector3.new(0.5, 0.5, 1.2) },
			{ fireRate = 1.40, damage = 24, range = 75, speed = 80, projectileCount = 5, pierceCount = 0, spreadAngle = 65, isHoming = true, homingTurnSpeed = 13, inflictsBurn = false, burnStacks = 0, explosionRadius = 5, color = Color3.fromRGB(255, 210, 50), bulletSize = Vector3.new(0.5, 0.5, 1.3) },
			{ fireRate = 1.20, damage = 32, range = 80, speed = 85, projectileCount = 6, pierceCount = 0, spreadAngle = 70, isHoming = true, homingTurnSpeed = 14, inflictsBurn = false, burnStacks = 0, explosionRadius = 5, color = Color3.fromRGB(255, 220, 60), bulletSize = Vector3.new(0.6, 0.6, 1.4) },
			{ fireRate = 1.00, damage = 42, range = 85, speed = 90, projectileCount = 7, pierceCount = 0, spreadAngle = 75, isHoming = true, homingTurnSpeed = 15, inflictsBurn = false, burnStacks = 0, explosionRadius = 6, color = Color3.fromRGB(255, 230, 70), bulletSize = Vector3.new(0.6, 0.6, 1.5) },
			{ fireRate = 0.80, damage = 56, range = 90, speed = 95, projectileCount = 9, pierceCount = 0, spreadAngle = 80, isHoming = true, homingTurnSpeed = 16, inflictsBurn = false, burnStacks = 0, explosionRadius = 7, color = Color3.fromRGB(255, 240, 80), bulletSize = Vector3.new(0.7, 0.7, 1.6) },
		},
	},

	Taser = {
		id = "Taser",
		name = "Déchargeur Tesla",
		description = "Arcs électriques haute tension frappant instantanément à très haute cadence.",
		icon = "rbxassetid://10709791281",
		iconFile = "CSFSimpleSkill3_C_256_08.png",
		tag = "[ TESLA-ELEC ]",
		glyph = "⚡",
		behavior = "TARGETED",
		scalingStat = "DamageMultiplier",
		scalingRatio = 0.015,
		ranks = {
			{ fireRate = 0.35, damage = 16, range = 45, speed = 250, projectileCount = 1, pierceCount = 2, spreadAngle = 0, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(80, 180, 255), bulletSize = Vector3.new(0.5, 0.5, 3.0) },
			{ fireRate = 0.30, damage = 22, range = 48, speed = 260, projectileCount = 2, pierceCount = 2, spreadAngle = 12, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(100, 200, 255), bulletSize = Vector3.new(0.6, 0.6, 3.2) },
			{ fireRate = 0.25, damage = 30, range = 52, speed = 270, projectileCount = 2, pierceCount = 3, spreadAngle = 15, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(120, 220, 255), bulletSize = Vector3.new(0.6, 0.6, 3.5) },
			{ fireRate = 0.20, damage = 40, range = 56, speed = 280, projectileCount = 3, pierceCount = 3, spreadAngle = 18, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(140, 240, 255), bulletSize = Vector3.new(0.7, 0.7, 3.8) },
			{ fireRate = 0.15, damage = 55, range = 60, speed = 300, projectileCount = 4, pierceCount = 4, spreadAngle = 20, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(180, 255, 255), bulletSize = Vector3.new(0.8, 0.8, 4.0) },
		},
	},

	OverdriveWeapon = {
		id = "OverdriveWeapon",
		name = "Surcharge Nucléaire (Overdrive)",
		description = "Barrage ultime à cadence frénétique pulvérisant la totalité des cibles en 360°.",
		icon = "rbxassetid://10709791130",
		iconFile = "CSFSimpleSkill3_C_256_41.png",
		tag = "[ OVERDRIVE ]",
		glyph = "⚡",
		behavior = "RADIAL",
		scalingStat = "DamageMultiplier",
		scalingRatio = 0.05,
		ranks = {
			{ fireRate = 0.08, damage = 45, range = 80, speed = 140, projectileCount = 12, pierceCount = 3, spreadAngle = 360, isHoming = false, homingTurnSpeed = 0, inflictsBurn = true, burnStacks = 3, explosionRadius = 8, color = Color3.fromRGB(255, 50, 80), bulletSize = Vector3.new(1.0, 1.0, 1.8) },
		},
	},
}
WeaponsData.WEAPONS = WEAPONS

function WeaponsData.GetWeapon(id: string): WeaponDefinition?
	return WeaponsData.WEAPONS[id]
end

return WeaponsData
