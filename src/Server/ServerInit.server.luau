--!strict
-- ServerInit.server.luau: Master server entry point bootstrapping arena and services

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

local ArenaBuilder = require(script.Parent.ArenaBuilder)
local PlayerStatsManager = require(script.Parent.PlayerStatsManager)
local WeaponService = require(script.Parent.WeaponService)
local XPService = require(script.Parent.XPService)
local PassiveService = require(script.Parent.PassiveService)
local EnemyDirector = require(script.Parent.EnemyDirector)

print("[SoulMachine / BrotatoRoblox] Initializing Server Systems...")

-- 2. Build Battle Arena
ArenaBuilder.BuildArena()

-- 3. Handle Player Setup
local function setupPlayer(player: Player)
	PlayerStatsManager.InitPlayer(player)
	WeaponService.InitPlayer(player)
	XPService.InitPlayer(player)
	PassiveService.InitPlayer(player)

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

			-- Spawn at arena center safely above spawn pad
			hrp.CFrame = CFrame.new(0, 4, 0)
		end
	end

	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		task.spawn(setupCharacter, player.Character)
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	setupPlayer(p)
end
Players.PlayerAdded:Connect(setupPlayer)

-- 4. Start Enemy Director
EnemyDirector.Start()

print("[SoulMachine / BrotatoRoblox] Server initialization complete! Ready for Swarm combat.")
