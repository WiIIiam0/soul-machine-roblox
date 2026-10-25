--!strict
-- WeaponsData.luau: The 10 Soul Machine weapons with exact Unity ShotData parameters and instant/physical flags

export type ShotBehavior = "TARGETED" | "CONE" | "RADIAL" | "HOMING" | "FOCUSED" | "TRUE_SHOTGUN"

export type WeaponRank = {
	isInstant: boolean,
	fireRate: number,
	damage: number,
	range: number,
	speed: number,           -- Used for physical projectiles (FireMissile / MissileMultiShot)
	projectileCount: number, -- Or ray count
	pierceCount: number,
	spreadAngle: number,     -- In degrees for CONE / TRUE_SHOTGUN
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
	uiStatColor: string?,
	tag: string,
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
		description = "Canon mecha automatique tirant des faisceaux laser instantanés à haute cadence.",
		icon = "",
		iconFile = "CSFSimpleSkill3_C_256_08.png",
		uiStatColor = "None",
		tag = "INIT",
		behavior = "FOCUSED",
		scalingStat = "DamageMultiplier",
		scalingRatio = 0.01,
		ranks = {
			{ isInstant = true, fireRate = 0.45, damage = 20, range = 50, speed = 110, projectileCount = 1, pierceCount = 0, spreadAngle = 0, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(0, 220, 255), bulletSize = Vector3.new(0.6, 0.6, 1.4) },
			{ isInstant = true, fireRate = 0.40, damage = 26, range = 55, speed = 115, projectileCount = 1, pierceCount = 1, spreadAngle = 0, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(50, 230, 255), bulletSize = Vector3.new(0.7, 0.7, 1.6) },
			{ isInstant = true, fireRate = 0.35, damage = 34, range = 60, speed = 120, projectileCount = 2, pierceCount = 1, spreadAngle = 10, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(100, 240, 255), bulletSize = Vector3.new(0.8, 0.8, 1.8) },
			{ isInstant = true, fireRate = 0.30, damage = 44, range = 65, speed = 130, projectileCount = 2, pierceCount = 2, spreadAngle = 10, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(150, 250, 255), bulletSize = Vector3.new(0.9, 0.9, 2.0) },
			{ isInstant = true, fireRate = 0.25, damage = 56, range = 70, speed = 140, projectileCount = 3, pierceCount = 2, spreadAngle = 12, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(200, 255, 255), bulletSize = Vector3.new(1.0, 1.0, 2.2) },
		},
	},

	Rifle = {
		id = "Rifle",
		name = "Fusil Gauss Lourd",
		description = "Rayon Gauss instantané hyper-perforant transperçant les cohortes d'ennemis.",
		icon = "",
		iconFile = "CSFSimpleSkill3_C_256_36.png",
		uiStatColor = "FireRateMultiplier",
		tag = "GAUS",
		behavior = "FOCUSED",
		scalingStat = "FireRateMultiplier",
		scalingRatio = 0.02,
		ranks = {
			{ isInstant = true, fireRate = 0.22, damage = 16, range = 80, speed = 160, projectileCount = 1, pierceCount = 1, spreadAngle = 4, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 230, 80), bulletSize = Vector3.new(0.4, 0.4, 2.2) },
			{ isInstant = true, fireRate = 0.18, damage = 22, range = 88, speed = 170, projectileCount = 1, pierceCount = 2, spreadAngle = 3, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 240, 100), bulletSize = Vector3.new(0.5, 0.5, 2.5) },
			{ isInstant = true, fireRate = 0.15, damage = 30, range = 96, speed = 180, projectileCount = 2, pierceCount = 2, spreadAngle = 6, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 245, 120), bulletSize = Vector3.new(0.5, 0.5, 2.8) },
			{ isInstant = true, fireRate = 0.12, damage = 40, range = 104, speed = 190, projectileCount = 2, pierceCount = 3, spreadAngle = 5, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 250, 140), bulletSize = Vector3.new(0.6, 0.6, 3.0) },
			{ isInstant = true, fireRate = 0.09, damage = 52, range = 115, speed = 200, projectileCount = 3, pierceCount = 4, spreadAngle = 6, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 255, 180), bulletSize = Vector3.new(0.7, 0.7, 3.2) },
		},
	},

	Pompe = {
		id = "Pompe",
		name = "Canon Dispersion (Pompe)",
		description = "Décharge instantanée d'un cône massif de faisceaux thermiques percutants.",
		icon = "",
		iconFile = "CSFSimpleSkill3_C_256_35.png",
		uiStatColor = "Speed",
		tag = "POMP",
		behavior = "TRUE_SHOTGUN",
		scalingStat = "Speed",
		scalingRatio = 0.02,
		ranks = {
			{ isInstant = true, fireRate = 1.00, damage = 18, range = 55, speed = 90, projectileCount = 5, pierceCount = 0, spreadAngle = 20, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 130, 30), bulletSize = Vector3.new(0.5, 0.5, 0.8) },
			{ isInstant = true, fireRate = 0.90, damage = 24, range = 58, speed = 95, projectileCount = 6, pierceCount = 1, spreadAngle = 22, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 140, 40), bulletSize = Vector3.new(0.6, 0.6, 0.9) },
			{ isInstant = true, fireRate = 0.80, damage = 32, range = 62, speed = 100, projectileCount = 7, pierceCount = 1, spreadAngle = 24, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 150, 50), bulletSize = Vector3.new(0.7, 0.7, 1.0) },
			{ isInstant = true, fireRate = 0.70, damage = 42, range = 66, speed = 105, projectileCount = 8, pierceCount = 2, spreadAngle = 26, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 160, 60), bulletSize = Vector3.new(0.7, 0.7, 1.1) },
			{ isInstant = true, fireRate = 0.60, damage = 55, range = 70, speed = 110, projectileCount = 10, pierceCount = 3, spreadAngle = 28, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 180, 80), bulletSize = Vector3.new(0.8, 0.8, 1.2) },
		},
	},

	Eventail = {
		id = "Eventail",
		name = "Lames Plasma Éventail",
		description = "Libère un large arc instantané de rayons plasma perforant des vagues entières.",
		icon = "",
		iconFile = "CSFSimpleSkill3_C_256_41.png",
		uiStatColor = "MaxHP",
		tag = "EVNT",
		behavior = "CONE",
		scalingStat = "MaxHP",
		scalingRatio = 0.02,
		ranks = {
			{ isInstant = true, fireRate = 0.75, damage = 24, range = 75, speed = 75, projectileCount = 5, pierceCount = 2, spreadAngle = 45, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(0, 255, 160), bulletSize = Vector3.new(2.4, 0.4, 0.8) },
			{ isInstant = true, fireRate = 0.70, damage = 32, range = 80, speed = 80, projectileCount = 6, pierceCount = 3, spreadAngle = 50, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(20, 255, 180), bulletSize = Vector3.new(2.8, 0.4, 0.9) },
			{ isInstant = true, fireRate = 0.65, damage = 42, range = 85, speed = 85, projectileCount = 7, pierceCount = 4, spreadAngle = 55, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(40, 255, 200), bulletSize = Vector3.new(3.2, 0.4, 1.0) },
			{ isInstant = true, fireRate = 0.60, damage = 54, range = 90, speed = 90, projectileCount = 8, pierceCount = 5, spreadAngle = 60, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(60, 255, 220), bulletSize = Vector3.new(3.6, 0.5, 1.1) },
			{ isInstant = true, fireRate = 0.50, damage = 70, range = 95, speed = 95, projectileCount = 9, pierceCount = 6, spreadAngle = 65, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(80, 255, 240), bulletSize = Vector3.new(4.0, 0.5, 1.2) },
		},
	},

	Rocket = {
		id = "Rocket",
		name = "Lance-Missiles Titan",
		description = "Frappe instantanée cinétique lourde déclenchant une onde de choc et des éclats radiaux.",
		icon = "",
		iconFile = "CSFSimpleSkill3_C_256_77.png",
		uiStatColor = "DamageMultiplier",
		tag = "ROKT",
		behavior = "TARGETED",
		scalingStat = "DamageMultiplier",
		scalingRatio = 0.02,
		ranks = {
			{ isInstant = true, fireRate = 1.30, damage = 80, range = 75, speed = 70, projectileCount = 1, pierceCount = 0, spreadAngle = 0, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 14, color = Color3.fromRGB(255, 70, 20), bulletSize = Vector3.new(1.0, 1.0, 2.5) },
			{ isInstant = true, fireRate = 1.15, damage = 115, range = 80, speed = 75, projectileCount = 1, pierceCount = 0, spreadAngle = 0, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 16, color = Color3.fromRGB(255, 80, 20), bulletSize = Vector3.new(1.1, 1.1, 2.7) },
			{ isInstant = true, fireRate = 1.00, damage = 160, range = 85, speed = 80, projectileCount = 1, pierceCount = 0, spreadAngle = 0, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 18, color = Color3.fromRGB(255, 90, 20), bulletSize = Vector3.new(1.2, 1.2, 3.0) },
			{ isInstant = true, fireRate = 0.85, damage = 220, range = 90, speed = 85, projectileCount = 2, pierceCount = 0, spreadAngle = 15, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 20, color = Color3.fromRGB(255, 100, 20), bulletSize = Vector3.new(1.3, 1.3, 3.2) },
			{ isInstant = true, fireRate = 0.70, damage = 300, range = 95, speed = 90, projectileCount = 2, pierceCount = 0, spreadAngle = 18, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 24, color = Color3.fromRGB(255, 120, 20), bulletSize = Vector3.new(1.5, 1.5, 3.5) },
		},
	},

	DarkStorm = {
		id = "DarkStorm",
		name = "Tempête Noire (DarkStorm)",
		description = "Émet simultanément des rayons tachyoniques instantanés pulvérisant les cibles autour du mecha.",
		icon = "",
		iconFile = "CSFSimpleSkill3_C_256_08.png",
		uiStatColor = "LifeSteal",
		tag = "DARK",
		behavior = "TARGETED",
		scalingStat = "LifeSteal",
		scalingRatio = 0.02,
		ranks = {
			{ isInstant = true, fireRate = 1.20, damage = 28, range = 50, speed = 60, projectileCount = 4, pierceCount = 1, spreadAngle = 360, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(180, 50, 255), bulletSize = Vector3.new(1.0, 1.0, 1.0) },
			{ isInstant = true, fireRate = 1.05, damage = 38, range = 55, speed = 65, projectileCount = 6, pierceCount = 1, spreadAngle = 360, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(200, 60, 255), bulletSize = Vector3.new(1.1, 1.1, 1.1) },
			{ isInstant = true, fireRate = 0.90, damage = 50, range = 60, speed = 70, projectileCount = 8, pierceCount = 2, spreadAngle = 360, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(220, 70, 255), bulletSize = Vector3.new(1.2, 1.2, 1.2) },
			{ isInstant = true, fireRate = 0.75, damage = 65, range = 65, speed = 75, projectileCount = 10, pierceCount = 2, spreadAngle = 360, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(240, 80, 255), bulletSize = Vector3.new(1.3, 1.3, 1.3) },
			{ isInstant = true, fireRate = 0.60, damage = 85, range = 70, speed = 80, projectileCount = 12, pierceCount = 3, spreadAngle = 360, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 100, 255), bulletSize = Vector3.new(1.4, 1.4, 1.4) },
		},
	},

	FireMissile = {
		id = "FireMissile",
		name = "Missile Incendiaire Pyros",
		description = "Roquette autoguidée physique appliquant de violents dégâts continus de brûlure thermique.",
		icon = "",
		iconFile = "CSFSimpleSkill3_C_256_77.png",
		uiStatColor = "None",
		tag = "PYRO",
		behavior = "HOMING",
		scalingStat = "BurnDamage",
		scalingRatio = 0.02,
		ranks = {
			{ isInstant = false, fireRate = 0.90, damage = 18, range = 80, speed = 85, projectileCount = 1, pierceCount = 0, spreadAngle = 0, isHoming = true, homingTurnSpeed = 10, inflictsBurn = true, burnStacks = 4, explosionRadius = 8, color = Color3.fromRGB(255, 90, 0), bulletSize = Vector3.new(0.8, 0.8, 1.8) },
			{ isInstant = false, fireRate = 0.80, damage = 26, range = 85, speed = 90, projectileCount = 1, pierceCount = 0, spreadAngle = 0, isHoming = true, homingTurnSpeed = 12, inflictsBurn = true, burnStacks = 6, explosionRadius = 9, color = Color3.fromRGB(255, 105, 0), bulletSize = Vector3.new(0.9, 0.9, 2.0) },
			{ isInstant = false, fireRate = 0.70, damage = 36, range = 90, speed = 95, projectileCount = 2, pierceCount = 0, spreadAngle = 20, isHoming = true, homingTurnSpeed = 13, inflictsBurn = true, burnStacks = 8, explosionRadius = 10, color = Color3.fromRGB(255, 120, 0), bulletSize = Vector3.new(1.0, 1.0, 2.2) },
			{ isInstant = false, fireRate = 0.60, damage = 48, range = 95, speed = 100, projectileCount = 2, pierceCount = 0, spreadAngle = 20, isHoming = true, homingTurnSpeed = 15, inflictsBurn = true, burnStacks = 10, explosionRadius = 11, color = Color3.fromRGB(255, 135, 0), bulletSize = Vector3.new(1.1, 1.1, 2.4) },
			{ isInstant = false, fireRate = 0.50, damage = 64, range = 100, speed = 105, projectileCount = 3, pierceCount = 0, spreadAngle = 25, isHoming = true, homingTurnSpeed = 16, inflictsBurn = true, burnStacks = 14, explosionRadius = 13, color = Color3.fromRGB(255, 150, 0), bulletSize = Vector3.new(1.2, 1.2, 2.6) },
		},
	},

	MissileMultiShot = {
		id = "MissileMultiShot",
		name = "Batterie Micro-Essaim",
		description = "Pluie physique de micro-missiles autoguidés cherchant chacun une cible différente.",
		icon = "",
		iconFile = "CSFSimpleSkill3_C_256_08.png",
		uiStatColor = "None",
		tag = "SWM",
		behavior = "HOMING",
		scalingStat = "DamageMultiplier",
		scalingRatio = 0.02,
		ranks = {
			{ isInstant = false, fireRate = 1.10, damage = 14, range = 75, speed = 80, projectileCount = 4, pierceCount = 0, spreadAngle = 50, isHoming = true, homingTurnSpeed = 12, inflictsBurn = false, burnStacks = 0, explosionRadius = 5, color = Color3.fromRGB(255, 200, 40), bulletSize = Vector3.new(0.5, 0.5, 1.2) },
			{ isInstant = false, fireRate = 0.95, damage = 19, range = 80, speed = 85, projectileCount = 5, pierceCount = 0, spreadAngle = 55, isHoming = true, homingTurnSpeed = 13, inflictsBurn = false, burnStacks = 0, explosionRadius = 5, color = Color3.fromRGB(255, 210, 50), bulletSize = Vector3.new(0.5, 0.5, 1.3) },
			{ isInstant = false, fireRate = 0.85, damage = 25, range = 85, speed = 90, projectileCount = 6, pierceCount = 0, spreadAngle = 60, isHoming = true, homingTurnSpeed = 14, inflictsBurn = false, burnStacks = 0, explosionRadius = 6, color = Color3.fromRGB(255, 220, 60), bulletSize = Vector3.new(0.6, 0.6, 1.4) },
			{ isInstant = false, fireRate = 0.75, damage = 33, range = 90, speed = 95, projectileCount = 7, pierceCount = 0, spreadAngle = 65, isHoming = true, homingTurnSpeed = 15, inflictsBurn = false, burnStacks = 0, explosionRadius = 6, color = Color3.fromRGB(255, 230, 70), bulletSize = Vector3.new(0.6, 0.6, 1.5) },
			{ isInstant = false, fireRate = 0.65, damage = 44, range = 95, speed = 100, projectileCount = 9, pierceCount = 0, spreadAngle = 70, isHoming = true, homingTurnSpeed = 16, inflictsBurn = false, burnStacks = 0, explosionRadius = 7, color = Color3.fromRGB(255, 240, 80), bulletSize = Vector3.new(0.7, 0.7, 1.6) },
		},
	},

	Taser = {
		id = "Taser",
		name = "Déchargeur Tesla",
		description = "Arcs électriques instantanés haute tension foudroyant de multiples cibles à ultra haute cadence.",
		icon = "",
		iconFile = "CSFSimpleSkill3_C_256_08.png",
		uiStatColor = "CriticalChance",
		tag = "TSLA",
		behavior = "FOCUSED",
		scalingStat = "CriticalChance",
		scalingRatio = 0.02,
		ranks = {
			{ isInstant = true, fireRate = 0.35, damage = 18, range = 50, speed = 250, projectileCount = 2, pierceCount = 1, spreadAngle = 10, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(80, 190, 255), bulletSize = Vector3.new(0.5, 0.5, 3.0) },
			{ isInstant = true, fireRate = 0.30, damage = 25, range = 54, speed = 260, projectileCount = 2, pierceCount = 2, spreadAngle = 12, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(100, 210, 255), bulletSize = Vector3.new(0.6, 0.6, 3.2) },
			{ isInstant = true, fireRate = 0.25, damage = 34, range = 58, speed = 270, projectileCount = 3, pierceCount = 2, spreadAngle = 14, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(120, 230, 255), bulletSize = Vector3.new(0.6, 0.6, 3.5) },
			{ isInstant = true, fireRate = 0.20, damage = 45, range = 62, speed = 280, projectileCount = 3, pierceCount = 3, spreadAngle = 16, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(140, 245, 255), bulletSize = Vector3.new(0.7, 0.7, 3.8) },
			{ isInstant = true, fireRate = 0.15, damage = 60, range = 66, speed = 300, projectileCount = 4, pierceCount = 3, spreadAngle = 18, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(180, 255, 255), bulletSize = Vector3.new(0.8, 0.8, 4.0) },
		},
	},

	OverdriveWeapon = {
		id = "OverdriveWeapon",
		name = "Surcharge Nucléaire (Overdrive)",
		description = "Déluge instantané de 20 faisceaux laser en cercle 360° pulvérisant la pièce.",
		icon = "",
		iconFile = "CSFSimpleSkill3_C_256_41.png",
		uiStatColor = "Speed",
		tag = "OVER",
		behavior = "RADIAL",
		scalingStat = "Speed",
		scalingRatio = 0.02,
		ranks = {
			{ isInstant = true, fireRate = 0.10, damage = 35, range = 90, speed = 140, projectileCount = 20, pierceCount = 2, spreadAngle = 360, isHoming = false, homingTurnSpeed = 0, inflictsBurn = false, burnStacks = 0, explosionRadius = 0, color = Color3.fromRGB(255, 50, 90), bulletSize = Vector3.new(1.0, 1.0, 1.8) },
		},
	},
}
WeaponsData.WEAPONS = WEAPONS

function WeaponsData.GetWeapon(id: string): WeaponDefinition?
	return WeaponsData.WEAPONS[id]
end

return WeaponsData
