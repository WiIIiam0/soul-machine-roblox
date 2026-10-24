--!strict
-- MetaProgressionService.luau: Manages account-wide persistent totalXP (ADN), slot capacity, and unlock timeline
-- 100% faithful port of Unity MetaProgressionManager.cs

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MetaProgressionData = require(Shared:WaitForChild("MetaProgressionData"))
local GameEvents = require(Shared:WaitForChild("GameEvents"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DATA_STORE_NAME = "SoulMachine_Meta_v3"

export type PlayerMetaState = {
	totalXP: number,
	startingXP: number,
	weaponSlots: number,
	passiveSlots: number,
	statSlots: number,
	maxWeaponRank: number,
	maxStatRank: number,
	totalRuns: number,
	totalKills: number,
	sessionXP: number,
}

local MetaProgressionService = {}
local playerMetaMap: { [Player]: PlayerMetaState } = {}

-- Safe DataStore handle
local metaStore: DataStore? = nil
local dataStoreAvailable = false

local success, result = pcall(function()
	return DataStoreService:GetDataStore(DATA_STORE_NAME)
end)
if success and result then
	metaStore = result
	dataStoreAvailable = true
else
	warn("[MetaProgressionService] DataStore access not available (Studio/offline). Using in-memory fallback.")
end

local function recalculateStateCaps(state: PlayerMetaState)
	state.weaponSlots = MetaProgressionData.GetMaxWeaponSlots(state.totalXP)
	state.passiveSlots = MetaProgressionData.GetMaxPassiveSlots(state.totalXP)
	state.statSlots = MetaProgressionData.GetMaxStatSlots(state.totalXP)
	state.maxWeaponRank = MetaProgressionData.GetMaxWeaponRank(state.totalXP)
	state.maxStatRank = MetaProgressionData.GetMaxStatRank(state.totalXP)
end

function MetaProgressionService.InitPlayer(player: Player)
	local defaultState: PlayerMetaState = {
		totalXP = 0,
		startingXP = 0,
		weaponSlots = 1,
		passiveSlots = 1,
		statSlots = 1,
		maxWeaponRank = 1,
		maxStatRank = 3,
		totalRuns = 0,
		totalKills = 0,
		sessionXP = 0,
	}
	recalculateStateCaps(defaultState)

	if dataStoreAvailable and metaStore then
		local key = "Player_" .. tostring(player.UserId)
		local loadSuccess, data = pcall(function()
			return metaStore:GetAsync(key)
		end)

		if loadSuccess and data and type(data) == "table" then
			local xp = math.max(0, tonumber(data.totalXP) or tonumber(data.xp) or 0)
			defaultState.totalXP = xp
			defaultState.startingXP = xp
			defaultState.totalRuns = (tonumber(data.totalRuns) or 0) + 1
			defaultState.totalKills = tonumber(data.totalKills) or 0
			recalculateStateCaps(defaultState)
			print(string.format("[MetaProgressionService] Loaded progression for %s: %d ADN XP (Slots: %d ARM, %d PAS, %d STAT)", player.Name, xp, defaultState.weaponSlots, defaultState.passiveSlots, defaultState.statSlots))
		else
			print(string.format("[MetaProgressionService] No previous save or new player for %s, starting fresh.", player.Name))
		end
	end

	playerMetaMap[player] = defaultState
	MetaProgressionService.SyncMeta(player)
end

function MetaProgressionService.GetPlayerMeta(player: Player): PlayerMetaState
	local state = playerMetaMap[player]
	if state then
		return state
	end
	local fallback: PlayerMetaState = {
		totalXP = 0,
		startingXP = 0,
		weaponSlots = 1,
		passiveSlots = 1,
		statSlots = 1,
		maxWeaponRank = 1,
		maxStatRank = 3,
		totalRuns = 1,
		totalKills = 0,
		sessionXP = 0,
	}
	recalculateStateCaps(fallback)
	return fallback
end

function MetaProgressionService.AddGlobalXP(player: Player, amount: number, source: string)
	local state = playerMetaMap[player]
	if not state then return end

	local oldXP = state.totalXP
	state.totalXP += amount
	state.sessionXP += amount

	local oldWeaponSlots = state.weaponSlots
	local oldPassiveSlots = state.passiveSlots
	local oldStatSlots = state.statSlots

	recalculateStateCaps(state)

	local newlyUnlocked = MetaProgressionData.GetNewlyUnlockedItems(oldXP, state.totalXP)
	if #newlyUnlocked > 0 then
		for _, item in ipairs(newlyUnlocked) do
			print(string.format("[MetaProgressionService] ★ UNLOCK REACHED for %s! %s (at %d ADN)", player.Name, item.description or item.unlockName, item.requiredXP))
		end

		Remotes.GetEvent("GlobalLevelUp"):FireClient(player, {
			totalXP = state.totalXP,
			newlyUnlocked = newlyUnlocked,
		})
	end

	MetaProgressionService.SyncMeta(player)

	if #newlyUnlocked > 0 or state.sessionXP >= 20 then
		MetaProgressionService.SavePlayer(player)
	end
end

function MetaProgressionService.SyncMeta(player: Player)
	local state = playerMetaMap[player]
	if not state then return end

	Remotes.GetEvent("MetaSync"):FireClient(player, {
		totalXP = state.totalXP,
		startingXP = state.startingXP,
		weaponSlots = state.weaponSlots,
		passiveSlots = state.passiveSlots,
		statSlots = state.statSlots,
		maxWeaponRank = state.maxWeaponRank,
		maxStatRank = state.maxStatRank,
		maxTimelineXP = MetaProgressionData.GetMaxTimelineXP(),
		nextUpcomingXP = MetaProgressionData.GetNextUpcomingXP(),
		totalRuns = state.totalRuns,
		totalKills = state.totalKills,
		sessionXP = state.sessionXP,
	})
end

function MetaProgressionService.SavePlayer(player: Player)
	local state = playerMetaMap[player]
	if not state or not dataStoreAvailable or not metaStore then return end

	local key = "Player_" .. tostring(player.UserId)
	local payload = {
		totalXP = state.totalXP,
		totalRuns = state.totalRuns,
		totalKills = state.totalKills,
		lastSaved = os.time(),
	}

	local saveSuccess, err = pcall(function()
		metaStore:SetAsync(key, payload)
	end)

	if not saveSuccess then
		warn("[MetaProgressionService] Failed to save data for " .. player.Name .. ": " .. tostring(err))
	else
		print("[MetaProgressionService] Successfully saved data for " .. player.Name)
	end
end

function MetaProgressionService.Cleanup(player: Player)
	MetaProgressionService.SavePlayer(player)
	playerMetaMap[player] = nil
end

Players.PlayerRemoving:Connect(MetaProgressionService.Cleanup)

-- Listen to Game Events to award Global XP automatically
GameEvents.OnWaveCompleted:Connect(function(waveNum: number)
	for _, player in ipairs(Players:GetPlayers()) do
		MetaProgressionService.AddGlobalXP(player, 10 + (waveNum * 2), "WaveCompleted")
	end
end)

GameEvents.OnEnemyKilled:Connect(function(enemyData: any, killerPlayer: Player?)
	if killerPlayer and killerPlayer:IsA("Player") then
		local state = playerMetaMap[killerPlayer]
		if state then
			state.totalKills += 1
		end

		local amount = 1
		if enemyData and enemyData.config then
			if enemyData.config.isBoss then
				amount = 25
			elseif enemyData.config.isMetaEnemy then
				amount = 5
			end
		end
		MetaProgressionService.AddGlobalXP(killerPlayer, amount, "EnemyKill")
	end
end)

GameEvents.OnXPCollected:Connect(function(player: Player, amount: number, isMeta: boolean)
	if isMeta then
		-- Meta Gem collected gives 1 ADN XP directly (matches MetaXPGem.cs metaXpValue = 1)
		MetaProgressionService.AddGlobalXP(player, 1, "MetaGem")
	end
end)

return MetaProgressionService
