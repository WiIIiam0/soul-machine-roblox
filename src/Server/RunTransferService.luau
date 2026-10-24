--!strict
-- RunTransferService.luau: Sauvegarde et restauration inter-serveurs (MemoryStoreService) de la run en cours lors d'un TP de Zone

local MemoryStoreService = game:GetService("MemoryStoreService")

local PlayerStatsManager = require(script.Parent.PlayerStatsManager)
local WeaponService = require(script.Parent.WeaponService)
local XPService = require(script.Parent.XPService)
local PassiveService = require(script.Parent.PassiveService)
local RewardService = require(script.Parent.RewardService)

local MAP_NAME = "SoulMachine_RunTransfer_v1"
local SNAPSHOT_TTL_SECONDS = 300

local RunTransferService = {}

local transferMap: MemoryStoreSortedMap? = nil
local localFallbackCache: { [string]: any } = {}

local ok, mapResult = pcall(function()
	return MemoryStoreService:GetSortedMap(MAP_NAME)
end)
if ok and mapResult then
	transferMap = mapResult
end

local function makeKey(userId: number): string
	return "Run_" .. tostring(userId)
end

function RunTransferService.SaveRunForTeleport(player: Player, targetZoneId: number): boolean
	local key = makeKey(player.UserId)
	local snapshot = {
		targetZoneId = targetZoneId,
		savedAt = os.time(),
		stats = PlayerStatsManager.ExportState(player),
		weapons = WeaponService.ExportState(player),
		xp = XPService.ExportState(player),
		passives = PassiveService.ExportState(player),
		unclaimedRewards = RewardService.ExportUnclaimedCount(player),
	}

	localFallbackCache[key] = snapshot

	if transferMap then
		local saveOk, err = pcall(function()
			transferMap:SetAsync(key, snapshot, SNAPSHOT_TTL_SECONDS)
		end)
		if not saveOk then
			warn("[RunTransferService] MemoryStore SetAsync warning for " .. player.Name .. ": " .. tostring(err))
			return false
		end
	end

	return true
end

function RunTransferService.ConsumeRunOnArrival(player: Player): any?
	local key = makeKey(player.UserId)
	local snapshot: any = nil

	if transferMap then
		local readOk, data = pcall(function()
			return transferMap:GetAsync(key)
		end)
		if readOk and type(data) == "table" then
			snapshot = data
			pcall(function()
				transferMap:RemoveAsync(key)
			end)
		end
	end

	if not snapshot and localFallbackCache[key] then
		snapshot = localFallbackCache[key]
	end
	localFallbackCache[key] = nil

	if type(snapshot) == "table" then
		local age = os.time() - (tonumber(snapshot.savedAt) or 0)
		if age <= SNAPSHOT_TTL_SECONDS then
			return snapshot
		end
	end

	return nil
end

function RunTransferService.RestorePlayerFromSnapshot(player: Player, snapshot: any)
	if type(snapshot) ~= "table" then return end

	if snapshot.stats then
		PlayerStatsManager.ImportState(player, snapshot.stats)
	end
	if snapshot.weapons then
		WeaponService.ImportState(player, snapshot.weapons)
	end
	if snapshot.xp then
		XPService.ImportState(player, snapshot.xp)
	end
	if snapshot.passives then
		PassiveService.ImportState(player, snapshot.passives)
	end
	if type(snapshot.unclaimedRewards) == "number" and snapshot.unclaimedRewards > 0 then
		RewardService.ImportUnclaimedCount(player, snapshot.unclaimedRewards)
	end
end

function RunTransferService.ClearRunState(player: Player)
	local key = makeKey(player.UserId)
	localFallbackCache[key] = nil
	if transferMap then
		pcall(function()
			transferMap:RemoveAsync(key)
		end)
	end
end

return RunTransferService
