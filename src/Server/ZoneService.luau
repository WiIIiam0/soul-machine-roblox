--!strict
-- ZoneService.luau: Gestion du serveur de Zone courant, du Téléporteur verrouillé par niveau, et du TeleportService multi-serveurs

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZonesData = require(Shared:WaitForChild("ZonesData"))
local GameEvents = require(Shared:WaitForChild("GameEvents"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ArenaBuilder = require(script.Parent.ArenaBuilder)
local PlayerStatsManager = require(script.Parent.PlayerStatsManager)
local WeaponService = require(script.Parent.WeaponService)
local XPService = require(script.Parent.XPService)
local PassiveService = require(script.Parent.PassiveService)
local RewardService = require(script.Parent.RewardService)
local MetaProgressionService = require(script.Parent.MetaProgressionService)
local EnemyService = require(script.Parent.EnemyService)
local ProjectileService = require(script.Parent.ProjectileService)
local RunTransferService = require(script.Parent.RunTransferService)

local ZoneService = {}

local currentZoneId: number = 1
local teleportingPlayers: { [Player]: boolean } = {}
local rejectCooldowns: { [Player]: number } = {}
local spawnGraceUntil: { [Player]: number } = {}
local zoneChangedListeners: { (number) -> () } = {}

local function fireZoneChanged(newZoneId: number)
	for _, fn in ipairs(zoneChangedListeners) do
		task.spawn(fn, newZoneId)
	end
end

function ZoneService.OnZoneChanged(callback: (number) -> ())
	table.insert(zoneChangedListeners, callback)
end

function ZoneService.GetCurrentZoneId(): number
	return currentZoneId
end

function ZoneService.GetCurrentZoneConfig(): ZonesData.ZoneConfig
	return ZonesData.GetZone(currentZoneId)
end

function ZoneService.IsPlayerTeleporting(player: Player): boolean
	return teleportingPlayers[player] == true
end

function ZoneService.MarkPlayerArrived(player: Player)
	spawnGraceUntil[player] = os.clock() + 2.0
	ZoneService.SyncZoneToClient(player)
end

function ZoneService.SyncZoneToClient(player: Player)
	local zone = ZonesData.GetZone(currentZoneId)
	local nextZone = if zone.nextZoneId then ZonesData.GetZone(zone.nextZoneId) else nil
	Remotes.GetEvent("StateSync"):FireClient(player, {
		zoneId = zone.zoneId,
		zoneName = zone.name,
		zoneSubtitle = zone.subtitle,
		nextZoneId = zone.nextZoneId or 0,
		nextZoneName = if nextZone then nextZone.name else "",
		nextZoneRequiredLevel = zone.nextZoneRequiredLevel or 0,
	})
end

function ZoneService.Init()
	local detectedZone = ZonesData.ResolveZoneIdFromPlaceId(game.PlaceId)
	if not detectedZone then
		local attrZone = tonumber(Workspace:GetAttribute("ZoneId"))
		if attrZone and attrZone >= 1 then
			detectedZone = math.floor(attrZone)
		end
	end

	currentZoneId = detectedZone or 1
	local zoneCfg = ZonesData.GetZone(currentZoneId)
	print(string.format("[ZoneService] Serveur initialisé sur %s (PlaceId=%d)", zoneCfg.name, game.PlaceId))

	ArenaBuilder.BuildArena(zoneCfg)
end

local function switchLocalStudioZone(targetZoneId: number)
	currentZoneId = targetZoneId
	local targetZone = ZonesData.GetZone(currentZoneId)

	EnemyService.ClearAllEnemies()
	XPService.ClearAllGems()
	ProjectileService.ClearAll()
	ArenaBuilder.BuildArena(targetZone)
	fireZoneChanged(currentZoneId)

	for _, p in ipairs(Players:GetPlayers()) do
		teleportingPlayers[p] = nil
		spawnGraceUntil[p] = os.clock() + 2.0

		local hasPendingRewards = RewardService.ExportUnclaimedCount(p) > 0
		PlayerStatsManager.SetLevelUpPhase(p, hasPendingRewards)

		local char = p.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				hrp.CFrame = CFrame.new(math.random(-6, 6), 4, math.random(-6, 6))
			end
		end

		Remotes.GetEvent("StateSync"):FireClient(p, {
			teleportingToZone = "",
		})
		ZoneService.SyncZoneToClient(p)
	end
end

local function initiateZoneTeleport(player: Player, targetZoneId: number)
	if teleportingPlayers[player] then return end
	teleportingPlayers[player] = true

	local targetZone = ZonesData.GetZone(targetZoneId)
	local targetPlaceId = ZonesData.GetPlaceId(targetZoneId)

	-- Invulnérabilité immédiate pendant le transfert
	PlayerStatsManager.SetLevelUpPhase(player, true)

	local portalPos = ArenaBuilder.PORTAL_POSITION + Vector3.new(0, 2, 0)
	Remotes.GetEvent("VFXEvent"):FireAllClients("Explosion", portalPos, 14, targetZone.themeColor)
	Remotes.GetEvent("StateSync"):FireClient(player, {
		teleportingToZone = targetZone.name,
	})

	-- Sauvegarde permanente (ADN) + Sauvegarde temporaire de run (MemoryStoreService)
	MetaProgressionService.SavePlayer(player)
	RunTransferService.SaveRunForTeleport(player, targetZoneId)

	local canTeleportAcrossServers = (not RunService:IsStudio()) and (targetPlaceId > 0)
	if canTeleportAcrossServers then
		print(string.format("[ZoneService] Téléportation inter-serveurs de %s vers %s (PlaceId=%d)...", player.Name, targetZone.name, targetPlaceId))
		local tpOptions = Instance.new("TeleportOptions")
		tpOptions:SetTeleportData({
			fromZoneId = currentZoneId,
			targetZoneId = targetZoneId,
		})

		local ok, err = pcall(function()
			TeleportService:TeleportAsync(targetPlaceId, { player }, tpOptions)
		end)

		if not ok then
			warn(string.format("[ZoneService] Échec TeleportAsync pour %s : %s", player.Name, tostring(err)))
			teleportingPlayers[player] = nil
			local hasPending = RewardService.ExportUnclaimedCount(player) > 0
			PlayerStatsManager.SetLevelUpPhase(player, hasPending)
			Remotes.GetEvent("StateSync"):FireClient(player, {
				teleportingToZone = "",
			})
		end
	else
		print(string.format("[ZoneService] Mode Studio / PlaceId=0 : Bascule locale vers %s", targetZone.name))
		task.delay(0.65, function()
			switchLocalStudioZone(targetZoneId)
		end)
	end
end

-- Gestion d'erreur asynchrone de TeleportService côté Roblox
TeleportService.TeleportInitFailed:Connect(function(player: Player, teleportResult: Enum.TeleportResult, errorMessage: string)
	warn(string.format("[ZoneService] TeleportInitFailed pour %s (%s): %s", player.Name, tostring(teleportResult), errorMessage))
	teleportingPlayers[player] = nil
	local hasPending = RewardService.ExportUnclaimedCount(player) > 0
	PlayerStatsManager.SetLevelUpPhase(player, hasPending)
	Remotes.GetEvent("StateSync"):FireClient(player, {
		teleportingToZone = "",
	})
end)

function ZoneService.RedirectUnauthorizedPlayerToZone1(player: Player): boolean
	local place1 = ZonesData.GetPlaceId(1)
	if currentZoneId > 1 and (not RunService:IsStudio()) and place1 > 0 then
		teleportingPlayers[player] = true
		Remotes.GetEvent("StateSync"):FireClient(player, {
			teleportingToZone = ZonesData.GetZone(1).name,
		})
		pcall(function()
			TeleportService:TeleportAsync(place1, { player })
		end)
		return true
	end
	return false
end

function ZoneService.RestartPlayerToZone1(player: Player)
	teleportingPlayers[player] = nil
	RunTransferService.ClearRunState(player)
	RewardService.ResetPlayer(player)
	MetaProgressionService.SavePlayer(player)

	local place1 = ZonesData.GetPlaceId(1)
	if currentZoneId > 1 then
		if (not RunService:IsStudio()) and place1 > 0 then
			teleportingPlayers[player] = true
			Remotes.GetEvent("StateSync"):FireClient(player, {
				teleportingToZone = ZonesData.GetZone(1).name,
			})
			local ok, err = pcall(function()
				TeleportService:TeleportAsync(place1, { player })
			end)
			if not ok then
				warn("[ZoneService] Échec retour Zone 1 pour " .. player.Name .. ": " .. tostring(err))
				teleportingPlayers[player] = nil
			end
			return
		else
			-- Retour Zone 1 en simulation locale Studio
			PlayerStatsManager.InitPlayer(player)
			WeaponService.InitPlayer(player)
			XPService.InitPlayer(player)
			PassiveService.InitPlayer(player)
			MetaProgressionService.SyncMeta(player)
			player:LoadCharacter()
			switchLocalStudioZone(1)
			return
		end
	end

	-- Déjà en Zone 1 : réinitialisation immédiate sur place
	PlayerStatsManager.InitPlayer(player)
	WeaponService.InitPlayer(player)
	XPService.InitPlayer(player)
	PassiveService.InitPlayer(player)
	MetaProgressionService.SyncMeta(player)
	ZoneService.SyncZoneToClient(player)
	player:LoadCharacter()
end

-- Notification automatique dès qu'un joueur atteint le niveau requis pour le portail de la zone
GameEvents.OnLevelUp:Connect(function(player: Player, newLevel: number)
	local zone = ZonesData.GetZone(currentZoneId)
	if zone.nextZoneId and zone.nextZoneRequiredLevel and newLevel == zone.nextZoneRequiredLevel then
		local nextZone = ZonesData.GetZone(zone.nextZoneId)
		Remotes.GetEvent("StateSync"):FireClient(player, {
			portalUnlockedAlert = string.format("⚡ PORTAIL DÉVERROUILLÉ : %s ACCESSIBLE AU NORD !", nextZone.name),
		})
	end
end)

-- Boucle de détection du Téléporteur (vérification stricte du niveau requis)
RunService.Heartbeat:Connect(function(_dt: number)
	local zone = ZonesData.GetZone(currentZoneId)
	if not zone.nextZoneId or not zone.nextZoneRequiredLevel then
		return
	end

	local portalPos = ArenaBuilder.PORTAL_POSITION
	local radius = ArenaBuilder.PORTAL_RADIUS
	local now = os.clock()

	for _, player in ipairs(Players:GetPlayers()) do
		if teleportingPlayers[player] then continue end
		if (spawnGraceUntil[player] or 0) > now then continue end

		local pData = PlayerStatsManager.GetPlayerData(player)
		if not pData or pData.isDead then continue end

		local char = player.Character
		if not char then continue end
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then continue end

		local pPos = hrp.Position
		local dx = pPos.X - portalPos.X
		local dz = pPos.Z - portalPos.Z
		local flatDist = math.sqrt(dx * dx + dz * dz)

		if flatDist <= radius then
			local level = XPService.GetPlayerLevel(player)
			if level >= zone.nextZoneRequiredLevel then
				initiateZoneTeleport(player, zone.nextZoneId)
			else
				-- Repousse le joueur hors du socle s'il n'a pas le niveau requis
				local pushZ = portalPos.Z + radius + 3.0
				hrp.CFrame = CFrame.new(pPos.X, pPos.Y, pushZ) * hrp.CFrame.Rotation

				if now - (rejectCooldowns[player] or 0) >= 1.4 then
					rejectCooldowns[player] = now
					Remotes.GetEvent("FloatingText"):FireClient(
						player,
						portalPos + Vector3.new(0, 5, 0),
						string.format("NIVEAU %d REQUIS !", zone.nextZoneRequiredLevel),
						Color3.fromRGB(255, 70, 70),
						true
					)
					Remotes.GetEvent("VFXEvent"):FireClient(
						player,
						"Explosion",
						portalPos + Vector3.new(0, 1.5, 0),
						7,
						Color3.fromRGB(255, 60, 60)
					)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	teleportingPlayers[player] = nil
	rejectCooldowns[player] = nil
	spawnGraceUntil[player] = nil
end)

return ZoneService
