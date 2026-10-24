--!strict
-- ClientAudio.client.luau: Faithful Cyberpunk Jukebox & SFX Manager mirroring TheSwarm AudioManager.cs

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

-- Sound Groups for professional mixing
local soundGroupFolder = SoundService:FindFirstChild("SoulMachineAudio")
if not soundGroupFolder then
	soundGroupFolder = Instance.new("Folder")
	soundGroupFolder.Name = "SoulMachineAudio"
	soundGroupFolder.Parent = SoundService
end

local sfxGroup = soundGroupFolder:FindFirstChild("SFX") :: SoundGroup?
if not sfxGroup then
	sfxGroup = Instance.new("SoundGroup")
	sfxGroup.Name = "SFX"
	sfxGroup.Volume = 0.8
	sfxGroup.Parent = soundGroupFolder
end

local musicGroup = soundGroupFolder:FindFirstChild("Music") :: SoundGroup?
if not musicGroup then
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "Music"
	musicGroup.Volume = 0.35
	musicGroup.Parent = soundGroupFolder
end

-- Sound asset cache with verified classic Roblox SFX
local SOUND_PRESETS: { [string]: string } = {
	LaserShoot = "rbxassetid://130113322",   -- Official classic Roblox laser fire
	HeavyShoot = "rbxassetid://130113322",
	Explosion = "rbxassetid://12222084",     -- Official classic Roblox explosion
	PlayerHit = "rbxassetid://12222216",     -- Official classic hit sound
	BurnTransfer = "rbxassetid://130113322",
	LevelUp = "rbxassetid://130788893",      -- Official chime
	GlobalLevelUp = "rbxassetid://130788893",
	OverdriveStart = "rbxassetid://130788893",
	OverdriveEnd = "rbxassetid://12222084",
	PassiveProc = "rbxassetid://12221967",
	CardSelect = "rbxassetid://12221967",
	MusicTrack = "",                         -- Left empty until uploaded to prevent format error
}

local blacklistedSoundIds: { [string]: boolean } = {}

local function findCustomSound(soundName: string): string?
	local customFolder = ReplicatedStorage:FindFirstChild("Audio") or ReplicatedStorage:FindFirstChild("Sounds")
	if customFolder then
		local found = customFolder:FindFirstChild(soundName)
		if found and found:IsA("Sound") and found.SoundId ~= "" then
			return found.SoundId
		end
	end
	return nil
end

local lastShotSoundTime = 0

local function playSFX(presetKey: string, customName: string?, volumeMultiplier: number?, pitch: number?)
	local soundId = (customName and findCustomSound(customName)) or SOUND_PRESETS[presetKey]
	if not soundId or soundId == "" or blacklistedSoundIds[soundId] then return end

	local sound = Instance.new("Sound")
	sound.Name = "SFX_" .. presetKey
	sound.SoundId = soundId
	sound.Volume = (volumeMultiplier or 1.0)
	sound.PlaybackSpeed = pitch or (0.95 + math.random() * 0.1)
	sound.SoundGroup = sfxGroup
	sound.Parent = SoundService

	local ok = pcall(function()
		sound:Play()
	end)

	if not ok then
		blacklistedSoundIds[soundId] = true
		sound:Destroy()
		return
	end

	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 5)
end

-- --- 1. WEAPON SHOOTING SFX ---
local projectilesFolder = Workspace:WaitForChild("GameProjectiles", 10)
if projectilesFolder then
	projectilesFolder.ChildAdded:Connect(function(child)
		if child:IsA("Part") then
			local now = os.clock()
			-- Throttle SFX slightly to prevent audio blowout during rapid bursts
			if now - lastShotSoundTime > 0.05 then
				lastShotSoundTime = now
				playSFX("LaserShoot", "laserSmall_000", 0.55, 0.95 + math.random() * 0.15)
			end
		end
	end)
end

-- --- 2. COMBAT & VFX EVENTS SFX ---
local vfxEvent = Remotes.GetEvent("VFXEvent")
vfxEvent.OnClientEvent:Connect(function(eventType: string, ...: any)
	if eventType == "Explosion" or eventType == "EnemyDeath" then
		playSFX("Explosion", "explosionCrunch_000", 0.85, 0.9 + math.random() * 0.2)
	elseif eventType == "BurnTransfer" then
		playSFX("BurnTransfer", "laserRetro_000", 0.7, 1.2)
	elseif eventType == "OverdriveStart" then
		playSFX("OverdriveStart", "forceField_000", 1.0, 1.0)
	elseif eventType == "OverdriveEnd" then
		playSFX("OverdriveEnd", "forceField_002", 0.8, 0.9)
	elseif eventType == "PassiveTrigger" then
		playSFX("PassiveProc", "computerNoise_000", 0.6, 1.1)
	end
end)

-- --- 3. STATE SYNC (PLAYER HURT, LEVEL UP, GAME OVER) ---
local lastHealth: number? = nil

Remotes.GetEvent("StateSync").OnClientEvent:Connect(function(data: any)
	if data.currentHP and data.maxHP then
		if lastHealth ~= nil and data.currentHP < lastHealth then
			playSFX("PlayerHit", "impactMetal_000", 0.9, 0.95 + math.random() * 0.1)
		end
		lastHealth = data.currentHP
	end
end)

-- Level-up card screen audio
Remotes.GetEvent("LevelUpOptions").OnClientEvent:Connect(function()
	playSFX("LevelUp", "computerNoise_002", 0.9, 1.0)
end)

-- Global Level-up Fanfare
Remotes.GetEvent("GlobalLevelUp").OnClientEvent:Connect(function()
	playSFX("GlobalLevelUp", "game_track_2", 1.0, 1.0)
end)

-- Card Choice Click SFX
Remotes.GetEvent("SelectLevelUpChoice").OnClientEvent:Connect(function()
	playSFX("CardSelect", "computerNoise_001", 0.7, 1.1)
end)

-- --- 4. CYBERPUNK BACKGROUND COMBAT MUSIC (JUKEBOX) ---
local customMusic = findCustomSound("game_track_1") or findCustomSound("menu_new")
if customMusic and customMusic ~= "" then
	local bgMusic = Instance.new("Sound")
	bgMusic.Name = "CyberpunkCombatMusic"
	bgMusic.SoundId = customMusic
	bgMusic.Looped = true
	bgMusic.Volume = 0.30
	bgMusic.SoundGroup = musicGroup
	bgMusic.Parent = SoundService

	task.spawn(function()
		task.wait(1.5)
		pcall(function()
			bgMusic:Play()
		end)
	end)
end
