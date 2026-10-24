--!strict
-- MetaProgressionService.luau: Manages account-wide persistent level, unlocks, slot capacity, and global XP

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MetaProgressionData = require(Shared:WaitForChild("MetaProgressionData"))
local GameEvents = require(Shared:WaitForChild("GameEvents"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DATA_STORE_NAME = "SoulMachine_Meta_v2"

export type PlayerMetaState = {
	level: number,
	xp: number,
	xpToNextLevel: number,
	weaponSlots: number,
	passiveSlots: number,
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

function MetaProgressionService.InitPlayer(player: Player)
	local defaultState: PlayerMetaState = {
		level = 1,
		xp = 0,
		xpToNextLevel = MetaProgressionData.GetXPForLevel(1),
		weaponSlots = MetaProgressionData.GetWeaponSlots(1),
		passiveSlots = MetaProgressionData.GetPassiveSlots(1),
		totalRuns = 0,
		totalKills = 0,
		sessionXP = 0,
	}

	if dataStoreAvailable and metaStore then
		local key = "Player_" .. tostring(player.UserId)
		local loadSuccess, data = pcall(function()
			return metaStore:GetAsync(key)
		end)

		if loadSuccess and data and type(data) == "table" then
			local level = math.max(1, tonumber(data.level) or 1)
			local xp = math.max(0, tonumber(data.xp) or 0)
			defaultState.level = level
			defaultState.xp = xp
			defaultState.xpToNextLevel = MetaProgressionData.GetXPForLevel(level)
			defaultState.weaponSlots = MetaProgressionData.GetWeaponSlots(level)
			defaultState.passiveSlots = MetaProgressionData.GetPassiveSlots(level)
			defaultState.totalRuns = (tonumber(data.totalRuns) or 0) + 1
			defaultState.totalKills = tonumber(data.totalKills) or 0
			print(string.format("[MetaProgressionService] Loaded data for %s: Niv. %d (%d XP)", player.Name, level, xp))
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
	return {
		level = 1,
		xp = 0,
		xpToNextLevel = MetaProgressionData.GetXPForLevel(1),
		weaponSlots = 4,
		passiveSlots = 4,
		totalRuns = 1,
		totalKills = 0,
		sessionXP = 0,
	}
end

function MetaProgressionService.AddGlobalXP(player: Player, amount: number, source: string)
	local state = playerMetaMap[player]
	if not state then return end

	state.xp += amount
	state.sessionXP += amount

	local didLevelUp = false
	while state.xp >= state.xpToNextLevel do
		state.xp -= state.xpToNextLevel
		state.level += 1
		state.xpToNextLevel = MetaProgressionData.GetXPForLevel(state.level)
		state.weaponSlots = MetaProgressionData.GetWeaponSlots(state.level)
		state.passiveSlots = MetaProgressionData.GetPassiveSlots(state.level)
		didLevelUp = true

		local unlockInfo = MetaProgressionData.GetUnlockInfoForLevel(state.level)
		print(string.format("[MetaProgressionService] ★ GLOBAL LEVEL UP! %s reached Global Level %d! Unlocks: %s", player.Name, state.level, unlockInfo and unlockInfo.description or "None"))

		Remotes.GetEvent("GlobalLevelUp"):FireClient(player, {
			newLevel = state.level,
			unlockInfo = unlockInfo,
		})
	end

	MetaProgressionService.SyncMeta(player)

	if didLevelUp then
		MetaProgressionService.SavePlayer(player)
	end
end

function MetaProgressionService.SyncMeta(player: Player)
	local state = playerMetaMap[player]
	if not state then return end

	Remotes.GetEvent("MetaSync"):FireClient(player, {
		globalLevel = state.level,
		globalXP = state.xp,
		xpToNextLevel = state.xpToNextLevel,
		weaponSlots = state.weaponSlots,
		passiveSlots = state.passiveSlots,
		totalRuns = state.totalRuns,
		totalKills = state.totalKills,
		sessionXP = state.sessionXP,
		unlockedWeapons = MetaProgressionData.GetAllUnlockedWeapons(state.level),
		unlockedPassives = MetaProgressionData.GetAllUnlockedPassives(state.level),
	})
end

function MetaProgressionService.SavePlayer(player: Player)
	local state = playerMetaMap[player]
	if not state or not dataStoreAvailable or not metaStore then return end

	local key = "Player_" .. tostring(player.UserId)
	local payload = {
		level = state.level,
		xp = state.xp,
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
		MetaProgressionService.AddGlobalXP(player, 40 + (waveNum * 5), "WaveCompleted")
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
				amount = 100
			elseif enemyData.config.isMetaEnemy then
				amount = 15
			end
		end
		MetaProgressionService.AddGlobalXP(killerPlayer, amount, "EnemyKill")
	end
end)

GameEvents.OnXPCollected:Connect(function(player: Player, amount: number, isMeta: boolean)
	if isMeta then
		-- Meta Gem collected gives substantial permanent account progression
		MetaProgressionService.AddGlobalXP(player, 15, "MetaGem")
	end
end)

return MetaProgressionService
