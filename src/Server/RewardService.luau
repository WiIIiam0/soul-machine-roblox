--!strict
-- RewardService.luau: Generates 3 level-up cards (Weapons, Stats, Passives) and handles player selection

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatTypes = require(Shared:WaitForChild("StatTypes"))
local WeaponsData = require(Shared:WaitForChild("WeaponsData"))
local PassivesData = require(Shared:WaitForChild("PassivesData"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerStatsManager = require(script.Parent.PlayerStatsManager)
local WeaponService = require(script.Parent.WeaponService)
local PassiveService = require(script.Parent.PassiveService)

export type RewardCard = {
	id: string,
	category: "WEAPON" | "STAT" | "PASSIVE",
	title: string,
	subtitle: string,
	description: string,
	icon: string,
	glyph: string?,
	rarityColor: Color3,
	weaponId: string?,
	statType: StatTypes.StatType?,
	statValue: number?,
	passiveDef: PassivesData.PassiveDefinition?,
}

local RewardService = {}
local pendingRewardsMap: { [Player]: { RewardCard } } = {}

local STAT_LIST: { StatTypes.StatType } = {
	"MaxHP", "Speed", "DamageMultiplier", "FireRateMultiplier", "Armor", "CriticalChance", "PickupRadius", "LifeSteal", "BurnDamage", "RangeMultiplier",
}

local WEAPON_IDS = {
	"Rifle", "Pompe", "Eventail", "Rocket", "DarkStorm", "FireMissile", "MissileMultiShot", "Taser",
}

local function getPassiveGlyph(pDef: PassivesData.PassiveDefinition): string
	local tGlyphs: { [string]: string } = {
		OnEnemyKilled = "💀",
		OnDamageDealt = "⚔️",
		OnDamageTaken = "🛡️",
		OnHeal = "💚",
		OnMove = "👟",
		OnStandStill = "🧘",
		OnCritHit = "🎯",
		OnLevelUp = "⭐",
		OnOverdrive = "⚡",
		OnGainXP = "💎",
	}
	local eGlyphs: { [string]: string } = {
		Heal = "💚",
		GainMaxHP = "❤️",
		GainStatDamage = "💥",
		GainStatSpeed = "👟",
		GainStatFireRate = "⚡",
		GainCritChance = "🎯",
		GainStatArmor = "🛡️",
		GainLifeSteal = "🩸",
		ChargeOverdrive = "⚡",
		GainXP = "💎",
	}
	local tg = tGlyphs[pDef.trigger] or "⚡"
	local eg = eGlyphs[pDef.effect] or "✨"
	return tg .. "➔" .. eg
end

function RewardService.GenerateCards(player: Player): { RewardCard }
	local cards: { RewardCard } = {}
	local rng = Random.new()

	local equippedWeapons = WeaponService.GetPlayerWeapons(player)

	-- 1. Try to generate at least 1 weapon card (either upgrade an existing or offer new)
	local possibleWeaponCards: { RewardCard } = {}

	-- Upgrades first
	for weaponId, rank in pairs(equippedWeapons) do
		local wDef = WeaponsData.GetWeapon(weaponId)
		if wDef and rank < #wDef.ranks then
			local nextRank = wDef.ranks[rank + 1]
			table.insert(possibleWeaponCards, {
				id = "WUpgrade_" .. weaponId,
				category = "WEAPON",
				title = wDef.name,
				subtitle = string.format("AMÉLIORATION : RANG %d ➔ %d", rank, rank + 1),
				description = string.format("Dégâts: %.0f | Projectiles: %d | Cadence: %.2fs", nextRank.damage, nextRank.projectileCount, nextRank.fireRate),
				icon = wDef.icon,
				glyph = wDef.glyph or "🔫",
				rarityColor = Color3.fromRGB(0, 200, 255),
				weaponId = weaponId,
			})
		end
	end

	-- New weapons (if player has less than 6 weapons)
	local numWeapons = 0
	for _ in pairs(equippedWeapons) do numWeapons += 1 end

	if numWeapons < 6 then
		for _, wId in ipairs(WEAPON_IDS) do
			if not equippedWeapons[wId] then
				local wDef = WeaponsData.GetWeapon(wId)
				if wDef and #wDef.ranks > 0 then
					local rank1 = wDef.ranks[1]
					table.insert(possibleWeaponCards, {
						id = "WNew_" .. wId,
						category = "WEAPON",
						title = "NOUVELLE ARME : " .. wDef.name,
						subtitle = "AJOUTER À L'ARSENAL",
						description = wDef.description,
						icon = wDef.icon,
						glyph = wDef.glyph or "🔫",
						rarityColor = Color3.fromRGB(255, 200, 40),
						weaponId = wId,
					})
				end
			end
		end
	end

	if #possibleWeaponCards > 0 then
		local chosen = table.remove(possibleWeaponCards, rng:NextInteger(1, #possibleWeaponCards))
		table.insert(cards, chosen)
	end

	-- 2. Stat Upgrade Card
	local statType = STAT_LIST[rng:NextInteger(1, #STAT_LIST)]
	local conf = StatTypes.STAT_CONFIG[statType]
	local bonus = conf.perLevelBonus

	table.insert(cards, {
		id = "Stat_" .. statType,
		category = "STAT",
		title = conf.name,
		subtitle = conf.format(bonus),
		description = conf.desc,
		icon = conf.icon,
		glyph = conf.glyph or "📈",
		rarityColor = Color3.fromRGB(80, 255, 140),
		statType = statType,
		statValue = bonus,
	})

	-- 3. Passive or Extra Card
	if rng:NextNumber() < 0.65 then
		-- Procedural or premade passive
		local passDef: PassivesData.PassiveDefinition
		if #PassivesData.PREMADE_PASSIVES > 0 and rng:NextNumber() < 0.5 then
			passDef = PassivesData.PREMADE_PASSIVES[rng:NextInteger(1, #PassivesData.PREMADE_PASSIVES)]
		else
			passDef = PassivesData.GenerateProceduralPassive(math.random(1, 999999))
		end

		table.insert(cards, {
			id = "Passive_" .. passDef.id,
			category = "PASSIVE",
			title = passDef.name,
			subtitle = "MODULE PASSIF RÉACTIF",
			description = passDef.description,
			icon = passDef.icon,
			glyph = getPassiveGlyph(passDef),
			rarityColor = Color3.fromRGB(220, 80, 255),
			passiveDef = passDef,
		})
	else
		-- Second Stat or Weapon Card
		local secondStat = STAT_LIST[rng:NextInteger(1, #STAT_LIST)]
		local sConf = StatTypes.STAT_CONFIG[secondStat]
		local sBonus = sConf.perLevelBonus

		table.insert(cards, {
			id = "Stat2_" .. secondStat,
			category = "STAT",
			title = sConf.name,
			subtitle = sConf.format(sBonus),
			description = sConf.desc,
			icon = sConf.icon,
			glyph = sConf.glyph or "📈",
			rarityColor = Color3.fromRGB(80, 255, 140),
			statType = secondStat,
			statValue = sBonus,
		})
	end

	return cards
end

function RewardService.OfferLevelUpRewards(player: Player)
	local cards = RewardService.GenerateCards(player)
	pendingRewardsMap[player] = cards

	-- Phase Shift / Invulnerability and untargetability during Level Up
	PlayerStatsManager.SetLevelUpPhase(player, true)

	Remotes.GetEvent("LevelUpOptions"):FireClient(player, cards)

	-- Safety auto-select timeout (16 seconds)
	task.delay(16, function()
		local pending = pendingRewardsMap[player]
		if pending and pending[1] then
			local chosenCard = pending[1]
			pendingRewardsMap[player] = nil
			PlayerStatsManager.SetLevelUpPhase(player, false)

			if chosenCard.category == "WEAPON" and chosenCard.weaponId then
				WeaponService.AddOrUpgradeWeapon(player, chosenCard.weaponId)
			elseif chosenCard.category == "STAT" and chosenCard.statType and chosenCard.statValue then
				PlayerStatsManager.AddStat(player, chosenCard.statType, chosenCard.statValue)
			elseif chosenCard.category == "PASSIVE" and chosenCard.passiveDef then
				PassiveService.AddPassive(player, chosenCard.passiveDef)
			end
		end
	end)
end

-- Handle choice response
local selectRemote = Remotes.GetEvent("SelectLevelUpChoice")
selectRemote.OnServerEvent:Connect(function(player: Player, choiceIndex: number)
	local pending = pendingRewardsMap[player]
	if not pending or not pending[choiceIndex] then
		PlayerStatsManager.SetLevelUpPhase(player, false)
		return
	end

	local chosenCard = pending[choiceIndex]
	pendingRewardsMap[player] = nil

	-- Remove invulnerability & restore normal visibility/aggro
	PlayerStatsManager.SetLevelUpPhase(player, false)

	if chosenCard.category == "WEAPON" and chosenCard.weaponId then
		WeaponService.AddOrUpgradeWeapon(player, chosenCard.weaponId)
	elseif chosenCard.category == "STAT" and chosenCard.statType and chosenCard.statValue then
		PlayerStatsManager.AddStat(player, chosenCard.statType, chosenCard.statValue)
	elseif chosenCard.category == "PASSIVE" and chosenCard.passiveDef then
		PassiveService.AddPassive(player, chosenCard.passiveDef)
	end
end)

function RewardService.Cleanup(player: Player)
	pendingRewardsMap[player] = nil
	PlayerStatsManager.SetLevelUpPhase(player, false)
end

Players.PlayerRemoving:Connect(RewardService.Cleanup)

return RewardService
