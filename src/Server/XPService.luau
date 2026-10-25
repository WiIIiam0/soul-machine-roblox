--!strict
-- XPService.luau: Manages physical XP drops, magnetic attraction, leveling curve, and level-up triggers

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameEvents = require(Shared:WaitForChild("GameEvents"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerStatsManager = require(script.Parent.PlayerStatsManager)

export type XPGem = {
	part: BasePart,
	position: Vector3,
	value: number,
	isMeta: boolean,
	magnetizedTo: Player?,
	magnetSpeed: number,
}

export type PlayerXPState = {
	level: number,
	currentXP: number,
	xpToNextLevel: number,
	totalMetaXP: number,
}

local XPService = {}
local activeGems: { XPGem } = {}
local playerXPMap: { [Player]: PlayerXPState } = {}

local gemsFolder: Folder

local function getGemsFolder(): Folder
	if not gemsFolder or not gemsFolder.Parent then
		local found = Workspace:FindFirstChild("ActiveXPGems") :: Folder?
		if not found then
			found = Instance.new("Folder")
			found.Name = "ActiveXPGems"
			found.Parent = Workspace
		end
		gemsFolder = found
	end
	return gemsFolder
end

function XPService.InitPlayer(player: Player)
	local state: PlayerXPState = {
		level = 1,
		currentXP = 0,
		xpToNextLevel = 12,
		totalMetaXP = 0,
	}
	playerXPMap[player] = state
	XPService.SyncXP(player)
end

function XPService.GetPlayerLevel(player: Player): number
	local state = playerXPMap[player]
	if state then
		return state.level
	end
	return 1
end

function XPService.ExportState(player: Player): PlayerXPState?
	local state = playerXPMap[player]
	if not state then return nil end
	return {
		level = state.level,
		currentXP = state.currentXP,
		xpToNextLevel = state.xpToNextLevel,
		totalMetaXP = state.totalMetaXP,
	}
end

function XPService.ImportState(player: Player, saved: any)
	if type(saved) ~= "table" then return end
	local state: PlayerXPState = {
		level = math.max(1, math.floor(tonumber(saved.level) or 1)),
		currentXP = math.max(0, tonumber(saved.currentXP) or 0),
		xpToNextLevel = math.max(12, math.floor(tonumber(saved.xpToNextLevel) or 12)),
		totalMetaXP = math.max(0, tonumber(saved.totalMetaXP) or 0),
	}
	playerXPMap[player] = state
	XPService.SyncXP(player)
end

function XPService.ClearAllGems()
	for i = #activeGems, 1, -1 do
		local gem = activeGems[i]
		if gem.part and gem.part.Parent then
			gem.part:Destroy()
		end
		table.remove(activeGems, i)
	end
end

function XPService.SpawnGem(pos: Vector3, value: number, isMeta: boolean)
	local part = Instance.new("Part")
	part.Name = if isMeta then "MetaGem" else "XPGem"
	part.Size = if isMeta then Vector3.new(1.4, 1.4, 1.4) else Vector3.new(0.8, 0.8, 0.8)
	part.Position = pos + Vector3.new(0, 0.5, 0)
	part.Color = if isMeta then Color3.fromRGB(255, 215, 0) else Color3.fromRGB(0, 230, 255)
	part.Material = Enum.Material.Neon
	part.CanCollide = false
	part.Anchored = true
	part.CastShadow = false
	part.CFrame = CFrame.new(pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(math.rad(45), math.rad(45), 0)
	part.Parent = getGemsFolder()

	local gem: XPGem = {
		part = part,
		position = part.Position,
		value = value,
		isMeta = isMeta,
		magnetizedTo = nil,
		magnetSpeed = 12,
	}

	table.insert(activeGems, gem)
end

local function getAliveRecipients(): { Player }
	local list: { Player } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local pData = PlayerStatsManager.GetPlayerData(p)
		if pData and not pData.isDead and playerXPMap[p] ~= nil then
			table.insert(list, p)
		end
	end
	return list
end

-- Partage d'XP équitable : si 1 d'XP est ramassé et qu'il y a 4 joueurs vivants, chacun reçoit 1/4 = 0.25 XP
function XPService.DistributeSharedXP(totalAmount: number, isMeta: boolean, collector: Player?)
	local recipients = getAliveRecipients()
	if #recipients == 0 then
		if collector and playerXPMap[collector] then
			XPService.AddXP(collector, totalAmount, isMeta)
		end
		return
	end

	local count = #recipients
	if isMeta then
		local metaShare = 1.0 / count
		local displayShare = totalAmount / count
		for _, p in ipairs(recipients) do
			local state = playerXPMap[p]
			if state then
				state.totalMetaXP += displayShare
				GameEvents.OnXPCollected:Fire(p, metaShare, true)
				XPService.SyncXP(p)
			end
		end
	else
		local xpShare = totalAmount / count
		for _, p in ipairs(recipients) do
			XPService.AddXP(p, xpShare, false)
		end
	end
end

function XPService.AddXP(player: Player, amount: number, isMeta: boolean)
	local state = playerXPMap[player]
	if not state then return end

	if isMeta then
		state.totalMetaXP += amount
		GameEvents.OnXPCollected:Fire(player, amount, true)
		XPService.SyncXP(player)
		return
	end

	state.currentXP += amount
	GameEvents.OnXPCollected:Fire(player, amount, false)

	-- Check for level ups
	while state.currentXP >= state.xpToNextLevel do
		state.currentXP -= state.xpToNextLevel
		state.level += 1
		state.xpToNextLevel = math.floor(state.xpToNextLevel * 1.35)

		-- Baseline Soul Machine level up reward: +2 Max HP and heal
		PlayerStatsManager.AddStat(player, "MaxHP", 2)
		PlayerStatsManager.Heal(player, 10)

		GameEvents.OnLevelUp:Fire(player, state.level)

		-- Trigger Reward selection
		local RewardService = require(script.Parent.RewardService)
		RewardService.OfferLevelUpRewards(player)
	end

	XPService.SyncXP(player)
end

function XPService.SyncXP(player: Player)
	local state = playerXPMap[player]
	if not state then return end

	Remotes.GetEvent("StateSync"):FireClient(player, {
		level = state.level,
		currentXP = state.currentXP,
		xpToNextLevel = state.xpToNextLevel,
		totalMetaXP = state.totalMetaXP,
	})
end

-- Magnetic attraction tick loop
RunService.Heartbeat:Connect(function(dt: number)
	for i = #activeGems, 1, -1 do
		local gem = activeGems[i]
		if not gem.part or not gem.part.Parent then
			table.remove(activeGems, i)
			continue
		end

		-- Gentle rotation visual
		gem.part.CFrame = gem.part.CFrame * CFrame.Angles(0, math.rad(90 * dt), 0)

		-- Find closest player or track magnetized player (ignore dead or frozen Level-Up players)
		if not gem.magnetizedTo or not gem.magnetizedTo.Parent then
			for _, player in ipairs(Players:GetPlayers()) do
				local pData = PlayerStatsManager.GetPlayerData(player)
				if pData and not pData.isDead and not pData.isLevelUpPhase then
					local char = player.Character
					if char and char:FindFirstChild("HumanoidRootPart") then
						local pPos = (char:FindFirstChild("HumanoidRootPart") :: BasePart).Position
						local dist = (pPos - gem.position).Magnitude
						if dist <= pData.currentStats.PickupRadius then
							gem.magnetizedTo = player
							break
						end
					end
				end
			end
		end

		if gem.magnetizedTo and gem.magnetizedTo.Character then
			local char = gem.magnetizedTo.Character
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				local targetPos = hrp.Position + Vector3.new(0, 0.5, 0)
				local toPlayer = (targetPos - gem.position)
				local dist = toPlayer.Magnitude

				if dist <= 2.2 then
					-- Picked up! Distribute shared XP across all alive players in the zone
					XPService.DistributeSharedXP(gem.value, gem.isMeta, gem.magnetizedTo)
					gem.part:Destroy()
					table.remove(activeGems, i)
					continue
				else
					-- Accelerate toward player
					gem.magnetSpeed = math.min(65, gem.magnetSpeed + (55 * dt))
					local step = toPlayer.Unit * (gem.magnetSpeed * dt)
					gem.position = gem.position + step
					gem.part.Position = gem.position
				end
			else
				gem.magnetizedTo = nil
			end
		end
	end
end)

function XPService.Cleanup(player: Player)
	playerXPMap[player] = nil
end

Players.PlayerRemoving:Connect(XPService.Cleanup)

return XPService
