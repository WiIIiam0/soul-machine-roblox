--!strict
-- ServerInit.server.luau: Master server entry point bootstrapping Zone Arena, cross-server Run Transfer, and services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Disable ClickToMove and ShiftLock to prevent cursor locking / center dot and pathfinding drift
StarterPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.KeyboardMouse
StarterPlayer.EnableMouseLockOption = false

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

-- 1. Initialize Network Remotes FIRST so they are available immediately
Remotes.Init()

local ZoneService = require(script.Parent.ZoneService)
local RunTransferService = require(script.Parent.RunTransferService)
local PlayerStatsManager = require(script.Parent.PlayerStatsManager)
local WeaponService = require(script.Parent.WeaponService)
local XPService = require(script.Parent.XPService)
local PassiveService = require(script.Parent.PassiveService)
local MetaProgressionService = require(script.Parent.MetaProgressionService)
local EnemyDirector = require(script.Parent.EnemyDirector)

print("[SoulMachine / BrotatoRoblox] Initializing Multi-Zone Server Systems...")

-- 2. Detect Zone from PlaceId & Build Zone Battle Arena + Level Teleporter
ZoneService.Init()

-- 3. Handle Player Setup (Drop-in Zone 1 OR Cross-Server Run Transfer into Zone 2/3/4)
local function setupPlayer(player: Player)
	MetaProgressionService.InitPlayer(player)
	PlayerStatsManager.InitPlayer(player)
	WeaponService.InitPlayer(player)
	XPService.InitPlayer(player)
	PassiveService.InitPlayer(player)

	local zoneCfg = ZoneService.GetCurrentZoneConfig()
	local snapshot = RunTransferService.ConsumeRunOnArrival(player)

	if snapshot then
		local savedLevel = if snapshot.xp and type(snapshot.xp.level) == "number" then snapshot.xp.level else 1
		if savedLevel >= zoneCfg.minLevel then
			RunTransferService.RestorePlayerFromSnapshot(player, snapshot)
			print(string.format("[ServerInit] Run inter-serveurs restaurée pour %s dans %s (Niv. %d)", player.Name, zoneCfg.name, savedLevel))
		elseif ZoneService.RedirectUnauthorizedPlayerToZone1(player) then
			return
		end
	elseif zoneCfg.zoneId > 1 then
		-- Si un joueur tente de rejoindre directement un serveur Zone 2+ sans être passé par le TP
		if ZoneService.RedirectUnauthorizedPlayerToZone1(player) then
			return
		end
	end

	ZoneService.MarkPlayerArrived(player)

	local function setupCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?

		if humanoid and hrp then
			local pData = PlayerStatsManager.GetPlayerData(player)
			if pData then
				humanoid.MaxHealth = pData.maxHP
				humanoid.Health = pData.currentHP
				humanoid.WalkSpeed = pData.currentStats.Speed
			end

			-- Spawn léger décalage aléatoire autour du centre pour la coop multi-joueurs
			hrp.CFrame = CFrame.new(math.random(-6, 6), 4, math.random(-6, 6))

			-- 3 secondes d'immunité + non-aggro à l'arrivée dans la zone (déplacement libre)
			PlayerStatsManager.GrantSpawnProtection(player, 3.0)
			task.delay(0.15, function()
				if player.Parent then
					PlayerStatsManager.RefreshPhaseVisuals(player)
				end
			end)

			ZoneService.SyncZoneToClient(player)
		end
	end

	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		task.spawn(setupCharacter, player.Character)
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, p)
end
Players.PlayerAdded:Connect(setupPlayer)

-- Handle Run Restart on Player Death / Game Over (retour automatique en Zone 1 Niveau 1)
Remotes.GetEvent("RestartRun").OnServerEvent:Connect(function(player: Player)
	print(string.format("[ServerInit] %s demande une nouvelle run -> retour Zone 1.", player.Name))
	ZoneService.RestartPlayerToZone1(player)
end)

-- 4. Start Endless Zone Enemy Director
EnemyDirector.Start()

print("[SoulMachine / BrotatoRoblox] Server initialization complete! Ready for Cooperative Swarm combat.")
