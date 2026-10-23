--!strict
-- ClientHUD.client.luau: Faithful Cyberpunk HUD, 3-Row Inventory, Damage Flash, and Level Up Modal with Countdown

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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

-- --- 1. FULLSCREEN DAMAGE FLASH (Vignette) ---
local damageFlash = Instance.new("Frame")
damageFlash.Name = "DamageFlash"
damageFlash.Size = UDim2.new(1, 0, 1, 0)
damageFlash.BackgroundColor3 = Color3.fromRGB(220, 20, 30)
damageFlash.BackgroundTransparency = 1
damageFlash.BorderSizePixel = 0
damageFlash.ZIndex = 50
damageFlash.Parent = screenGui

local function triggerDamageFlash()
	damageFlash.BackgroundTransparency = 0.65
	local tw = TweenService:Create(damageFlash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	tw:Play()
end

-- --- 2. TOP BAR: XP & WAVE TRACKER ---
local topBarContainer = Instance.new("Frame")
topBarContainer.Name = "TopBarContainer"
topBarContainer.Size = UDim2.new(0, 520, 0, 48)
topBarContainer.Position = UDim2.new(0.5, -260, 0, 16)
topBarContainer.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
topBarContainer.BackgroundTransparency = 0.25
topBarContainer.BorderSizePixel = 0
topBarContainer.Parent = screenGui

local topBarCorner = Instance.new("UICorner")
topBarCorner.CornerRadius = UDim.new(0, 8)
topBarCorner.Parent = topBarContainer

local topBarStroke = Instance.new("UIStroke")
topBarStroke.Color = Color3.fromRGB(0, 180, 240)
topBarStroke.Thickness = 1.5
topBarStroke.Transparency = 0.3
topBarStroke.Parent = topBarContainer

-- Level Badge
local levelBadge = Instance.new("TextLabel")
levelBadge.Name = "LevelBadge"
levelBadge.Size = UDim2.new(0, 80, 1, 0)
levelBadge.BackgroundTransparency = 1
levelBadge.TextColor3 = Color3.fromRGB(0, 240, 255)
levelBadge.Font = Enum.Font.GothamBlack
levelBadge.TextSize = 14
levelBadge.Text = "NIV. 1"
levelBadge.Parent = topBarContainer

-- XP Bar
local xpBarBg = Instance.new("Frame")
xpBarBg.Name = "XPBarBg"
xpBarBg.Size = UDim2.new(1, -260, 0, 14)
xpBarBg.Position = UDim2.new(0, 85, 0.5, -7)
xpBarBg.BackgroundColor3 = Color3.fromRGB(8, 12, 18)
xpBarBg.BorderSizePixel = 0
xpBarBg.Parent = topBarContainer

local xpCorner = Instance.new("UICorner")
xpCorner.CornerRadius = UDim.new(0.5, 0)
xpCorner.Parent = xpBarBg

local xpBarFill = Instance.new("Frame")
xpBarFill.Name = "Fill"
xpBarFill.Size = UDim2.new(0, 0, 1, 0)
xpBarFill.BackgroundColor3 = Color3.fromRGB(170, 70, 255) -- Violet XP
xpBarFill.BorderSizePixel = 0
xpBarFill.Parent = xpBarBg

local xpFillCorner = Instance.new("UICorner")
xpFillCorner.CornerRadius = UDim.new(0.5, 0)
xpFillCorner.Parent = xpBarFill

local xpText = Instance.new("TextLabel")
xpText.Name = "XPText"
xpText.Size = UDim2.new(1, 0, 1, 0)
xpText.BackgroundTransparency = 1
xpText.TextColor3 = Color3.fromRGB(255, 255, 255)
xpText.Font = Enum.Font.GothamBold
xpText.TextSize = 10
xpText.Text = "0 / 12 XP"
xpText.Parent = xpBarBg

-- Wave & Enemies Tracker
local waveInfoLabel = Instance.new("TextLabel")
waveInfoLabel.Name = "WaveInfoLabel"
waveInfoLabel.Size = UDim2.new(0, 160, 1, 0)
waveInfoLabel.Position = UDim2.new(1, -165, 0, 0)
waveInfoLabel.BackgroundTransparency = 1
waveInfoLabel.TextColor3 = Color3.fromRGB(255, 210, 50)
waveInfoLabel.Font = Enum.Font.GothamBlack
waveInfoLabel.TextSize = 12
waveInfoLabel.Text = "VAGUE 1 (40s) | 0 FOES"
waveInfoLabel.Parent = topBarContainer

-- --- 3. TOP-LEFT: 3-ROW INVENTORY (Fidèle à l'original: ARMES, PASSIFS, STATS) ---
local invContainer = Instance.new("Frame")
invContainer.Name = "InventoryContainer"
invContainer.Size = UDim2.new(0, 310, 0, 128)
invContainer.Position = UDim2.new(0, 20, 0, 20)
invContainer.BackgroundColor3 = Color3.fromRGB(10, 15, 25)
invContainer.BackgroundTransparency = 0.25
invContainer.BorderSizePixel = 0
invContainer.Parent = screenGui

local invCorner = Instance.new("UICorner")
invCorner.CornerRadius = UDim.new(0, 10)
invCorner.Parent = invContainer

local invStroke = Instance.new("UIStroke")
invStroke.Color = Color3.fromRGB(0, 200, 255)
invStroke.Thickness = 1.5
invStroke.Transparency = 0.4
invStroke.Parent = invContainer

local function createInvRow(name: string, labelText: string, labelColor: Color3, yPos: number): (Frame, Frame)
	local row = Instance.new("Frame")
	row.Name = name .. "Row"
	row.Size = UDim2.new(1, -20, 0, 32)
	row.Position = UDim2.new(0, 10, 0, yPos)
	row.BackgroundTransparency = 1
	row.Parent = invContainer

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(0, 75, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = labelColor
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = labelText
	label.Parent = row

	local slots = Instance.new("Frame")
	slots.Name = "Slots"
	slots.Size = UDim2.new(1, -75, 1, 0)
	slots.Position = UDim2.new(0, 75, 0, 0)
	slots.BackgroundTransparency = 1
	slots.Parent = row

	return row, slots
end

local _, weaponSlots = createInvRow("Weapons", "ARMES", Color3.fromRGB(255, 100, 100), 8)
local _, passiveSlots = createInvRow("Passives", "PASSIFS", Color3.fromRGB(200, 150, 255), 44)
local _, statSlots = createInvRow("Stats", "STATS", Color3.fromRGB(100, 255, 150), 80)

local function populateRowSlots(container: Frame, count: number, borderColor: Color3, items: { { name: string, rank: number, glyph: string?, icon: string? } })
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	for i = 1, count do
		local box = Instance.new("Frame")
		box.Name = "Slot_" .. i
		box.Size = UDim2.new(0, 30, 0, 30)
		box.Position = UDim2.new(0, (i - 1) * 34, 0, 1)
		box.BackgroundColor3 = Color3.fromRGB(14, 18, 30)
		box.BorderSizePixel = 0
		box.Parent = container

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 6)
		bCorner.Parent = box

		local bStroke = Instance.new("UIStroke")
		bStroke.Thickness = 1.2
		bStroke.Parent = box

		local item = items[i]
		if item then
			bStroke.Color = borderColor
			bStroke.Transparency = 0.2
			box.BackgroundColor3 = Color3.fromRGB(22, 30, 48)

			-- Sci-Fi Technical Designation
			local tagLabel = Instance.new("TextLabel")
			tagLabel.Name = "Tag"
			tagLabel.Size = UDim2.new(1, -2, 1, -2)
			tagLabel.Position = UDim2.new(0, 1, 0, 1)
			tagLabel.BackgroundTransparency = 1
			tagLabel.TextColor3 = borderColor
			tagLabel.Font = Enum.Font.GothamBlack
			tagLabel.TextSize = 8
			tagLabel.Text = item.tag or string.sub(item.name, 1, 4):upper()
			tagLabel.ZIndex = 1
			tagLabel.Parent = box

			-- Optional image overlay if valid
			if item.icon and item.icon ~= "" and not string.find(item.icon, "rbxassetid://107097914") then
				local iconImg = Instance.new("ImageLabel")
				iconImg.Size = UDim2.new(1, -4, 1, -4)
				iconImg.Position = UDim2.new(0, 2, 0, 2)
				iconImg.BackgroundTransparency = 1
				iconImg.Image = item.icon
				iconImg.ZIndex = 2
				iconImg.Parent = box
			end

			-- Rank text badge in bottom-right corner
			if item.rank and item.rank > 0 then
				local rankBadge = Instance.new("TextLabel")
				rankBadge.Name = "RankBadge"
				rankBadge.Size = UDim2.new(0, 13, 0, 11)
				rankBadge.Position = UDim2.new(1, -13, 1, -11)
				rankBadge.BackgroundColor3 = Color3.fromRGB(10, 15, 25)
				rankBadge.BackgroundTransparency = 0.2
				rankBadge.TextColor3 = borderColor
				rankBadge.Font = Enum.Font.GothamBlack
				rankBadge.TextSize = 8
				rankBadge.Text = tostring(item.rank)
				rankBadge.ZIndex = 3
				rankBadge.Parent = box

				local rCorner = Instance.new("UICorner")
				rCorner.CornerRadius = UDim.new(0, 3)
				rCorner.Parent = rankBadge
			end
		else
			bStroke.Color = Color3.fromRGB(40, 50, 70)
			bStroke.Transparency = 0.7
		end
	end
end

-- --- 4. BOTTOM LEFT: HEALTH & SHIELD ---
local vitalsContainer = Instance.new("Frame")
vitalsContainer.Name = "VitalsContainer"
vitalsContainer.Size = UDim2.new(0, 260, 0, 60)
vitalsContainer.Position = UDim2.new(0, 24, 1, -84)
vitalsContainer.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
vitalsContainer.BackgroundTransparency = 0.25
vitalsContainer.BorderSizePixel = 0
vitalsContainer.Parent = screenGui

local vitalsCorner = Instance.new("UICorner")
vitalsCorner.CornerRadius = UDim.new(0, 8)
vitalsCorner.Parent = vitalsContainer

local vitalsStroke = Instance.new("UIStroke")
vitalsStroke.Color = Color3.fromRGB(0, 200, 255)
vitalsStroke.Thickness = 1.5
vitalsStroke.Transparency = 0.4
vitalsStroke.Parent = vitalsContainer

local hpBarBg = Instance.new("Frame")
hpBarBg.Name = "HPBarBg"
hpBarBg.Size = UDim2.new(1, -20, 0, 18)
hpBarBg.Position = UDim2.new(0, 10, 0, 8)
hpBarBg.BackgroundColor3 = Color3.fromRGB(25, 10, 10)
hpBarBg.BorderSizePixel = 0
hpBarBg.Parent = vitalsContainer

local hpCorner = Instance.new("UICorner")
hpCorner.CornerRadius = UDim.new(0, 5)
hpCorner.Parent = hpBarBg

local hpBarFill = Instance.new("Frame")
hpBarFill.Name = "Fill"
hpBarFill.Size = UDim2.new(1, 0, 1, 0)
hpBarFill.BackgroundColor3 = Color3.fromRGB(50, 220, 70)
hpBarFill.BorderSizePixel = 0
hpBarFill.Parent = hpBarBg

local hpFillCorner = Instance.new("UICorner")
hpFillCorner.CornerRadius = UDim.new(0, 5)
hpFillCorner.Parent = hpBarFill

local hpText = Instance.new("TextLabel")
hpText.Name = "HPText"
hpText.Size = UDim2.new(1, 0, 1, 0)
hpText.BackgroundTransparency = 1
hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
hpText.Font = Enum.Font.GothamBold
hpText.TextSize = 11
hpText.Text = "100 / 100 PV"
hpText.Parent = hpBarBg

local armorText = Instance.new("TextLabel")
armorText.Name = "ArmorText"
armorText.Size = UDim2.new(1, -20, 0, 20)
armorText.Position = UDim2.new(0, 10, 0, 32)
armorText.BackgroundTransparency = 1
armorText.TextColor3 = Color3.fromRGB(150, 200, 255)
armorText.Font = Enum.Font.GothamMedium
armorText.TextSize = 11
armorText.TextXAlignment = Enum.TextXAlignment.Left
armorText.Text = "🛡️ BLINDAGE : 0 ARMURE (0% RÉDUCTION)"
armorText.Parent = vitalsContainer

-- --- 5. BOTTOM CENTER: OVERDRIVE REACTOR ---
local odContainer = Instance.new("Frame")
odContainer.Name = "OverdriveContainer"
odContainer.Size = UDim2.new(0, 320, 0, 52)
odContainer.Position = UDim2.new(0.5, -160, 1, -74)
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
odBtn.Text = "RÉACTEUR OVERDRIVE : 0%"
odBtn.Parent = odContainer

odBtn.Activated:Connect(function()
	Remotes.GetEvent("TriggerOverdrive"):FireServer()
end)

-- --- 6. LEVEL UP MODAL AVEC COMPTE À REBOURS (15s) ET DESIGN FIDÈLE ---
local levelUpModal = Instance.new("Frame")
levelUpModal.Name = "LevelUpModal"
levelUpModal.Size = UDim2.new(1, 0, 1, 0)
levelUpModal.BackgroundColor3 = Color3.fromRGB(10, 15, 30)
levelUpModal.BackgroundTransparency = 0.15
levelUpModal.Visible = false
levelUpModal.ZIndex = 100
levelUpModal.Parent = screenGui

-- Titre
local modalTitle = Instance.new("TextLabel")
modalTitle.Name = "Title"
modalTitle.Size = UDim2.new(1, 0, 0, 44)
modalTitle.Position = UDim2.new(0, 0, 0.08, 0)
modalTitle.BackgroundTransparency = 1
modalTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
modalTitle.Font = Enum.Font.GothamBlack
modalTitle.TextSize = 34
modalTitle.Text = "NIVEAU SUPÉRIEUR"
modalTitle.Parent = levelUpModal

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "Subtitle"
subtitleLabel.Size = UDim2.new(1, 0, 0, 24)
subtitleLabel.Position = UDim2.new(0, 0, 0.14, 0)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
subtitleLabel.Font = Enum.Font.GothamMedium
subtitleLabel.TextSize = 16
subtitleLabel.Text = "Choisissez une amélioration"
subtitleLabel.Parent = levelUpModal

-- Compte à rebours (15s)
local timerContainer = Instance.new("Frame")
timerContainer.Name = "TimerContainer"
timerContainer.Size = UDim2.new(0, 360, 0, 26)
timerContainer.Position = UDim2.new(0.5, -180, 0.19, 0)
timerContainer.BackgroundColor3 = Color3.fromRGB(15, 20, 35)
timerContainer.BorderSizePixel = 0
timerContainer.Parent = levelUpModal

local timerCorner = Instance.new("UICorner")
timerCorner.CornerRadius = UDim.new(0.5, 0)
timerCorner.Parent = timerContainer

local timerFill = Instance.new("Frame")
timerFill.Name = "Fill"
timerFill.Size = UDim2.new(1, 0, 1, 0)
timerFill.BackgroundColor3 = Color3.fromRGB(0, 220, 255)
timerFill.BorderSizePixel = 0
timerFill.Parent = timerContainer

local timerFillCorner = Instance.new("UICorner")
timerFillCorner.CornerRadius = UDim.new(0.5, 0)
timerFillCorner.Parent = timerFill

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(1, 0, 1, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timerLabel.Font = Enum.Font.GothamBold
timerLabel.TextSize = 12
timerLabel.Text = "TEMPS RESTANT : 15s"
timerLabel.ZIndex = 2
timerLabel.Parent = timerContainer

local cardsHolder = Instance.new("Frame")
cardsHolder.Name = "CardsHolder"
cardsHolder.Size = UDim2.new(0, 940, 0, 420)
cardsHolder.Position = UDim2.new(0.5, -470, 0.5, -170)
cardsHolder.BackgroundTransparency = 1
cardsHolder.Parent = levelUpModal

local countdownRemaining = 15.0
local countdownActive = false

local function createChoiceCard(index: number, cardData: any, xOffset: number): Frame
	local card = Instance.new("Frame")
	card.Name = "Card_" .. index
	card.Size = UDim2.new(0, 280, 0, 400)
	card.Position = UDim2.new(0, xOffset, 0, 0)
	card.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = cardsHolder

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 20)
	cCorner.Parent = card

	local cStroke = Instance.new("UIStroke")
	cStroke.Color = cardData.rarityColor or Color3.fromRGB(0, 200, 255)
	cStroke.Thickness = 2.5
	cStroke.Parent = card

	-- Floating Category Badge on top border (-15px)
	local categoryBadge = Instance.new("TextLabel")
	categoryBadge.Name = "CategoryBadge"
	categoryBadge.Size = UDim2.new(0, 120, 0, 28)
	categoryBadge.Position = UDim2.new(0.5, -60, 0, -14)
	categoryBadge.BackgroundColor3 = Color3.fromRGB(10, 20, 30)
	categoryBadge.TextColor3 = cardData.rarityColor or Color3.fromRGB(255, 255, 255)
	categoryBadge.Font = Enum.Font.GothamBlack
	categoryBadge.TextSize = 12
	categoryBadge.Text = cardData.category or "UPGRADE"
	categoryBadge.Parent = card

	local catCorner = Instance.new("UICorner")
	catCorner.CornerRadius = UDim.new(0, 8)
	catCorner.Parent = categoryBadge

	local catStroke = Instance.new("UIStroke")
	catStroke.Color = cardData.rarityColor or Color3.fromRGB(0, 200, 255)
	catStroke.Thickness = 1.5
	catStroke.Parent = categoryBadge

	-- Card Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -24, 0, 48)
	title.Position = UDim2.new(0, 12, 0, 28)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 17
	title.TextWrapped = true
	title.Text = cardData.title
	title.Parent = card

	-- Icon Box
	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.Size = UDim2.new(0, 80, 0, 80)
	iconBox.Position = UDim2.new(0.5, -40, 0, 86)
	iconBox.BackgroundColor3 = Color3.fromRGB(10, 20, 40)
	iconBox.BorderSizePixel = 0
	iconBox.Parent = card

	local iCorner = Instance.new("UICorner")
	iCorner.CornerRadius = UDim.new(0, 14)
	iCorner.Parent = iconBox

	local iStroke = Instance.new("UIStroke")
	iStroke.Color = cardData.rarityColor
	iStroke.Thickness = 2
	iStroke.Transparency = 0.3
	iStroke.Parent = iconBox

	-- Holographic sci-fi technical badge (NO tacky cartoon emojis)
	local iconBadge = Instance.new("TextLabel")
	iconBadge.Name = "IconBadge"
	iconBadge.Size = UDim2.new(1, -8, 1, -8)
	iconBadge.Position = UDim2.new(0, 4, 0, 4)
	iconBadge.BackgroundTransparency = 1
	iconBadge.Text = cardData.tag or string.sub(cardData.title, 1, 12):upper()
	iconBadge.TextColor3 = cardData.rarityColor
	iconBadge.Font = Enum.Font.GothamBlack
	iconBadge.TextSize = 11
	iconBadge.TextWrapped = true
	iconBadge.ZIndex = 1
	iconBadge.Parent = iconBox

	-- Check if asset exists in ReplicatedStorage.Icons (Bulk Import folder)
	local resolvedImage = cardData.icon
	local iconsFolder = ReplicatedStorage:FindFirstChild("Icons")
	if iconsFolder and cardData.iconFile then
		local found = iconsFolder:FindFirstChild(cardData.iconFile) or iconsFolder:FindFirstChild(string.gsub(cardData.iconFile, "%.png$", ""))
		if found and (found:IsA("Decal") or found:IsA("Texture")) then
			resolvedImage = found.Texture
		end
	end

	if resolvedImage and resolvedImage ~= "" and not string.find(resolvedImage, "rbxassetid://107097914") then
		local iconImg = Instance.new("ImageLabel")
		iconImg.Size = UDim2.new(1, -10, 1, -10)
		iconImg.Position = UDim2.new(0, 5, 0, 5)
		iconImg.BackgroundTransparency = 1
		iconImg.Image = resolvedImage
		iconImg.ZIndex = 2
		iconImg.Parent = iconBox
	end

	-- Subtitle (e.g. RANG 1 ➔ 2 or +20% PV)
	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "SubLabel"
	subLabel.Size = UDim2.new(1, -20, 0, 24)
	subLabel.Position = UDim2.new(0, 10, 0, 178)
	subLabel.BackgroundTransparency = 1
	subLabel.TextColor3 = cardData.rarityColor
	subLabel.Font = Enum.Font.GothamBold
	subLabel.TextSize = 12
	subLabel.Text = cardData.subtitle or ""
	subLabel.Parent = card

	-- Description
	local desc = Instance.new("TextLabel")
	desc.Name = "Desc"
	desc.Size = UDim2.new(1, -24, 0, 110)
	desc.Position = UDim2.new(0, 12, 0, 206)
	desc.BackgroundTransparency = 1
	desc.TextColor3 = Color3.fromRGB(200, 220, 255)
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 13
	desc.TextWrapped = true
	desc.Text = cardData.description or ""
	desc.Parent = card

	-- Full Card Button / Select Button
	local selectBtn = Instance.new("TextButton")
	selectBtn.Name = "SelectBtn"
	selectBtn.Size = UDim2.new(1, -30, 0, 42)
	selectBtn.Position = UDim2.new(0, 15, 1, -54)
	selectBtn.BackgroundColor3 = cardData.rarityColor
	selectBtn.TextColor3 = Color3.fromRGB(10, 15, 25)
	selectBtn.Font = Enum.Font.GothamBlack
	selectBtn.TextSize = 14
	selectBtn.Text = "SÉLECTIONNER"
	selectBtn.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = selectBtn

	local function pickThis()
		if not countdownActive then return end
		countdownActive = false
		levelUpModal.Visible = false
		Remotes.GetEvent("SelectLevelUpChoice"):FireServer(index)
	end

	selectBtn.Activated:Connect(pickThis)

	return card
end

-- Open Level Up Screen
Remotes.GetEvent("LevelUpOptions").OnClientEvent:Connect(function(cards: { any })
	for _, child in ipairs(cardsHolder:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local offsets = { 20, 330, 640 }
	for idx, cardData in ipairs(cards) do
		if idx <= 3 then
			createChoiceCard(idx, cardData, offsets[idx])
		end
	end

	countdownRemaining = 15.0
	countdownActive = true
	timerFill.Size = UDim2.new(1, 0, 1, 0)
	timerLabel.Text = "TEMPS RESTANT : 15s"
	levelUpModal.Visible = true
end)

-- Level Up Countdown Heartbeat
RunService.Heartbeat:Connect(function(dt: number)
	if countdownActive and levelUpModal.Visible then
		countdownRemaining -= dt
		local ratio = math.clamp(countdownRemaining / 15.0, 0, 1)
		timerFill.Size = UDim2.new(ratio, 0, 1, 0)
		timerLabel.Text = string.format("TEMPS RESTANT : %.1fs", math.max(0, countdownRemaining))

		if countdownRemaining <= 0 then
			countdownActive = false
			levelUpModal.Visible = false
			-- Auto-select first choice
			Remotes.GetEvent("SelectLevelUpChoice"):FireServer(1)
		end
	end
end)

local prevHP: number? = nil

-- State Sync Listener
Remotes.GetEvent("StateSync").OnClientEvent:Connect(function(data: any)
	if data.currentHP and data.maxHP then
		if prevHP ~= nil and data.currentHP < prevHP then
			triggerDamageFlash()
		end
		prevHP = data.currentHP

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
			odBtn.Text = "⚡ OVERDRIVE ACTIF ! FEU FRÉNÉTIQUE !"
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
		local stateDesc = "ASSAUT"
		if data.waveState == "RESTING" then stateDesc = "PAUSE"
		elseif data.waveState == "CLEARING" then stateDesc = "NETTOYAGE"
		elseif data.waveState == "BOSS" then stateDesc = "BOSS !"
		end

		waveInfoLabel.Text = string.format("VAGUE %d (%ds) | %d ENNEMIS", data.wave, data.waveTimer or 0, data.activeEnemies or 0)
	end

	-- Populate 3-Row Inventory Slots
	if data.weapons then
		local wList: { { name: string, rank: number, tag: string?, icon: string? } } = {}
		for wId, rank in pairs(data.weapons) do
			local wDef = WeaponsData.GetWeapon(wId)
			table.insert(wList, {
				name = if wDef then wDef.name else wId,
				rank = rank,
				tag = if wDef and wDef.tag then string.gsub(wDef.tag, "[%[%]%s]", "") else string.sub(wId, 1, 4):upper(),
				icon = if wDef then wDef.icon else nil,
			})
		end
		populateRowSlots(weaponSlots, 6, Color3.fromRGB(255, 80, 80), wList)
	end

	if data.passives then
		local pList: { { name: string, rank: number, tag: string?, icon: string? } } = {}
		for _, p in ipairs(data.passives) do
			table.insert(pList, {
				name = p.name or "Passif",
				rank = 1,
				tag = "PASF",
				icon = p.icon,
			})
		end
		populateRowSlots(passiveSlots, 6, Color3.fromRGB(200, 150, 255), pList)
	end

	if data.stats then
		local sList: { { name: string, rank: number, tag: string?, icon: string? } } = {}
		local statEntries = { "MaxHP", "Speed", "DamageMultiplier", "Armor", "LifeSteal", "RangeMultiplier" }
		for _, sKey in ipairs(statEntries) do
			if data.stats[sKey] then
				local conf = StatTypes.STAT_CONFIG[sKey]
				local tag = if conf and conf.tag then string.gsub(conf.tag, "[%[%]%s]", "") else string.sub(sKey, 1, 4):upper()
				table.insert(sList, {
					name = sKey,
					rank = math.floor(data.stats[sKey]),
					tag = tag,
					icon = if conf then conf.icon else nil,
				})
			end
		end
		populateRowSlots(statSlots, 6, Color3.fromRGB(50, 255, 120), sList)
	end
end)
