--!strict
-- ClientHUD.client.luau: Main HUD orchestrator (Overhead Vitals, Flush Bottom Global XP Bar, Bottom Inventory, Level-Up & Overlays)

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local UIFolder = script.Parent:WaitForChild("UI")
local OverheadVitals = require(UIFolder:WaitForChild("OverheadVitals"))
local InventoryView = require(UIFolder:WaitForChild("InventoryView"))
local LevelUpView = require(UIFolder:WaitForChild("LevelUpView"))
local HudOverlays = require(UIFolder:WaitForChild("HudOverlays"))

-- 1. Floating gauges above the character's head (HP, In-Run XP, Overdrive) — no duplicated on-screen gauges
OverheadVitals.BindPlayer(player)

-- 2. Root ScreenGuis (IgnoreGuiInset = true so bottom-edge elements sit flush at Y = 100%, with zero global UIScale distortion)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SoulMachineHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

local vfxGui = Instance.new("ScreenGui")
vfxGui.Name = "SoulMachineVFX"
vfxGui.ResetOnSpawn = false
vfxGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
vfxGui.IgnoreGuiInset = true
vfxGui.DisplayOrder = 25
vfxGui.Parent = playerGui

-- 3. Modern Cyber Pill Zone Indicator (Collision-free centered header)
local topInfoContainer = Instance.new("Frame")
topInfoContainer.Name = "TopInfoContainer"
topInfoContainer.Size = UDim2.new(0, 130, 0, 26)
topInfoContainer.AnchorPoint = Vector2.new(0.5, 0)
topInfoContainer.Position = UDim2.new(0.5, 0, 0, 48)
topInfoContainer.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
topInfoContainer.BackgroundTransparency = 0.45
topInfoContainer.BorderSizePixel = 0
topInfoContainer.ZIndex = 10
topInfoContainer.Parent = screenGui

local topInfoScale = Instance.new("UIScale")
topInfoScale.Name = "TopInfoScale"
topInfoScale.Parent = topInfoContainer

local topInfoCorner = Instance.new("UICorner")
topInfoCorner.CornerRadius = UDim.new(0, 13)
topInfoCorner.Parent = topInfoContainer

local topInfoStroke = Instance.new("UIStroke")
topInfoStroke.Color = Color3.fromRGB(0, 180, 240)
topInfoStroke.Thickness = 1.0
topInfoStroke.Transparency = 0.50
topInfoStroke.Parent = topInfoContainer

local topInfoLabel = Instance.new("TextLabel")
topInfoLabel.Name = "TopInfoLabel"
topInfoLabel.Size = UDim2.new(1, 0, 1, 0)
topInfoLabel.Position = UDim2.new(0, 0, 0, 0)
topInfoLabel.BackgroundTransparency = 1
topInfoLabel.TextColor3 = Color3.fromRGB(240, 250, 255)
topInfoLabel.Font = Enum.Font.GothamBlack
topInfoLabel.TextSize = 13
topInfoLabel.TextWrapped = false
topInfoLabel.TextXAlignment = Enum.TextXAlignment.Center
topInfoLabel.TextYAlignment = Enum.TextYAlignment.Center
topInfoLabel.Text = "ZONE 1"
topInfoLabel.Parent = topInfoContainer

-- 4. Global (Persistent / ADN) XP Bar Flush at the Very Bottom Edge (No Canvas / Card Frame)
local META_BAR_HEIGHT = 12

local metaXPBar = Instance.new("Frame")
metaXPBar.Name = "MetaXPBar"
metaXPBar.AnchorPoint = Vector2.new(0, 1)
metaXPBar.Position = UDim2.new(0, 0, 1, 0)
metaXPBar.Size = UDim2.new(1, 0, 0, META_BAR_HEIGHT)
metaXPBar.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
metaXPBar.BackgroundTransparency = 0.08
metaXPBar.BorderSizePixel = 0
metaXPBar.ZIndex = 15
metaXPBar.Parent = screenGui

local metaXPTopLine = Instance.new("Frame")
metaXPTopLine.Name = "TopBorderLine"
metaXPTopLine.Size = UDim2.new(1, 0, 0, 1)
metaXPTopLine.Position = UDim2.new(0, 0, 0, 0)
metaXPTopLine.BackgroundColor3 = Color3.fromRGB(255, 190, 35)
metaXPTopLine.BackgroundTransparency = 0.45
metaXPTopLine.BorderSizePixel = 0
metaXPTopLine.ZIndex = 18
metaXPTopLine.Parent = metaXPBar

local metaXPBarFill = Instance.new("Frame")
metaXPBarFill.Name = "Fill"
metaXPBarFill.Size = UDim2.new(0, 0, 1, 0)
metaXPBarFill.Position = UDim2.new(0, 0, 0, 0)
metaXPBarFill.BackgroundColor3 = Color3.fromRGB(255, 180, 20)
metaXPBarFill.BorderSizePixel = 0
metaXPBarFill.ZIndex = 16
metaXPBarFill.Parent = metaXPBar

local metaXPNotches = Instance.new("Frame")
metaXPNotches.Name = "Notches"
metaXPNotches.Size = UDim2.new(1, 0, 1, 0)
metaXPNotches.BackgroundTransparency = 1
metaXPNotches.ZIndex = 17
metaXPNotches.Parent = metaXPBar

local metaXPInlineLabel = Instance.new("TextLabel")
metaXPInlineLabel.Name = "InlineLabel"
metaXPInlineLabel.Size = UDim2.new(1, -16, 1, 0)
metaXPInlineLabel.Position = UDim2.new(0, 8, 0, 0)
metaXPInlineLabel.BackgroundTransparency = 1
metaXPInlineLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
metaXPInlineLabel.TextTransparency = 0.15
metaXPInlineLabel.Font = Enum.Font.GothamBold
metaXPInlineLabel.TextSize = 9
metaXPInlineLabel.TextWrapped = false
metaXPInlineLabel.TextXAlignment = Enum.TextXAlignment.Center
metaXPInlineLabel.Text = "ADN : 0 / 522"
metaXPInlineLabel.ZIndex = 19
metaXPInlineLabel.Parent = metaXPBar

local lastMetaNotchCount = -1
local function updateMetaNotches(maxXP: number)
	local count = math.clamp(math.floor(maxXP / 10), 0, 60)
	if count == lastMetaNotchCount then return end
	lastMetaNotchCount = count
	metaXPNotches:ClearAllChildren()
	for i = 1, count - 1 do
		local tick = Instance.new("Frame")
		tick.Size = UDim2.new(0, 1, 1, 0)
		tick.Position = UDim2.new(i / count, 0, 0, 0)
		tick.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		tick.BackgroundTransparency = 0.45
		tick.BorderSizePixel = 0
		tick.Parent = metaXPNotches
	end
end

updateMetaNotches(522)

-- 5. Sub-Controllers (Bottom Inventory, Level-Up Modal, Overlays)
local inventoryController = InventoryView.Create(screenGui, META_BAR_HEIGHT + 8)

local levelUpController = LevelUpView.Create(screenGui, function(choiceIndex: number)
	Remotes.GetEvent("SelectLevelUpChoice"):FireServer(choiceIndex)
end)

local overlays = HudOverlays.Create(screenGui, vfxGui, function()
	Remotes.GetEvent("RestartRun"):FireServer()
end)

Remotes.GetEvent("LevelUpOptions").OnClientEvent:Connect(function(cards: { any })
	levelUpController.Open(cards)
end)

-- 6. Monotonic Responsive Viewport Binder
-- 6. Monotonic Responsive Viewport Binder with Dynamic Topbar Collision Avoidance
local function applyResponsiveLayout()
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	if vp.X <= 0 or vp.Y <= 0 then return end

	local topInset = GuiService:GetGuiInset().Y
	local baseScale = math.clamp(math.min(vp.X / 1366, vp.Y / 768), 0.74, 1.12)

	-- Dynamic collision-free positioning avoiding Roblox top-left core buttons (Fixed ~140px width)
	local CORE_BUTTONS_RIGHT = 140
	local screenWidth = vp.X
	local badgeBaseWidth = 130
	local badgeScale = math.clamp(baseScale, 0.75, 1.05)
	local effectiveWidth = badgeBaseWidth * badgeScale
	local idealCenterX = screenWidth * 0.5
	local badgeLeftEdge = idealCenterX - (effectiveWidth * 0.5)
	local safeLimit = CORE_BUTTONS_RIGHT + 12

	if badgeLeftEdge >= safeLimit then
		-- No collision: perfectly centered horizontally across screen
		topInfoContainer.AnchorPoint = Vector2.new(0.5, 0)
		topInfoContainer.Position = UDim2.new(0.5, 0, 0, topInset + 8)
	else
		-- Collision detected on narrow screens: center dynamically between the core buttons and right edge of screen
		local availableSpace = screenWidth - CORE_BUTTONS_RIGHT
		local shiftedCenterX = CORE_BUTTONS_RIGHT + (availableSpace * 0.5)
		topInfoContainer.AnchorPoint = Vector2.new(0.5, 0)
		topInfoContainer.Position = UDim2.new(0, math.floor(shiftedCenterX), 0, topInset + 8)
	end

	topInfoScale.Scale = badgeScale

	inventoryController.ApplyViewport(vp, baseScale)
	overlays.ApplyViewport(vp, baseScale)
	levelUpController.ApplyViewport(vp, topInset)
end

local function bindCameraViewport(cam: Camera?)
	if not cam then return end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
	applyResponsiveLayout()
end

bindCameraViewport(Workspace.CurrentCamera)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindCameraViewport(Workspace.CurrentCamera)
end)

-- 7. Portal & Network State Synchronization
local cachedTotalXP = 0
local cachedMaxTimelineXP = 522
local cachedMaxWeaponSlots = 1
local cachedMaxPassiveSlots = 1
local cachedMaxStatSlots = 1
local cachedMaxWeaponRank = 1
local cachedMaxStatRank = 3

local currentZoneId = tonumber(Workspace:GetAttribute("ZoneId")) or 1
local currentZoneName = tostring(Workspace:GetAttribute("ZoneName") or "ZONE 1")
local currentRunLevel = 1
local currentSurvivingWave = 1
local currentWaveState = "SPAWNING"
local currentWaveTimer = 35
local prevHP: number? = nil

local function refreshTopInfoText()
	if currentWaveState == "BOSS" then
		topInfoStroke.Color = Color3.fromRGB(255, 75, 85)
		topInfoLabel.TextColor3 = Color3.fromRGB(255, 85, 95)
		topInfoLabel.Text = string.format("ZONE %d  •  ⚠ BOSS", currentZoneId)
	else
		topInfoStroke.Color = Color3.fromRGB(0, 180, 240)
		topInfoLabel.TextColor3 = Color3.fromRGB(240, 250, 255)
		topInfoLabel.Text = string.format("ZONE %d", currentZoneId)
	end
end

local function refreshLocalPortalVisuals()
	local arena = Workspace:FindFirstChild("MechaArena")
	if not arena then return end
	local portalModel = arena:FindFirstChild("ZonePortalModel")
	if not portalModel then return end

	local reqLevel = tonumber(Workspace:GetAttribute("NextZoneRequiredLevel")) or 0
	if reqLevel <= 0 then return end

	local unlocked = currentRunLevel >= reqLevel
	local statusColor = if unlocked then Color3.fromRGB(40, 255, 145) else Color3.fromRGB(255, 75, 55)

	local core = portalModel:FindFirstChild("ZonePortalCore") :: BasePart?
	if core then
		core.Color = statusColor
	end
	local beam = portalModel:FindFirstChild("ZonePortalBeam") :: BasePart?
	if beam then
		beam.Color = statusColor
		beam.Transparency = if unlocked then 0.58 else 0.80
	end

	local anchor = portalModel:FindFirstChild("PortalLabelAnchor")
	local bb = if anchor then anchor:FindFirstChild("PortalBillboard") else nil
	local bg = if bb then bb:FindFirstChild("BG") else nil
	local reqLbl = if bg then bg:FindFirstChild("ReqLabel") :: TextLabel? else nil
	if reqLbl then
		reqLbl.TextColor3 = statusColor
		if unlocked then
			reqLbl.Text = "⚡ DÉVERROUILLÉ — MARCHEZ SUR LE TÉLÉPORTEUR !"
		else
			reqLbl.Text = string.format("VERROUILLÉ — NIVEAU %d REQUIS (ACTUEL : %d/%d)", reqLevel, currentRunLevel, reqLevel)
		end
	end
end

Workspace:GetAttributeChangedSignal("ZoneId"):Connect(function()
	currentZoneId = tonumber(Workspace:GetAttribute("ZoneId")) or 1
	currentZoneName = tostring(Workspace:GetAttribute("ZoneName") or ("ZONE " .. currentZoneId))
	refreshTopInfoText()
	task.defer(refreshLocalPortalVisuals)
end)

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "MechaArena" then
		task.delay(0.15, refreshLocalPortalVisuals)
	end
end)
task.defer(refreshLocalPortalVisuals)

Remotes.GetEvent("GlobalLevelUp").OnClientEvent:Connect(function(data: any)
	if not data then return end
	local unlocked = data.newlyUnlocked
	if type(unlocked) == "table" and #unlocked > 0 then
		local latest = unlocked[#unlocked]
		local titleText = string.format("★ NOUVEAU PALIER ADN (%d XP) ★", tonumber(data.totalXP) or cachedTotalXP)
		local descText = tostring(latest.description or latest.unlockName or "Nouveau déblocage permanent !")
		overlays.PresentBanner(titleText, descText, 5.0)
	else
		local info = data.unlockInfo
		local titleText = string.format("★ NIVEAU GLOBAL %d ★", tonumber(data.newLevel) or 1)
		local descText = (info and info.description) or "+1 Palier permanent débloqué !"
		overlays.PresentBanner(titleText, descText, 5.0)
	end
end)

Remotes.GetEvent("MetaSync").OnClientEvent:Connect(function(data: any)
	if not data then return end

	if data.totalXP ~= nil then cachedTotalXP = data.totalXP end
	if data.maxTimelineXP ~= nil then cachedMaxTimelineXP = math.max(1, data.maxTimelineXP) end
	if data.weaponSlots ~= nil then cachedMaxWeaponSlots = data.weaponSlots end
	if data.passiveSlots ~= nil then cachedMaxPassiveSlots = data.passiveSlots end
	if data.statSlots ~= nil then cachedMaxStatSlots = data.statSlots end
	if data.maxWeaponRank ~= nil then cachedMaxWeaponRank = data.maxWeaponRank end
	if data.maxStatRank ~= nil then cachedMaxStatRank = data.maxStatRank end

	local ratio = math.clamp(cachedTotalXP / cachedMaxTimelineXP, 0, 1)
	TweenService:Create(metaXPBarFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(ratio, 0, 1, 0),
	}):Play()
	metaXPInlineLabel.Text = string.format("ADN : %d / %d", cachedTotalXP, cachedMaxTimelineXP)
	updateMetaNotches(cachedMaxTimelineXP)

	inventoryController.SetCaps(cachedMaxWeaponSlots, cachedMaxPassiveSlots, cachedMaxStatSlots, cachedMaxWeaponRank, cachedMaxStatRank)
end)

Remotes.GetEvent("StateSync").OnClientEvent:Connect(function(data: any)
	if data.zoneId then
		currentZoneId = data.zoneId
	end
	if data.zoneName and data.zoneName ~= "" then
		currentZoneName = data.zoneName
	end

	if data.teleportingToZone ~= nil then
		if data.teleportingToZone ~= "" then
			overlays.SetWarpOverlay(true, tostring(data.teleportingToZone))
		else
			overlays.SetWarpOverlay(false, nil)
		end
	end

	if data.portalUnlockedAlert then
		overlays.PresentBanner("⚡ TÉLÉPORTEUR INTER-ZONES ACTIVÉ ⚡", tostring(data.portalUnlockedAlert), 5.0)
	end

	if data.isDead then
		overlays.ShowGameOver(string.format(
			"• Secteur atteint : %s (Vague %d)\n• Niveau de combat : NIV. %d\n• Emplacements : %d Armes | %d Passifs | %d Stats\n• ADN global enregistré : %d XP",
			currentZoneName,
			currentSurvivingWave,
			currentRunLevel,
			cachedMaxWeaponSlots,
			cachedMaxPassiveSlots,
			cachedMaxStatSlots,
			cachedTotalXP
		))
	end

	if data.currentHP ~= nil and data.maxHP ~= nil then
		if prevHP ~= nil and data.currentHP < prevHP then
			overlays.TriggerDamageFlash()
		end
		prevHP = data.currentHP
		OverheadVitals.UpdateHealth(data.currentHP, data.maxHP)

		if data.currentHP <= 0 then
			overlays.ShowGameOver(nil)
		end
	end

	if data.currentOverdrive ~= nil and data.maxOverdrive ~= nil then
		OverheadVitals.UpdateOverdrive(data.currentOverdrive, data.maxOverdrive, data.isOverdriveActive == true)
	end

	if data.level then
		currentRunLevel = data.level
		OverheadVitals.UpdateLevel(currentRunLevel)
		if data.currentXP ~= nil and data.xpToNextLevel then
			OverheadVitals.UpdateXP(data.currentXP, data.xpToNextLevel)
		end
		refreshLocalPortalVisuals()
	end

	if data.wave then
		currentSurvivingWave = data.wave
		currentWaveState = tostring(data.waveState or "SPAWNING")
		currentWaveTimer = tonumber(data.waveTimer) or 0
		refreshTopInfoText()
	end

	if data.weapons then
		inventoryController.UpdateWeapons(data.weapons)
	end

	if data.passives then
		inventoryController.UpdatePassives(data.passives)
	end

	if data.stats then
		inventoryController.UpdateStats(data.statCardLevels)
	end
end)

-- Request full initial sync now that all UI listeners are mounted
Remotes.GetEvent("RequestSync"):FireServer()
