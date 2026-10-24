--!strict
-- RewardService.luau: Generates 3 level-up cards (Weapons, Stats, Passives) and handles player selection

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatTypes = require(Shared:WaitForChild("StatTypes"))
local WeaponsData = require(Shared:WaitForChild("WeaponsData"))
local PassivesData = require(Shared:WaitForChild("PassivesData"))
local MetaProgressionData = require(Shared:WaitForChild("MetaProgressionData"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerStatsManager = require(script.Parent.PlayerStatsManager)
local WeaponService = require(script.Parent.WeaponService)
local PassiveService = require(script.Parent.PassiveService)
local MetaProgressionService = require(script.Parent.MetaProgressionService)

export type RewardCard = {
	id: string,
	category: "WEAPON" | "STAT" | "PASSIVE",
	title: string,
	subtitle: string,
	description: string,
	icon: string,
	iconFile: string?,
	tag: string?,
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
	local tTags: { [string]: string } = {
		OnEnemyKilled = "KILL",
		OnDamageDealt = "HIT",
		OnDamageTaken = "DEF",
		OnHeal = "HEAL",
		OnMove = "MOVE",
		OnStandStill = "STILL",
		OnCritHit = "CRIT",
		OnLevelUp = "LVL",
		OnOverdrive = "OVER",
		OnGainXP = "XP",
	}
	local eTags: { [string]: string } = {
		Heal = "REPAIR",
		GainMaxHP = "HP+",
		GainStatDamage = "DMG+",
		GainStatSpeed = "SPD+",
		GainStatFireRate = "CAD+",
		GainCritChance = "CRT+",
		GainStatArmor = "ARM+",
		GainLifeSteal = "DRAIN+",
		ChargeOverdrive = "OD+",
		GainXP = "XP+",
	}
	local tg = tTags[pDef.trigger] or "SYS"
	local eg = eTags[pDef.effect] or "PWR"
	return string.format("[%s -> %s]", tg, eg)
end

function RewardService.GenerateCards(player: Player): { RewardCard }
	local cards: { RewardCard } = {}
	local rng = Random.new()

	local meta = MetaProgressionService.GetPlayerMeta(player)
	local maxWeaponSlots = meta.weaponSlots
	local maxPassiveSlots = meta.passiveSlots
	local maxStatSlots = meta.statSlots
	local maxWeaponRank = meta.maxWeaponRank
	local maxStatRank = meta.maxStatRank

	local equippedWeapons = WeaponService.GetPlayerWeapons(player)
	local numRealWeapons = 0
	for wId in pairs(equippedWeapons) do
		if wId ~= "StarterGun" then
			numRealWeapons += 1
		end
	end

	-- 1. WEAPONS POOL
	local possibleWeaponCards: { RewardCard } = {}

	-- Upgrades first (capped by maxWeaponRank)
	for weaponId, rank in pairs(equippedWeapons) do
		local wDef = WeaponsData.GetWeapon(weaponId)
		if wDef and rank < maxWeaponRank and rank < #wDef.ranks then
			local nextRank = wDef.ranks[rank + 1]
			table.insert(possibleWeaponCards, {
				id = "WUpgrade_" .. weaponId,
				category = "WEAPON",
				title = wDef.name,
				subtitle = string.format("AMÉLIORATION : RANG %d ➔ %d", rank, rank + 1),
				description = string.format("Dégâts: %.0f | Projectiles: %d | Cadence: %.2fs", nextRank.damage, nextRank.projectileCount, nextRank.fireRate),
				icon = wDef.icon,
				iconFile = wDef.iconFile,
				tag = wDef.tag or "[ ARME ]",
				glyph = wDef.tag or "[ ARME ]",
				rarityColor = Color3.fromRGB(0, 200, 255),
				weaponId = weaponId,
			})
		end
	end

	-- New weapons (only if player has free weapon slots according to meta)
	if numRealWeapons < maxWeaponSlots then
		for _, wId in ipairs(WEAPON_IDS) do
			if wId ~= "StarterGun" and not equippedWeapons[wId] and MetaProgressionData.IsWeaponUnlocked(meta.totalXP, wId) then
				local wDef = WeaponsData.GetWeapon(wId)
				if wDef and #wDef.ranks > 0 then
					table.insert(possibleWeaponCards, {
						id = "WNew_" .. wId,
						category = "WEAPON",
						title = "NOUVELLE ARME : " .. wDef.name,
						subtitle = "AJOUTER À L'ARSENAL",
						description = wDef.description,
						icon = wDef.icon,
						iconFile = wDef.iconFile,
						tag = wDef.tag or "[ ARME ]",
						glyph = wDef.tag or "[ ARME ]",
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

	-- 2. STATS POOL (Faithful to RewardManager.cs lines 280-324)
	local ownedStatLevels = PlayerStatsManager.GetStatCardLevels(player)
	local ownedUniqueStats = 0
	for _ in pairs(ownedStatLevels) do ownedUniqueStats += 1 end

	local possibleStatCards: { RewardCard } = {}
	for _, sKey in ipairs(STAT_LIST) do
		local conf = StatTypes.STAT_CONFIG[sKey]
		if conf then
			local currentLevel = ownedStatLevels[sKey]
			if currentLevel ~= nil then
				-- Stat already owned: can upgrade if currentLevel < maxStatRank
				if currentLevel < maxStatRank then
					local bonus = conf.perLevelBonus
					table.insert(possibleStatCards, {
						id = "Stat_" .. sKey .. "_" .. (currentLevel + 1),
						category = "STAT",
						title = string.format("%s (NIV. %d)", conf.name, currentLevel + 1),
						subtitle = conf.format(bonus),
						description = conf.desc,
						icon = conf.icon,
						iconFile = conf.iconFile,
						tag = conf.tag or "[ MODULE ]",
						glyph = conf.tag or "[ MODULE ]",
						rarityColor = Color3.fromRGB(80, 255, 140),
						statType = sKey,
						statValue = bonus,
					})
				end
			elseif ownedUniqueStats < maxStatSlots and MetaProgressionData.IsStatUnlocked(meta.totalXP, sKey) then
				-- New stat: only if player has free stat slot according to meta
				local bonus = conf.perLevelBonus
				table.insert(possibleStatCards, {
					id = "Stat_" .. sKey .. "_1",
					category = "STAT",
					title = conf.name,
					subtitle = conf.format(bonus),
					description = conf.desc,
					icon = conf.icon,
					iconFile = conf.iconFile,
					tag = conf.tag or "[ MODULE ]",
					glyph = conf.tag or "[ MODULE ]",
					rarityColor = Color3.fromRGB(80, 255, 140),
					statType = sKey,
					statValue = bonus,
				})
			end
		end
	end

	if #possibleStatCards > 0 then
		local chosen = table.remove(possibleStatCards, rng:NextInteger(1, #possibleStatCards))
		table.insert(cards, chosen)
	end

	-- 3. PASSIVE POOL (Faithful to RewardManager.cs & PassiveManager.cs)
	local equippedPassives = PassiveService.GetPlayerPassives(player)
	local numPassives = #equippedPassives
	local canOfferPassive = numPassives < maxPassiveSlots

	local possiblePassiveCards: { RewardCard } = {}
	if canOfferPassive then
		for _, p in ipairs(PassivesData.PREMADE_PASSIVES) do
			if MetaProgressionData.IsPassiveUnlocked(meta.totalXP, p.id) then
				local alreadyOwned = false
				for _, eq in ipairs(equippedPassives) do
					if eq.id == p.id then
						alreadyOwned = true
						break
					end
				end
				if not alreadyOwned then
					table.insert(possiblePassiveCards, {
						id = "Passive_" .. p.id,
						category = "PASSIVE",
						title = p.name,
						subtitle = "MODULE PASSIF RÉACTIF",
						description = p.description,
						icon = p.icon,
						iconFile = p.iconFile,
						tag = "[ PASSIF ]",
						glyph = getPassiveGlyph(p),
						rarityColor = Color3.fromRGB(220, 80, 255),
						passiveDef = p,
					})
				end
			end
		end
	end

	if #possiblePassiveCards > 0 and rng:NextNumber() < 0.65 then
		local chosen = table.remove(possiblePassiveCards, rng:NextInteger(1, #possiblePassiveCards))
		table.insert(cards, chosen)
	elseif #possibleStatCards > 0 then
		local chosen = table.remove(possibleStatCards, rng:NextInteger(1, #possibleStatCards))
		table.insert(cards, chosen)
	elseif #possibleWeaponCards > 0 then
		local chosen = table.remove(possibleWeaponCards, rng:NextInteger(1, #possibleWeaponCards))
		table.insert(cards, chosen)
	end

	-- Guaranteed fallback if less than 3 choices
	while #cards < 3 do
		local fallbackStat = STAT_LIST[rng:NextInteger(1, #STAT_LIST)]
		local fbConf = StatTypes.STAT_CONFIG[fallbackStat]
		local fbBonus = fbConf.perLevelBonus
		table.insert(cards, {
			id = "FallbackStat_" .. fallbackStat .. "_" .. #cards,
			category = "STAT",
			title = fbConf.name,
			subtitle = fbConf.format(fbBonus),
			description = fbConf.desc,
			icon = fbConf.icon,
			iconFile = fbConf.iconFile,
			tag = fbConf.tag or "[ MODULE ]",
			glyph = fbConf.tag or "[ MODULE ]",
			rarityColor = Color3.fromRGB(80, 255, 140),
			statType = fallbackStat,
			statValue = fbBonus,
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
