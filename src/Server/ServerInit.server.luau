--!strict
-- ServerInit.server.luau: Master server entry point bootstrapping arena and services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local ArenaBuilder = require(script.Parent.ArenaBuilder)
local PlayerStatsManager = require(script.Parent.PlayerStatsManager)
local WeaponService = require(script.Parent.WeaponService)
local XPService = require(script.Parent.XPService)
local PassiveService = require(script.Parent.PassiveService)
local EnemyDirector = require(script.Parent.EnemyDirector)

print("[SoulMachine / BrotatoRoblox] Initializing Server Systems...")

-- 1. Initialize Network Remotes
Remotes.Init()

-- 2. Build Battle Arena
ArenaBuilder.BuildArena()

-- 3. Handle Player Setup
local function setupPlayer(player: Player)
	PlayerStatsManager.InitPlayer(player)
	WeaponService.InitPlayer(player)
	XPService.InitPlayer(player)
	PassiveService.InitPlayer(player)

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?

		if humanoid and hrp then
			local pData = PlayerStatsManager.GetPlayerData(player)
			if pData then
				humanoid.MaxHealth = pData.maxHP
				humanoid.Health = pData.currentHP
				humanoid.WalkSpeed = pData.currentStats.Speed
				humanoid.AutoRotate = true
			end

			-- Spawn at arena center
			hrp.CFrame = CFrame.new(0, 4, 0)
		end
	end)

	if player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local pData = PlayerStatsManager.GetPlayerData(player)
			if pData then
				humanoid.WalkSpeed = pData.currentStats.Speed
			end
		end
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	setupPlayer(p)
end
Players.PlayerAdded:Connect(setupPlayer)

-- 4. Start Enemy Director
EnemyDirector.Start()

print("[SoulMachine / BrotatoRoblox] Server initialization complete! Ready for Swarm combat.")
