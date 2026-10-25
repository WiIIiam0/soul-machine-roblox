--!strict
-- ClientAudio.client.luau: Faithful Cyberpunk Jukebox & Anti-Clipping SFX Manager mirroring TheSwarm AudioManager.cs

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

-- Sound Groups for professional mixing & anti-clipping
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
	sfxGroup.Volume = 0.5
	sfxGroup.Parent = soundGroupFolder

	-- Built-in Compressor to completely prevent harsh audio crackling / clipping distortion
	local compressor = Instance.new("CompressorSoundEffect")
	compressor.Threshold = -8
	compressor.Ratio = 4
	compressor.Attack = 0.01
	compressor.Release = 0.1
	compressor.Parent = sfxGroup
end

local musicGroup = soundGroupFolder:FindFirstChild("Music") :: SoundGroup?
if not musicGroup then
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "Music"
	musicGroup.Volume = 0.25
	musicGroup.Parent = soundGroupFolder
end

-- Sound asset cache (aucun vieux son Roblox 2007 d'explosion/impact/mort forcé)
local SOUND_PRESETS: { [string]: string } = {
	LaserShoot = "rbxassetid://130113322",
	HeavyShoot = "rbxassetid://130113322",
	Explosion = "",
	PlayerHit = "",
	BurnTransfer = "",
	LevelUp = "rbxassetid://130788893",
	GlobalLevelUp = "rbxassetid://130788893",
	OverdriveStart = "rbxassetid://130788893",
	OverdriveEnd = "",
	PassiveProc = "",
	CardSelect = "rbxassetid://12221967",
	MusicTrack = "",
}

local blacklistedSoundIds: { [string]: boolean } = {}
local activeSoundCount = 0
local MAX_CONCURRENT_SFX = 6

-- Sound rate-limiters (in seconds) to prevent loud buzzing from sound pile-up
local soundDebounces: { [string]: number } = {}
local DEBOUNCE_WINDOWS: { [string]: number } = {
	LaserShoot = 0.08,
	Explosion = 0.12,
	BurnTransfer = 0.15,
	PassiveProc = 0.15,
	PlayerHit = 0.15,
}

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

local function playSFX(presetKey: string, customName: string?, volumeMultiplier: number?, pitch: number?)
	local now = os.clock()
	local minInterval = DEBOUNCE_WINDOWS[presetKey]
	if minInterval then
		local lastTime = soundDebounces[presetKey] or 0
		if (now - lastTime) < minInterval then
			return -- Drop excess sound to prevent audio buzzing/distortion
		end
		soundDebounces[presetKey] = now
	end

	if activeSoundCount >= MAX_CONCURRENT_SFX then
		return
	end

	local soundId = (customName and findCustomSound(customName)) or SOUND_PRESETS[presetKey]
	if not soundId or soundId == "" or blacklistedSoundIds[soundId] then return end

	local sound = Instance.new("Sound")
	sound.Name = "SFX_" .. presetKey
	sound.SoundId = soundId
	sound.Volume = (volumeMultiplier or 0.35)
	sound.PlaybackSpeed = pitch or (0.95 + math.random() * 0.1)
	sound.SoundGroup = sfxGroup
	sound.Parent = SoundService

	activeSoundCount += 1

	local ok = pcall(function()
		sound:Play()
	end)

	if not ok then
		activeSoundCount = math.max(0, activeSoundCount - 1)
		blacklistedSoundIds[soundId] = true
		sound:Destroy()
		return
	end

	local cleaned = false
	local function cleanup()
		if cleaned then return end
		cleaned = true
		activeSoundCount = math.max(0, activeSoundCount - 1)
		sound:Destroy()
	end

	sound.Ended:Connect(cleanup)
	Debris:AddItem(sound, 3)
end

-- --- 1. WEAPON SHOOTING SFX ---
local projectilesFolder = Workspace:WaitForChild("GameProjectiles", 10)
if projectilesFolder then
	projectilesFolder.ChildAdded:Connect(function(child)
		if child:IsA("Part") then
			playSFX("LaserShoot", "laserSmall_000", 0.22, 0.95 + math.random() * 0.15)
		end
	end)
end

-- --- 2. COMBAT & VFX EVENTS SFX ---
-- En accord avec Unity TheSwarm (EnemyHealth.cs), la mort d'un ennemi ("EnemyDeath") ne joue AUCUN bruitage.
local vfxEvent = Remotes.GetEvent("VFXEvent")
vfxEvent.OnClientEvent:Connect(function(eventType: string, ...: any)
	if eventType == "Explosion" then
		playSFX("Explosion", "explosionCrunch_000", 0.30, 0.9 + math.random() * 0.2)
	elseif eventType == "BurnTransfer" then
		playSFX("BurnTransfer", "laserRetro_000", 0.28, 1.2)
	elseif eventType == "OverdriveStart" then
		playSFX("OverdriveStart", "forceField_000", 0.60, 1.0)
	elseif eventType == "OverdriveEnd" then
		playSFX("OverdriveEnd", "forceField_002", 0.40, 0.9)
	elseif eventType == "PassiveTrigger" then
		playSFX("PassiveProc", "computerNoise_000", 0.25, 1.1)
	elseif eventType == "LaserTracer" then
		playSFX("LaserShoot", "laserSmall_000", 0.20, 0.95 + math.random() * 0.15)
	end
end)

-- --- 3. STATE SYNC (LEVEL UP, GAME OVER) ---
-- (Note: En accord avec Unity PlayerManager.cs, aucun bruitage de dégâts répétitif n'est joué sur chaque coup)
Remotes.GetEvent("StateSync").OnClientEvent:Connect(function(_data: any)
end)

-- Level-up card screen audio
Remotes.GetEvent("LevelUpOptions").OnClientEvent:Connect(function()
	playSFX("LevelUp", "computerNoise_002", 0.50, 1.0)
end)

-- Global Level-up Fanfare
Remotes.GetEvent("GlobalLevelUp").OnClientEvent:Connect(function()
	playSFX("GlobalLevelUp", "game_track_2", 0.60, 1.0)
end)

-- Card Choice Click SFX
Remotes.GetEvent("SelectLevelUpChoice").OnClientEvent:Connect(function()
	playSFX("CardSelect", "computerNoise_001", 0.35, 1.1)
end)

-- --- 4. CYBERPUNK BACKGROUND COMBAT MUSIC (JUKEBOX) ---
local customMusic = findCustomSound("game_track_1") or findCustomSound("menu_new")
if customMusic and customMusic ~= "" then
	local bgMusic = Instance.new("Sound")
	bgMusic.Name = "CyberpunkCombatMusic"
	bgMusic.SoundId = customMusic
	bgMusic.Looped = true
	bgMusic.Volume = 0.22
	bgMusic.SoundGroup = musicGroup
	bgMusic.Parent = SoundService

	task.spawn(function()
		task.wait(1.5)
		pcall(function()
			bgMusic:Play()
		end)
	end)
end
