--!strict
-- PlayerStatsManager.luau: Manages player health, dynamic stats, overdrive, and stat items

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatTypes = require(Shared:WaitForChild("StatTypes"))
local GameEvents = require(Shared:WaitForChild("GameEvents"))
local Remotes = require(Shared:WaitForChild("Remotes"))

export type PlayerData = {
	player: Player,
	currentHP: number,
	maxHP: number,
	currentOverdrive: number,
	maxOverdrive: number,
	isOverdriveActive: boolean,
	overdriveDuration: number,
	overdriveEndTime: number,
	baseStats: StatTypes.PlayerStats,
	statBonuses: { [StatTypes.StatType]: number },
	statCardLevels: { [string]: number },
	currentStats: StatTypes.PlayerStats,
	isDead: boolean,
	isLevelUpPhase: boolean,
}

local PlayerStatsManager = {}
local playerDataMap: { [Player]: PlayerData } = {}

function PlayerStatsManager.InitPlayer(player: Player): PlayerData
	local base = StatTypes.CloneStats(StatTypes.DEFAULT_STATS)
	local data: PlayerData = {
		player = player,
		currentHP = base.MaxHP,
		maxHP = base.MaxHP,
		currentOverdrive = 0,
		maxOverdrive = 100,
		isOverdriveActive = false,
		overdriveDuration = 8, -- 8 seconds of Overdrive hyper-burst
		overdriveEndTime = 0,
		baseStats = base,
		statBonuses = {
			MaxHP = 0,
			Speed = 0,
			DamageMultiplier = 0,
			FireRateMultiplier = 0,
			Armor = 0,
			CriticalChance = 0,
			PickupRadius = 0,
			LifeSteal = 0,
			BurnDamage = 0,
			RangeMultiplier = 0,
		},
		statCardLevels = {},
		currentStats = StatTypes.CloneStats(base),
		isDead = false,
		isLevelUpPhase = false,
	}

	playerDataMap[player] = data
	PlayerStatsManager.RecalculateStats(player)
	return data
end

function PlayerStatsManager.GetPlayerData(player: Player): PlayerData?
	return playerDataMap[player]
end

function PlayerStatsManager.RecalculateStats(player: Player)
	local data = playerDataMap[player]
	if not data then return end

	local base = data.baseStats
	local bonus = data.statBonuses

	local prevMaxHP = data.maxHP
	local newMaxHP = math.max(10, base.MaxHP + (bonus.MaxHP or 0))
	data.maxHP = newMaxHP
	data.currentStats.MaxHP = newMaxHP

	-- If Max HP grew, scale or add to current HP proportionally
	if newMaxHP > prevMaxHP then
		data.currentHP = math.min(newMaxHP, data.currentHP + (newMaxHP - prevMaxHP))
	else
		data.currentHP = math.clamp(data.currentHP, 0, newMaxHP)
	end

	data.currentStats.Speed = math.max(8, base.Speed + (bonus.Speed or 0))
	data.currentStats.DamageMultiplier = math.max(0.1, base.DamageMultiplier + (bonus.DamageMultiplier or 0))
	data.currentStats.FireRateMultiplier = math.max(0.1, base.FireRateMultiplier + (bonus.FireRateMultiplier or 0))
	data.currentStats.Armor = math.max(0, base.Armor + (bonus.Armor or 0))
	data.currentStats.CriticalChance = math.clamp(base.CriticalChance + (bonus.CriticalChance or 0), 0, 100)
	data.currentStats.PickupRadius = math.max(5, base.PickupRadius + (bonus.PickupRadius or 0))
	data.currentStats.LifeSteal = math.clamp(base.LifeSteal + (bonus.LifeSteal or 0), 0, 0.8)
	data.currentStats.BurnDamage = math.max(1, base.BurnDamage + (bonus.BurnDamage or 0))
	data.currentStats.RangeMultiplier = math.max(0.5, base.RangeMultiplier + (bonus.RangeMultiplier or 0))

	-- Update Roblox character humanoid walk speed
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = data.currentStats.Speed
		end
	end

	PlayerStatsManager.SyncToClient(player)
end

function PlayerStatsManager.AddStat(player: Player, statType: StatTypes.StatType, amount: number)
	local data = playerDataMap[player]
	if not data then return end

	data.statBonuses[statType] = (data.statBonuses[statType] or 0) + amount
	data.statCardLevels[statType] = (data.statCardLevels[statType] or 0) + 1
	PlayerStatsManager.RecalculateStats(player)
	GameEvents.OnGainStat:Fire(player, statType, amount)
end

function PlayerStatsManager.GetStatCardLevels(player: Player): { [string]: number }
	local data = playerDataMap[player]
	if not data then return {} end
	return data.statCardLevels
end

function PlayerStatsManager.SetLevelUpPhase(player: Player, active: boolean)
	local data = playerDataMap[player]
	if not data then return end
	data.isLevelUpPhase = active

	local char = player.Character
	if char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Transparency = if active then 0.55 else 0
			end
		end

		local highlight = char:FindFirstChild("LevelUpPhaseAura") :: Highlight?
		if active then
			if not highlight then
				highlight = Instance.new("Highlight")
				highlight.Name = "LevelUpPhaseAura"
				highlight.FillColor = Color3.fromRGB(0, 230, 255)
				highlight.FillTransparency = 0.65
				highlight.OutlineColor = Color3.fromRGB(0, 255, 255)
				highlight.OutlineTransparency = 0.2
				highlight.Parent = char
			end
		else
			if highlight then
				highlight:Destroy()
			end
		end
	end
end

function PlayerStatsManager.TakeDamage(player: Player, rawDamage: number, attacker: any?): number
	local data = playerDataMap[player]
	if not data or data.isDead or data.isLevelUpPhase then return 0 end

	local actualDamage = StatTypes.CalculateDamageAfterArmor(rawDamage, data.currentStats.Armor)
	data.currentHP = math.max(0, data.currentHP - actualDamage)

	GameEvents.OnDamageTaken:Fire(player, actualDamage, attacker)
	PlayerStatsManager.ChargeOverdrive(player, actualDamage * 0.4)

	local floatingEvent = Remotes.GetEvent("FloatingText")
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		local pos = (character:FindFirstChild("HumanoidRootPart") :: BasePart).Position + Vector3.new(0, 3, 0)
		floatingEvent:FireAllClients(pos, string.format("-%.0f", actualDamage), Color3.fromRGB(255, 60, 60), false)
	end

	if data.currentHP <= 0 then
		data.isDead = true
		local char = player.Character
		if char then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
		end
	end

	PlayerStatsManager.SyncToClient(player)
	return actualDamage
end

function PlayerStatsManager.Heal(player: Player, amount: number)
	local data = playerDataMap[player]
	if not data or data.isDead then return end

	local healed = math.min(data.maxHP - data.currentHP, amount)
	if healed <= 0 then return end

	data.currentHP += healed
	GameEvents.OnHeal:Fire(player, healed)

	local floatingEvent = Remotes.GetEvent("FloatingText")
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		local pos = (character:FindFirstChild("HumanoidRootPart") :: BasePart).Position + Vector3.new(0, 3.5, 0)
		floatingEvent:FireAllClients(pos, string.format("+%.0f", healed), Color3.fromRGB(80, 255, 80), false)
	end

	PlayerStatsManager.SyncToClient(player)
end

function PlayerStatsManager.ChargeOverdrive(player: Player, amount: number)
	local data = playerDataMap[player]
	if not data or data.isOverdriveActive then return end

	data.currentOverdrive = math.clamp(data.currentOverdrive + amount, 0, data.maxOverdrive)
	PlayerStatsManager.SyncToClient(player)
end

function PlayerStatsManager.TryActivateOverdrive(player: Player): boolean
	local data = playerDataMap[player]
	if not data or data.isDead or data.isOverdriveActive then return false end
	if data.currentOverdrive < data.maxOverdrive then return false end

	data.isOverdriveActive = true
	data.currentOverdrive = 0
	data.overdriveEndTime = os.clock() + data.overdriveDuration

	GameEvents.OnOverdriveTriggered:Fire(player)
	Remotes.GetEvent("VFXEvent"):FireAllClients("OverdriveStart", player)

	task.delay(data.overdriveDuration, function()
		if data.isOverdriveActive then
			data.isOverdriveActive = false
			Remotes.GetEvent("VFXEvent"):FireAllClients("OverdriveEnd", player)
			PlayerStatsManager.SyncToClient(player)
		end
	end)

	PlayerStatsManager.SyncToClient(player)
	return true
end

function PlayerStatsManager.GetWeaponScalingMultiplier(player: Player, scalingStat: string?, scalingRatio: number?): number
	if not scalingStat or scalingStat == "None" or not scalingRatio or scalingRatio <= 0 then
		return 1.0
	end
	local data = playerDataMap[player]
	if not data then return 1.0 end

	local current = data.currentStats
	local base = data.baseStats
	local statLevel = 0

	if scalingStat == "MaxHP" then
		statLevel = current.MaxHP / 20
	elseif scalingStat == "Speed" then
		statLevel = math.max(0, current.Speed - base.Speed) / 1
	elseif scalingStat == "DamageMultiplier" then
		statLevel = math.max(0, current.DamageMultiplier - 1.0) / 0.02
	elseif scalingStat == "FireRateMultiplier" then
		statLevel = math.max(0, current.FireRateMultiplier - 1.0) / 0.05
	elseif scalingStat == "Armor" then
		statLevel = current.Armor / 10
	elseif scalingStat == "CriticalChance" then
		statLevel = current.CriticalChance / 1
	elseif scalingStat == "PickupRadius" then
		statLevel = math.max(0, current.PickupRadius - base.PickupRadius) / 1
	elseif scalingStat == "LifeSteal" then
		statLevel = current.LifeSteal / 0.01
	elseif scalingStat == "BurnDamage" then
		statLevel = math.max(0, current.BurnDamage) / 1
	end

	if statLevel < 0 then statLevel = 0 end
	return 1.0 + (statLevel * scalingRatio)
end

function PlayerStatsManager.SyncToClient(player: Player)
	local data = playerDataMap[player]
	if not data then return end

	local remote = Remotes.GetEvent("StateSync")
	remote:FireClient(player, {
		currentHP = data.currentHP,
		maxHP = data.maxHP,
		currentOverdrive = data.currentOverdrive,
		maxOverdrive = data.maxOverdrive,
		isOverdriveActive = data.isOverdriveActive,
		isDead = data.isDead,
		stats = data.currentStats,
		statCardLevels = data.statCardLevels,
	})
end

function PlayerStatsManager.ExportState(player: Player): any?
	local data = playerDataMap[player]
	if not data then return nil end

	local bonusesCopy: { [string]: number } = {}
	for k, v in pairs(data.statBonuses) do
		bonusesCopy[k] = v
	end

	local cardLevelsCopy: { [string]: number } = {}
	for k, v in pairs(data.statCardLevels) do
		cardLevelsCopy[k] = v
	end

	return {
		currentHP = data.currentHP,
		maxHP = data.maxHP,
		currentOverdrive = data.currentOverdrive,
		statBonuses = bonusesCopy,
		statCardLevels = cardLevelsCopy,
	}
end

function PlayerStatsManager.ImportState(player: Player, saved: any)
	if type(saved) ~= "table" then return end
	local data = playerDataMap[player] or PlayerStatsManager.InitPlayer(player)

	if type(saved.statBonuses) == "table" then
		for k, v in pairs(saved.statBonuses) do
			if type(k) == "string" and type(v) == "number" then
				(data.statBonuses :: any)[k] = v
			end
		end
	end

	if type(saved.statCardLevels) == "table" then
		data.statCardLevels = {}
		for k, v in pairs(saved.statCardLevels) do
			if type(k) == "string" and type(v) == "number" then
				data.statCardLevels[k] = math.floor(v)
			end
		end
	end

	data.currentOverdrive = math.clamp(tonumber(saved.currentOverdrive) or 0, 0, data.maxOverdrive)
	data.isDead = false
	data.isLevelUpPhase = false

	PlayerStatsManager.RecalculateStats(player)

	if type(saved.currentHP) == "number" and saved.currentHP > 0 then
		data.currentHP = math.clamp(saved.currentHP, 1, data.maxHP)
	else
		data.currentHP = data.maxHP
	end

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.MaxHealth = data.maxHP
			humanoid.Health = data.currentHP
			humanoid.WalkSpeed = data.currentStats.Speed
		end
	end

	PlayerStatsManager.SyncToClient(player)
end

function PlayerStatsManager.Cleanup(player: Player)
	playerDataMap[player] = nil
end

Players.PlayerRemoving:Connect(PlayerStatsManager.Cleanup)

-- Listen to Remote TriggerOverdrive
local triggerOverdriveRemote = Remotes.GetEvent("TriggerOverdrive")
triggerOverdriveRemote.OnServerEvent:Connect(function(player)
	PlayerStatsManager.TryActivateOverdrive(player)
end)

return PlayerStatsManager
