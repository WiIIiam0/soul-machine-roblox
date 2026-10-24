--!strict
-- Remotes.luau: Network remotes container and helper accessor

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "GameRemotes"

local REMOTE_EVENT_NAMES = {
	"StateSync",             -- Server -> Client: HP, Overdrive, Level, XP, Wave, Inventory
	"LevelUpOptions",        -- Server -> Client: 3 reward choices
	"SelectLevelUpChoice",   -- Client -> Server: index of chosen card
	"TriggerOverdrive",      -- Client -> Server: player activated Overdrive
	"FloatingText",          -- Server -> Client: 3D damage / crit / burn text
	"VFXEvent",              -- Server -> Client: explosions, muzzle flashes, beams
	"MetaSync",              -- Server -> Client: GlobalLevel, GlobalXP, XPToNextLevel, WeaponSlots, PassiveSlots, UnlockedWeapons, UnlockedPassives
	"GlobalLevelUp",         -- Server -> Client: new global level, unlock notification
	"RestartRun",            -- Client -> Server: restart after game over
}

local Remotes = {}

local function getOrCreateFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder?
	if not folder then
		if RunService:IsServer() then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		else
			folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 10) :: Folder?
			if not folder then
				error("GameRemotes folder not found in ReplicatedStorage!")
			end
		end
	end
	return folder
end

function Remotes.Init()
	local folder = getOrCreateFolder()
	if RunService:IsServer() then
		for _, name in ipairs(REMOTE_EVENT_NAMES) do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end
	end
end

function Remotes.GetEvent(name: string): RemoteEvent
	local folder = getOrCreateFolder()
	local remote = folder:FindFirstChild(name) :: RemoteEvent?
	if not remote then
		if RunService:IsServer() then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		else
			remote = folder:WaitForChild(name, 10) :: RemoteEvent
		end
	end
	return remote
end

return Remotes
