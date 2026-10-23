--!strict
-- ClientHUD.client.luau: Full Sci-Fi Mecha HUD (XP bar, Health, Overdrive, Wave status, Level-Up cards modal)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local WeaponsData = require(Shared:WaitForChild("WeaponsData"))

-- Create Main ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SoulMachineHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- --- 1. TOP CENTER: XP BAR & LEVEL ---
local xpContainer = Instance.new("Frame")
xpContainer.Name = "XPContainer"
xpContainer.Size = UDim2.new(0, 420, 0, 42)
xpContainer.Position = UDim2.new(0.5, -210, 0, 16)
xpContainer.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
xpContainer.BackgroundTransparency = 0.25
xpContainer.BorderSizePixel = 0
xpContainer.Parent = screenGui

local xpCorner = Instance.new("UICorner")
xpCorner.CornerRadius = UDim.new(0, 8)
xpCorner.Parent = xpContainer

local xpStroke = Instance.new("UIStroke")
xpStroke.Color = Color3.fromRGB(0, 180, 255)
xpStroke.Thickness = 1.5
xpStroke.Parent = xpContainer

local levelBadge = Instance.new("TextLabel")
levelBadge.Name = "LevelBadge"
levelBadge.Size = UDim2.new(0, 90, 1, 0)
levelBadge.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
levelBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
levelBadge.Font = Enum.Font.GothamBold
levelBadge.TextSize = 14
levelBadge.Text = "NIV. 1"
levelBadge.Parent = xpContainer

local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(0, 8)
badgeCorner.Parent = levelBadge

local xpBarBg = Instance.new("Frame")
xpBarBg.Name = "BarBG"
xpBarBg.Size = UDim2.new(1, -106, 0, 16)
xpBarBg.Position = UDim2.new(0, 98, 0.5, -8)
xpBarBg.BackgroundColor3 = Color3.fromRGB(8, 12, 18)
xpBarBg.BorderSizePixel = 0
xpBarBg.Parent = xpContainer

local xpBarFill = Instance.new("Frame")
xpBarFill.Name = "Fill"
xpBarFill.Size = UDim2.new(0, 0, 1, 0)
xpBarFill.BackgroundColor3 = Color3.fromRGB(0, 230, 255)
xpBarFill.BorderSizePixel = 0
xpBarFill.Parent = xpBarBg

local xpText = Instance.new("TextLabel")
xpText.Name = "XPText"
xpText.Size = UDim2.new(1, 0, 1, 0)
xpText.BackgroundTransparency = 1
xpText.TextColor3 = Color3.fromRGB(255, 255, 255)
xpText.Font = Enum.Font.GothamBold
xpText.TextSize = 11
xpText.Text = "0 / 12 XP"
xpText.Parent = xpBarBg

-- --- 2. TOP BAR: WAVE STATUS & RADAR ---
local waveContainer = Instance.new("Frame")
waveContainer.Name = "WaveContainer"
waveContainer.Size = UDim2.new(0, 280, 0, 50)
waveContainer.Position = UDim2.new(0.5, -140, 0, 68)
waveContainer.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
waveContainer.BackgroundTransparency = 0.3
waveContainer.BorderSizePixel = 0
waveContainer.Parent = screenGui

local waveCorner = Instance.new("UICorner")
waveCorner.CornerRadius = UDim.new(0, 8)
waveCorner.Parent = waveContainer

local waveLabel = Instance.new("TextLabel")
waveLabel.Name = "WaveLabel"
waveLabel.Size = UDim2.new(1, 0, 0.5, 0)
waveLabel.BackgroundTransparency = 1
waveLabel.TextColor3 = Color3.fromRGB(255, 200, 40)
waveLabel.Font = Enum.Font.GothamBlack
waveLabel.TextSize = 15
waveLabel.Text = "VAGUE 1"
waveLabel.Parent = waveContainer

local waveSubLabel = Instance.new("TextLabel")
waveSubLabel.Name = "WaveSubLabel"
waveSubLabel.Size = UDim2.new(1, 0, 0.5, 0)
waveSubLabel.Position = UDim2.new(0, 0, 0.5, 0)
waveSubLabel.BackgroundTransparency = 1
waveSubLabel.TextColor3 = Color3.fromRGB(200, 220, 240)
waveSubLabel.Font = Enum.Font.GothamMedium
waveSubLabel.TextSize = 12
waveSubLabel.Text = "ASSAUT EN COURS (40s) | 0 ENNEMIS"
waveSubLabel.Parent = waveContainer

-- --- 3. BOTTOM LEFT: HEALTH & SHIELD/ARMOR ---
local vitalsContainer = Instance.new("Frame")
vitalsContainer.Name = "VitalsContainer"
vitalsContainer.Size = UDim2.new(0, 260, 0, 64)
vitalsContainer.Position = UDim2.new(0, 24, 1, -88)
vitalsContainer.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
vitalsContainer.BackgroundTransparency = 0.25
vitalsContainer.BorderSizePixel = 0
vitalsContainer.Parent = screenGui

local vitalsCorner = Instance.new("UICorner")
vitalsCorner.CornerRadius = UDim.new(0, 8)
vitalsCorner.Parent = vitalsContainer

local hpBarBg = Instance.new("Frame")
hpBarBg.Name = "HPBarBG"
hpBarBg.Size = UDim2.new(1, -20, 0, 22)
hpBarBg.Position = UDim2.new(0, 10, 0, 10)
hpBarBg.BackgroundColor3 = Color3.fromRGB(50, 15, 15)
hpBarBg.BorderSizePixel = 0
hpBarBg.Parent = vitalsContainer

local hpBarFill = Instance.new("Frame")
hpBarFill.Name = "Fill"
hpBarFill.Size = UDim2.new(1, 0, 1, 0)
hpBarFill.BackgroundColor3 = Color3.fromRGB(50, 220, 80)
hpBarFill.BorderSizePixel = 0
hpBarFill.Parent = hpBarBg

local hpText = Instance.new("TextLabel")
hpText.Name = "HPText"
hpText.Size = UDim2.new(1, 0, 1, 0)
hpText.BackgroundTransparency = 1
hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
hpText.Font = Enum.Font.GothamBold
hpText.TextSize = 12
hpText.Text = "100 / 100 PV"
hpText.Parent = hpBarBg

local armorText = Instance.new("TextLabel")
armorText.Name = "ArmorText"
armorText.Size = UDim2.new(1, -20, 0, 20)
armorText.Position = UDim2.new(0, 10, 0, 36)
armorText.BackgroundTransparency = 1
armorText.TextColor3 = Color3.fromRGB(160, 200, 255)
armorText.Font = Enum.Font.GothamMedium
armorText.TextSize = 11
armorText.TextXAlignment = Enum.TextXAlignment.Left
armorText.Text = "🛡️ BLINDAGE : 0 ARMURE (0% RÉDUCTION)"
armorText.Parent = vitalsContainer

-- --- 4. BOTTOM CENTER: OVERDRIVE REACTOR ---
local odContainer = Instance.new("Frame")
odContainer.Name = "OverdriveContainer"
odContainer.Size = UDim2.new(0, 320, 0, 52)
odContainer.Position = UDim2.new(0.5, -160, 1, -76)
odContainer.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
odContainer.BackgroundTransparency = 0.25
odContainer.BorderSizePixel = 0
odContainer.Parent = screenGui

local odCorner = Instance.new("UICorner")
odCorner.CornerRadius = UDim.new(0, 8)
odCorner.Parent = odContainer

local odBarBg = Instance.new("Frame")
odBarBg.Name = "ODBarBG"
odBarBg.Size = UDim2.new(1, -20, 0, 18)
odBarBg.Position = UDim2.new(0, 10, 0, 8)
odBarBg.BackgroundColor3 = Color3.fromRGB(30, 15, 10)
odBarBg.BorderSizePixel = 0
odBarBg.Parent = odContainer

local odBarFill = Instance.new("Frame")
odBarFill.Name = "Fill"
odBarFill.Size = UDim2.new(0, 0, 1, 0)
odBarFill.BackgroundColor3 = Color3.fromRGB(255, 120, 30)
odBarFill.BorderSizePixel = 0
odBarFill.Parent = odBarBg

local odBtn = Instance.new("TextButton")
odBtn.Name = "ODButton"
odBtn.Size = UDim2.new(1, -20, 0, 20)
odBtn.Position = UDim2.new(0, 10, 0, 28)
odBtn.BackgroundTransparency = 1
odBtn.TextColor3 = Color3.fromRGB(255, 160, 60)
odBtn.Font = Enum.Font.GothamBold
odBtn.TextSize = 11
odBtn.Text = "REACTEUR OVERDRIVE : 0%"
odBtn.Parent = odContainer

odBtn.Activated:Connect(function()
	Remotes.GetEvent("TriggerOverdrive"):FireServer()
end)

-- --- 5. BOTTOM RIGHT: WEAPONS TRAY ---
local weaponsContainer = Instance.new("Frame")
weaponsContainer.Name = "WeaponsContainer"
weaponsContainer.Size = UDim2.new(0, 240, 0, 110)
weaponsContainer.Position = UDim2.new(1, -264, 1, -134)
weaponsContainer.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
weaponsContainer.BackgroundTransparency = 0.3
weaponsContainer.BorderSizePixel = 0
weaponsContainer.Parent = screenGui

local wCorner = Instance.new("UICorner")
wCorner.CornerRadius = UDim.new(0, 8)
wCorner.Parent = weaponsContainer

local wHeader = Instance.new("TextLabel")
wHeader.Size = UDim2.new(1, 0, 0, 24)
wHeader.BackgroundTransparency = 1
wHeader.TextColor3 = Color3.fromRGB(0, 200, 255)
wHeader.Font = Enum.Font.GothamBold
wHeader.TextSize = 11
wHeader.Text = "ARSENAL DU MECHA"
wHeader.Parent = weaponsContainer

local wList = Instance.new("TextLabel")
wList.Name = "WList"
wList.Size = UDim2.new(1, -16, 1, -30)
wList.Position = UDim2.new(0, 8, 0, 26)
wList.BackgroundTransparency = 1
wList.TextColor3 = Color3.fromRGB(220, 230, 245)
wList.Font = Enum.Font.Gotham
wList.TextSize = 11
wList.TextXAlignment = Enum.TextXAlignment.Left
wList.TextYAlignment = Enum.TextYAlignment.Top
wList.Text = "• Canon Impulsion (Rang 1)"
wList.Parent = weaponsContainer

-- --- 6. LEVEL UP 3-CARD MODAL ---
local levelUpModal = Instance.new("Frame")
levelUpModal.Name = "LevelUpModal"
levelUpModal.Size = UDim2.new(1, 0, 1, 0)
levelUpModal.BackgroundColor3 = Color3.fromRGB(5, 8, 14)
levelUpModal.BackgroundTransparency = 0.4
levelUpModal.Visible = false
levelUpModal.Parent = screenGui

local modalTitle = Instance.new("TextLabel")
modalTitle.Size = UDim2.new(1, 0, 0, 60)
modalTitle.Position = UDim2.new(0, 0, 0.15, 0)
modalTitle.BackgroundTransparency = 1
modalTitle.TextColor3 = Color3.fromRGB(0, 230, 255)
modalTitle.Font = Enum.Font.GothamBlack
modalTitle.TextSize = 28
modalTitle.Text = "SÉLECTION DU PROTOCOLE D'ÉVOLUTION"
modalTitle.Parent = levelUpModal

local cardsHolder = Instance.new("Frame")
cardsHolder.Name = "CardsHolder"
cardsHolder.Size = UDim2.new(0, 840, 0, 360)
cardsHolder.Position = UDim2.new(0.5, -420, 0.5, -150)
cardsHolder.BackgroundTransparency = 1
cardsHolder.Parent = levelUpModal

local function createChoiceCard(index: number, cardData: any, xOffset: number): Frame
	local card = Instance.new("Frame")
	card.Name = "Card_" .. index
	card.Size = UDim2.new(0, 250, 0, 340)
	card.Position = UDim2.new(0, xOffset, 0, 0)
	card.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
	card.BorderSizePixel = 0
	card.Parent = cardsHolder

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 12)
	cCorner.Parent = card

	local cStroke = Instance.new("UIStroke")
	cStroke.Color = cardData.rarityColor or Color3.fromRGB(0, 200, 255)
	cStroke.Thickness = 2
	cStroke.Parent = card

	-- Card Category Tag
	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.new(1, -20, 0, 24)
	tag.Position = UDim2.new(0, 10, 0, 12)
	tag.BackgroundTransparency = 1
	tag.TextColor3 = cardData.rarityColor
	tag.Font = Enum.Font.GothamBold
	tag.TextSize = 11
	tag.Text = cardData.subtitle or "UPGRADE"
	tag.Parent = card

	-- Card Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 48)
	title.Position = UDim2.new(0, 10, 0, 38)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 16
	title.TextWrapped = true
	title.Text = cardData.title
	title.Parent = card

	-- Card Icon Image
	local iconImg = Instance.new("ImageLabel")
	iconImg.Size = UDim2.new(0, 72, 0, 72)
	iconImg.Position = UDim2.new(0.5, -36, 0, 96)
	iconImg.BackgroundTransparency = 1
	iconImg.Image = cardData.icon or "rbxassetid://10709791437"
	iconImg.Parent = card

	-- Card Description
	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -24, 0, 90)
	desc.Position = UDim2.new(0, 12, 0, 180)
	desc.BackgroundTransparency = 1
	desc.TextColor3 = Color3.fromRGB(190, 210, 230)
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 12
	desc.TextWrapped = true
	desc.Text = cardData.description or ""
	desc.Parent = card

	-- Select Button
	local selectBtn = Instance.new("TextButton")
	selectBtn.Name = "SelectBtn"
	selectBtn.Size = UDim2.new(1, -30, 0, 38)
	selectBtn.Position = UDim2.new(0, 15, 1, -50)
	selectBtn.BackgroundColor3 = cardData.rarityColor
	selectBtn.TextColor3 = Color3.fromRGB(10, 12, 18)
	selectBtn.Font = Enum.Font.GothamBlack
	selectBtn.TextSize = 13
	selectBtn.Text = "SÉLECTIONNER"
	selectBtn.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = selectBtn

	selectBtn.MouseButton1Click:Connect(function()
		levelUpModal.Visible = false
		Remotes.GetEvent("SelectLevelUpChoice"):FireServer(index)
	end)

	return card
end

-- Open Level Up Screen
Remotes.GetEvent("LevelUpOptions").OnClientEvent:Connect(function(cards: { any })
	-- Clear old cards
	for _, child in ipairs(cardsHolder:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local offsets = { 20, 295, 570 }
	for idx, cardData in ipairs(cards) do
		if idx <= 3 then
			createChoiceCard(idx, cardData, offsets[idx])
		end
	end

	levelUpModal.Visible = true
end)

-- State Sync Listener
Remotes.GetEvent("StateSync").OnClientEvent:Connect(function(data: any)
	if data.currentHP and data.maxHP then
		local hpRatio = math.clamp(data.currentHP / data.maxHP, 0, 1)
		hpBarFill.Size = UDim2.new(hpRatio, 0, 1, 0)
		hpText.Text = string.format("%.0f / %.0f PV", data.currentHP, data.maxHP)
	end

	if data.stats and data.stats.Armor ~= nil then
		local armor = data.stats.Armor
		local reduction = math.floor((armor / (armor + 100)) * 100)
		armorText.Text = string.format("🛡️ BLINDAGE : %.0f ARMURE (%d%% RÉDUCTION)", armor, reduction)
	end

	if data.currentOverdrive ~= nil and data.maxOverdrive ~= nil then
		local odRatio = math.clamp(data.currentOverdrive / data.maxOverdrive, 0, 1)
		odBarFill.Size = UDim2.new(odRatio, 0, 1, 0)

		if data.isOverdriveActive then
			odBtn.Text = "⚡ OVERDRIVE ACTIF ! FEU HYPER-FRÉNÉTIQUE !"
			odBtn.TextColor3 = Color3.fromRGB(255, 50, 80)
			odBarFill.BackgroundColor3 = Color3.fromRGB(255, 30, 80)
		elseif odRatio >= 1.0 then
			odBtn.Text = "⚡ OVERDRIVE PRÊT ! [ESPACE / TOUCHE F]"
			odBtn.TextColor3 = Color3.fromRGB(255, 240, 50)
			odBarFill.BackgroundColor3 = Color3.fromRGB(255, 200, 30)
		else
			odBtn.Text = string.format("RÉACTEUR OVERDRIVE : %.0f%%", odRatio * 100)
			odBtn.TextColor3 = Color3.fromRGB(255, 160, 60)
			odBarFill.BackgroundColor3 = Color3.fromRGB(255, 120, 30)
		end
	end

	if data.level and data.currentXP ~= nil and data.xpToNextLevel then
		levelBadge.Text = "NIV. " .. data.level
		local xpRatio = math.clamp(data.currentXP / data.xpToNextLevel, 0, 1)
		xpBarFill.Size = UDim2.new(xpRatio, 0, 1, 0)
		xpText.Text = string.format("%.0f / %.0f XP", data.currentXP, data.xpToNextLevel)
	end

	if data.wave then
		waveLabel.Text = "VAGUE " .. data.wave
		local stateDesc = "ASSAUT"
		if data.waveState == "RESTING" then stateDesc = "PAUSE ENTRE VAGUES"
		elseif data.waveState == "CLEARING" then stateDesc = "NETTOYAGE ESSAIM"
		elseif data.waveState == "BOSS" then stateDesc = "BOSS EN COURS !"
		end

		waveSubLabel.Text = string.format("%s (%ds) | %d ENNEMIS", stateDesc, data.waveTimer or 0, data.activeEnemies or 0)
	end

	if data.weapons then
		local lines: { string } = {}
		for wId, rank in pairs(data.weapons) do
			local wDef = WeaponsData.GetWeapon(wId)
			local name = if wDef then wDef.name else wId
			table.insert(lines, string.format("• %s (Rang %d)", name, rank))
		end
		wList.Text = table.concat(lines, "\n")
	end
end)
