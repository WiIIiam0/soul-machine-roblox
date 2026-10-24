--!strict
-- EnemiesData.luau: Bestiary of robotic swarm enemies, behaviors, tiers, and combat capabilities

export type AIBehavior = "CHASE" | "KITE_SHOOT" | "KAMIKAZE" | "BOSS" | "FLEE_LOOT" | "DASH_MELEE"

export type EnemyConfig = {
	id: string,
	name: string,
	tier: number,
	cost: number,               -- Cost in Director credits
	maxHealth: number,
	moveSpeed: number,
	contactDamage: number,
	xpValue: number,
	isBoss: boolean,
	isMetaEnemy: boolean,
	behavior: AIBehavior,

	-- Dash Parameters (matching EnemyAI.cs in TheSwarm)
	canDash: boolean,
	dashRange: number,
	dashPrepTime: number,
	dashLockTime: number,
	dashSpeed: number,
	dashDistance: number,
	dashCooldown: number,

	-- Shoot Parameters (matching EnemyAI.cs in TheSwarm)
	canShoot: boolean,
	shootRange: number,
	shootChargeTime: number,
	shootCooldown: number,
	bulletDamage: number,
	bulletSpeed: number,
	fleeRange: number,
	fleeSpeed: number,

	color: Color3,
	size: Vector3,
}

local EnemiesData = {}

local TYPES: { [string]: EnemyConfig } = {
	ScoutDrone = {
		id = "ScoutDrone",
		name = "Drone Éclaireur",
		tier = 1,
		cost = 25,
		maxHealth = 25,
		moveSpeed = 16,
		contactDamage = 8,
		xpValue = 1,
		isBoss = false,
		isMetaEnemy = false,
		behavior = "DASH_MELEE",

		canDash = true,
		dashRange = 16,
		dashPrepTime = 1.0,
		dashLockTime = 0.3,
		dashSpeed = 38,
		dashDistance = 24,
		dashCooldown = 2.8,

		canShoot = false,
		shootRange = 0,
		shootChargeTime = 0,
		shootCooldown = 0,
		bulletDamage = 0,
		bulletSpeed = 0,
		fleeRange = 0,
		fleeSpeed = 0,

		color = Color3.fromRGB(240, 60, 60),
		size = Vector3.new(4.5, 4.5, 4.5),
	},

	AssaultMecha = {
		id = "AssaultMecha",
		name = "Mécha d'Assaut",
		tier = 1,
		cost = 55,
		maxHealth = 55,
		moveSpeed = 13,
		contactDamage = 14,
		xpValue = 2,
		isBoss = false,
		isMetaEnemy = false,
		behavior = "DASH_MELEE",

		canDash = true,
		dashRange = 18,
		dashPrepTime = 1.2,
		dashLockTime = 0.35,
		dashSpeed = 30,
		dashDistance = 20,
		dashCooldown = 3.5,

		canShoot = false,
		shootRange = 0,
		shootChargeTime = 0,
		shootCooldown = 0,
		bulletDamage = 0,
		bulletSpeed = 0,
		fleeRange = 5,
		fleeSpeed = 8,

		color = Color3.fromRGB(200, 110, 40),
		size = Vector3.new(6.0, 8.0, 6.0),
	},

	SniperBot = {
		id = "SniperBot",
		name = "Tourelle Sniper Laser",
		tier = 2,
		cost = 80,
		maxHealth = 45,
		moveSpeed = 10,
		contactDamage = 6,
		xpValue = 3,
		isBoss = false,
		isMetaEnemy = false,
		behavior = "KITE_SHOOT",

		canDash = false,
		dashRange = 0,
		dashPrepTime = 0,
		dashLockTime = 0,
		dashSpeed = 0,
		dashDistance = 0,
		dashCooldown = 0,

		canShoot = true,
		shootRange = 55,
		shootChargeTime = 1.1,
		shootCooldown = 2.4,
		bulletDamage = 16,
		bulletSpeed = 75,
		fleeRange = 12,
		fleeSpeed = 11,

		color = Color3.fromRGB(180, 50, 220),
		size = Vector3.new(5.0, 7.5, 5.0),
	},

	HeavyJuggernaut = {
		id = "HeavyJuggernaut",
		name = "Colosse Juggernaut",
		tier = 2,
		cost = 150,
		maxHealth = 160,
		moveSpeed = 9,
		contactDamage = 28,
		xpValue = 6,
		isBoss = false,
		isMetaEnemy = false,
		behavior = "CHASE",

		canDash = false,
		dashRange = 0,
		dashPrepTime = 0,
		dashLockTime = 0,
		dashSpeed = 0,
		dashDistance = 0,
		dashCooldown = 0,

		canShoot = false,
		shootRange = 0,
		shootChargeTime = 0,
		shootCooldown = 0,
		bulletDamage = 0,
		bulletSpeed = 0,
		fleeRange = 0,
		fleeSpeed = 0,

		color = Color3.fromRGB(80, 80, 100),
		size = Vector3.new(8.5, 11.0, 8.5),
	},

	KamikazeRoller = {
		id = "KamikazeRoller",
		name = "Sphère Kamikaze",
		tier = 3,
		cost = 95,
		maxHealth = 38,
		moveSpeed = 22,
		contactDamage = 40,
		xpValue = 4,
		isBoss = false,
		isMetaEnemy = false,
		behavior = "KAMIKAZE",

		canDash = true,
		dashRange = 18,
		dashPrepTime = 0.55,
		dashLockTime = 0.15,
		dashSpeed = 46,
		dashDistance = 26,
		dashCooldown = 2.0,

		canShoot = false,
		shootRange = 0,
		shootChargeTime = 0,
		shootCooldown = 0,
		bulletDamage = 0,
		bulletSpeed = 0,
		fleeRange = 0,
		fleeSpeed = 0,

		color = Color3.fromRGB(255, 30, 30),
		size = Vector3.new(4.0, 4.0, 4.0),
	},

	OverlordBoss = {
		id = "OverlordBoss",
		name = "Goliath Suprême (Boss)",
		tier = 4,
		cost = 800,
		maxHealth = 1200,
		moveSpeed = 8,
		contactDamage = 35,
		xpValue = 50,
		isBoss = true,
		isMetaEnemy = false,
		behavior = "BOSS",

		canDash = true,
		dashRange = 32,
		dashPrepTime = 1.4,
		dashLockTime = 0.4,
		dashSpeed = 32,
		dashDistance = 35,
		dashCooldown = 7.5,

		canShoot = true,
		shootRange = 60,
		shootChargeTime = 0.8,
		shootCooldown = 1.8,
		bulletDamage = 20,
		bulletSpeed = 65,
		fleeRange = 0,
		fleeSpeed = 0,

		color = Color3.fromRGB(220, 20, 50),
		size = Vector3.new(14.0, 18.0, 14.0),
	},

	MetaDrone = {
		id = "MetaDrone",
		name = "Drone Porteur d'Orbe Doré",
		tier = 1,
		cost = 0,
		maxHealth = 100,
		moveSpeed = 16,
		contactDamage = 0,
		xpValue = 25,
		isBoss = false,
		isMetaEnemy = true,
		behavior = "FLEE_LOOT",

		canDash = false,
		dashRange = 0,
		dashPrepTime = 0,
		dashLockTime = 0,
		dashSpeed = 0,
		dashDistance = 0,
		dashCooldown = 0,

		canShoot = false,
		shootRange = 0,
		shootChargeTime = 0,
		shootCooldown = 0,
		bulletDamage = 0,
		bulletSpeed = 0,
		fleeRange = 0,
		fleeSpeed = 0,

		color = Color3.fromRGB(255, 215, 0),
		size = Vector3.new(3.5, 3.5, 3.5),
	},
}
EnemiesData.TYPES = TYPES

function EnemiesData.GetEnemy(id: string): EnemyConfig?
	return EnemiesData.TYPES[id]
end

return EnemiesData
