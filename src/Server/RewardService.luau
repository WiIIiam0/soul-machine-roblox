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
	iconColor: Color3?,
	isComposite: boolean?,
	triggerIconFile: string?,
	effectIconFile: string?,
	triggerColor: Color3?,
	effectColor: Color3?,
	triggerTag: string?,
	effectTag: string?,
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
local queuedLevelUpsMap: { [Player]: number } = {}
local offerGenerationMap: { [Player]: number } = {}

local STAT_LIST: { StatTypes.StatType } = {
	"MaxHP", "Speed", "DamageMultiplier", "FireRateMultiplier", "Armor", "CriticalChance", "PickupRadius", "LifeSteal", "BurnDamage", "RangeMultiplier",
}

local WEAPON_IDS = {
	"Rifle", "Pompe", "Eventail", "Rocket", "DarkStorm", "FireMissile", "MissileMultiShot", "Taser",
}

local TRIGGER_SHORT_TAGS: { [string]: string } = {
	OnEnemyKilled = "KILL",
	OnDamageDealt = "HIT",
	OnDamageTaken = "TANK",
	OnHeal = "SOIN",
	OnMove = "MOVE",
	OnStandStill = "FIXE",
	OnCritHit = "CRIT",
	OnLevelUp = "NIV",
	OnOverdrive = "OVER",
	OnGainXP = "XP",
	OnWaveStart = "VAG",
	OnWeaponFire = "TIR",
}

local EFFECT_SHORT_TAGS: { [string]: string } = {
	Heal = "SOIN",
	GainMaxHP = "PV+",
	GainStatDamage = "DMG+",
	GainStatSpeed = "VIT+",
	GainStatFireRate = "CAD+",
	GainCritChance = "CRT+",
	GainStatArmor = "ARM+",
	GainLifeSteal = "VOL+",
	ChargeOverdrive = "OD+",
	GainXP = "XP+",
}

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
			local statColor = StatTypes.GetStatColor(wDef.uiStatColor)
			table.insert(possibleWeaponCards, {
				id = "WUpgrade_" .. weaponId,
				category = "WEAPON",
				title = wDef.name,
				subtitle = string.format("AMÉLIORATION : RANG %d ➔ %d", rank, rank + 1),
				description = string.format("Dégâts: %.0f | Projectiles: %d | Cadence: %.2fs", nextRank.damage, nextRank.projectileCount, nextRank.fireRate),
				icon = wDef.icon,
				iconFile = wDef.iconFile,
				iconColor = statColor or Color3.new(1, 1, 1),
				tag = wDef.tag or "[ ARME ]",
				glyph = wDef.tag or "[ ARME ]",
				rarityColor = statColor or Color3.fromRGB(0, 200, 255),
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
					local statColor = StatTypes.GetStatColor(wDef.uiStatColor)
					table.insert(possibleWeaponCards, {
						id = "WNew_" .. wId,
						category = "WEAPON",
						title = "NOUVELLE ARME : " .. wDef.name,
						subtitle = "AJOUTER À L'ARSENAL",
						description = wDef.description,
						icon = wDef.icon,
						iconFile = wDef.iconFile,
						iconColor = statColor or Color3.new(1, 1, 1),
						tag = wDef.tag or "[ ARME ]",
						glyph = wDef.tag or "[ ARME ]",
						rarityColor = statColor or Color3.fromRGB(255, 200, 40),
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
						iconColor = conf.color,
						tag = conf.tag or "[ MODULE ]",
						glyph = conf.tag or "[ MODULE ]",
						rarityColor = conf.color or Color3.fromRGB(80, 255, 140),
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
					iconColor = conf.color,
					tag = conf.tag or "[ MODULE ]",
					glyph = conf.tag or "[ MODULE ]",
					rarityColor = conf.color or Color3.fromRGB(80, 255, 140),
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

	-- 3. PASSIVE POOL (Combinatorial System: Trigger x Effect matching Unity RewardManager.cs lines 220-275)
	local equippedPassives = PassiveService.GetPlayerPassives(player)
	local numPassives = #equippedPassives
	local canOfferPassive = numPassives < maxPassiveSlots

	local possiblePassiveCards: { RewardCard } = {}
	if canOfferPassive then
		local availableTriggers: { PassivesData.TriggerCondition } = { "OnEnemyKilled", "OnDamageDealt", "OnMove", "OnWeaponFire", "OnDamageTaken" }
		if meta.totalXP >= 28 then table.insert(availableTriggers, "OnCritHit") end
		if meta.totalXP >= 72 then table.insert(availableTriggers, "OnWaveStart") end
		if meta.totalXP >= 217 then table.insert(availableTriggers, "OnOverdrive") end
		if meta.totalXP >= 522 then table.insert(availableTriggers, "OnLevelUp") end

		local availableEffects: { PassivesData.PassiveEffect } = { "Heal", "GainStatDamage", "ChargeOverdrive", "GainMaxHP", "GainStatSpeed" }
		if meta.totalXP >= 13 then table.insert(availableEffects, "GainStatArmor") end
		if meta.totalXP >= 85 then table.insert(availableEffects, "GainCritChance") end
		if meta.totalXP >= 187 then table.insert(availableEffects, "GainLifeSteal") end

		for _, t in ipairs(availableTriggers) do
			for _, e in ipairs(availableEffects) do
				local alreadyOwned = false
				for _, eq in ipairs(equippedPassives) do
					if eq.trigger == t and eq.effect == e then
						alreadyOwned = true
						break
					end
				end

				if not alreadyOwned then
					local dynamicDef = PassivesData.CreateDynamicPassive(t, e)
					local trigColor = StatTypes.GetStatColor(dynamicDef.triggerScalingStat) or Color3.new(1, 1, 1)
					local effColor = StatTypes.GetStatColor(dynamicDef.effectScalingStat) or Color3.new(1, 1, 1)
					table.insert(possiblePassiveCards, {
						id = dynamicDef.id,
						category = "PASSIVE",
						title = dynamicDef.name,
						subtitle = "PASSIF SYSTÉMIQUE",
						description = dynamicDef.description,
						icon = dynamicDef.icon,
						iconFile = dynamicDef.iconFile,
						isComposite = true,
						triggerIconFile = dynamicDef.triggerIconFile,
						effectIconFile = dynamicDef.effectIconFile,
						triggerColor = trigColor,
						effectColor = effColor,
						triggerTag = TRIGGER_SHORT_TAGS[t] or "TRG",
						effectTag = EFFECT_SHORT_TAGS[e] or "EFF",
						tag = "[ PASSIF ]",
						glyph = string.format("[%s ➔ %s]", t, e),
						rarityColor = Color3.fromRGB(200, 100, 255),
						passiveDef = dynamicDef,
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
			iconColor = fbConf.color,
			tag = fbConf.tag or "[ MODULE ]",
			glyph = fbConf.tag or "[ MODULE ]",
			rarityColor = fbConf.color or Color3.fromRGB(80, 255, 140),
			statType = fallbackStat,
			statValue = fbBonus,
		})
	end

	return cards
end

local function applyChosenCard(player: Player, chosenCard: RewardCard)
	if chosenCard.category == "WEAPON" and chosenCard.weaponId then
		WeaponService.AddOrUpgradeWeapon(player, chosenCard.weaponId)
	elseif chosenCard.category == "STAT" and chosenCard.statType and chosenCard.statValue then
		PlayerStatsManager.AddStat(player, chosenCard.statType, chosenCard.statValue)
	elseif chosenCard.category == "PASSIVE" and chosenCard.passiveDef then
		PassiveService.AddPassive(player, chosenCard.passiveDef)
	end
end

local function presentNextRewardModal(player: Player)
	if not player.Parent then return end
	local cards = RewardService.GenerateCards(player)
	pendingRewardsMap[player] = cards

	local gen = (offerGenerationMap[player] or 0) + 1
	offerGenerationMap[player] = gen

	-- Phase Shift / Invulnerability and untargetability during Level Up
	PlayerStatsManager.SetLevelUpPhase(player, true)

	Remotes.GetEvent("LevelUpOptions"):FireClient(player, cards)

	-- Safety auto-select timeout (16 seconds), bound strictly to this generation ID
	task.delay(16, function()
		if offerGenerationMap[player] ~= gen then return end
		local pending = pendingRewardsMap[player]
		if pending and pending[1] then
			local chosenCard = pending[1]
			pendingRewardsMap[player] = nil
			applyChosenCard(player, chosenCard)

			local queued = queuedLevelUpsMap[player] or 0
			if queued > 0 then
				queuedLevelUpsMap[player] = queued - 1
				presentNextRewardModal(player)
			else
				PlayerStatsManager.SetLevelUpPhase(player, false)
			end
		end
	end)
end

function RewardService.OfferLevelUpRewards(player: Player)
	if pendingRewardsMap[player] ~= nil then
		queuedLevelUpsMap[player] = (queuedLevelUpsMap[player] or 0) + 1
		return
	end
	presentNextRewardModal(player)
end

function RewardService.ExportUnclaimedCount(player: Player): number
	local count = queuedLevelUpsMap[player] or 0
	if pendingRewardsMap[player] ~= nil then
		count += 1
	end
	return count
end

function RewardService.ImportUnclaimedCount(player: Player, count: number)
	pendingRewardsMap[player] = nil
	queuedLevelUpsMap[player] = 0
	if count > 0 then
		queuedLevelUpsMap[player] = math.max(0, math.floor(count) - 1)
		task.defer(function()
			if player.Parent then
				presentNextRewardModal(player)
			end
		end)
	end
end

function RewardService.ResetPlayer(player: Player)
	pendingRewardsMap[player] = nil
	queuedLevelUpsMap[player] = nil
	offerGenerationMap[player] = (offerGenerationMap[player] or 0) + 1
	PlayerStatsManager.SetLevelUpPhase(player, false)
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
	offerGenerationMap[player] = (offerGenerationMap[player] or 0) + 1

	applyChosenCard(player, chosenCard)

	local queued = queuedLevelUpsMap[player] or 0
	if queued > 0 then
		queuedLevelUpsMap[player] = queued - 1
		presentNextRewardModal(player)
	else
		-- Remove invulnerability & restore normal visibility/aggro
		PlayerStatsManager.SetLevelUpPhase(player, false)
	end
end)

function RewardService.Cleanup(player: Player)
	pendingRewardsMap[player] = nil
	queuedLevelUpsMap[player] = nil
	offerGenerationMap[player] = nil
	PlayerStatsManager.SetLevelUpPhase(player, false)
end

Players.PlayerRemoving:Connect(RewardService.Cleanup)

return RewardService
