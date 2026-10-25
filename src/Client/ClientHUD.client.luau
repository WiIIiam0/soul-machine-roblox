--!strict
-- ClientHUD.client.luau: Faithful Cyberpunk HUD with Responsive UIScale, 3-Row Inventory, Meta-Progression, and Level-Up Cards

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local WeaponsData = require(Shared:WaitForChild("WeaponsData"))
local StatTypes = require(Shared:WaitForChild("StatTypes"))
local MetaProgressionData = require(Shared:WaitForChild("MetaProgressionData"))

-- Create Main ScreenGui (respects Roblox TopBar so HUD elements NEVER overlap Roblox buttons)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SoulMachineHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = false
screenGui.Parent = playerGui

-- Dedicated Fullscreen VFX ScreenGui (covers true physical screen without clipping)
local vfxGui = Instance.new("ScreenGui")
vfxGui.Name = "SoulMachineVFX"
vfxGui.ResetOnSpawn = false
vfxGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
vfxGui.IgnoreGuiInset = true
vfxGui.Parent = playerGui

-- --- MASTER RESPONSIVE SCALING ENGINE (UIScale) ---
local masterScale = Instance.new("UIScale")
masterScale.Name = "MasterScale"
masterScale.Parent = screenGui

local function isPortraitMode(): boolean
	local cam = Workspace.CurrentCamera
	if not cam then return false end
	local vp = cam.ViewportSize
	return (vp.X < vp.Y) or (vp.X < 720)
end

-- --- 1. FULLSCREEN DAMAGE FLASH (Vignette) ---
local damageFlash = Instance.new("Frame")
damageFlash.Name = "DamageFlash"
damageFlash.Size = UDim2.new(1, 0, 1, 0)
damageFlash.BackgroundColor3 = Color3.fromRGB(220, 20, 30)
damageFlash.BackgroundTransparency = 1
damageFlash.BorderSizePixel = 0
damageFlash.ZIndex = 50
damageFlash.Parent = vfxGui

local function triggerDamageFlash()
	damageFlash.BackgroundTransparency = 0.65
	local tw = TweenService:Create(damageFlash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	tw:Play()
end

-- --- 2. TOP-CENTER: XP, ZONE & WAVE TRACKER (In-Run) ---
local topBarContainer = Instance.new("Frame")
topBarContainer.Name = "TopBarContainer"
topBarContainer.Size = UDim2.new(0, 560, 0, 44)
topBarContainer.AnchorPoint = Vector2.new(0.5, 0)
topBarContainer.Position = UDim2.new(0.5, 0, 0, 16)
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

-- Level Badge (In-run)
local levelBadge = Instance.new("TextLabel")
levelBadge.Name = "LevelBadge"
levelBadge.Size = UDim2.new(0, 75, 1, 0)
levelBadge.BackgroundTransparency = 1
levelBadge.TextColor3 = Color3.fromRGB(0, 240, 255)
levelBadge.Font = Enum.Font.GothamBlack
levelBadge.TextSize = 13
levelBadge.Text = "NIV. 1"
levelBadge.Parent = topBarContainer

-- XP Bar (In-run)
local xpBarBg = Instance.new("Frame")
xpBarBg.Name = "XPBarBg"
xpBarBg.Size = UDim2.new(1, -315, 0, 14)
xpBarBg.Position = UDim2.new(0, 80, 0.5, -7)
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

-- Zone, Wave & Enemies Tracker
local waveInfoLabel = Instance.new("TextLabel")
waveInfoLabel.Name = "WaveInfoLabel"
waveInfoLabel.Size = UDim2.new(0, 225, 1, 0)
waveInfoLabel.Position = UDim2.new(1, -230, 0, 0)
waveInfoLabel.BackgroundTransparency = 1
waveInfoLabel.TextColor3 = Color3.fromRGB(255, 210, 50)
waveInfoLabel.Font = Enum.Font.GothamBlack
waveInfoLabel.TextSize = 11
waveInfoLabel.Text = "ZONE 1 • VAGUE 1 (35s) | 0 FOES"
waveInfoLabel.Parent = topBarContainer

-- --- 2B. TOP-CENTER: META-PROGRESSION TRACKER (Compte Global) ---
local metaBarContainer = Instance.new("Frame")
metaBarContainer.Name = "MetaBarContainer"
metaBarContainer.Size = UDim2.new(0, 480, 0, 24)
metaBarContainer.AnchorPoint = Vector2.new(0.5, 0)
metaBarContainer.Position = UDim2.new(0.5, 0, 0, 66)
metaBarContainer.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
metaBarContainer.BackgroundTransparency = 0.35
metaBarContainer.BorderSizePixel = 0
metaBarContainer.Parent = screenGui

local metaCorner = Instance.new("UICorner")
metaCorner.CornerRadius = UDim.new(0, 6)
metaCorner.Parent = metaBarContainer

local metaStroke = Instance.new("UIStroke")
metaStroke.Color = Color3.fromRGB(255, 200, 40)
metaStroke.Thickness = 1.2
metaStroke.Transparency = 0.5
metaStroke.Parent = metaBarContainer

local metaLevelLabel = Instance.new("TextLabel")
metaLevelLabel.Name = "MetaLevelLabel"
metaLevelLabel.Size = UDim2.new(0, 125, 1, 0)
metaLevelLabel.Position = UDim2.new(0, 8, 0, 0)
metaLevelLabel.BackgroundTransparency = 1
metaLevelLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
metaLevelLabel.Font = Enum.Font.GothamBlack
metaLevelLabel.TextSize = 10
metaLevelLabel.TextXAlignment = Enum.TextXAlignment.Left
metaLevelLabel.Text = "ADN : 0 XP"
metaLevelLabel.Parent = metaBarContainer

local metaXPBarBg = Instance.new("Frame")
metaXPBarBg.Name = "MetaXPBarBg"
metaXPBarBg.Size = UDim2.new(1, -255, 0, 10)
metaXPBarBg.Position = UDim2.new(0, 130, 0.5, -5)
metaXPBarBg.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
metaXPBarBg.BorderSizePixel = 0
metaXPBarBg.Parent = metaBarContainer

local metaXPCorner = Instance.new("UICorner")
metaXPCorner.CornerRadius = UDim.new(0.5, 0)
metaXPCorner.Parent = metaXPBarBg

local metaXPBarFill = Instance.new("Frame")
metaXPBarFill.Name = "Fill"
metaXPBarFill.Size = UDim2.new(0, 0, 1, 0)
metaXPBarFill.BackgroundColor3 = Color3.fromRGB(255, 180, 20)
metaXPBarFill.BorderSizePixel = 0
metaXPBarFill.Parent = metaXPBarBg

local metaXPFillCorner = Instance.new("UICorner")
metaXPFillCorner.CornerRadius = UDim.new(0.5, 0)
metaXPFillCorner.Parent = metaXPBarFill

local metaXPText = Instance.new("TextLabel")
metaXPText.Name = "MetaXPText"
metaXPText.Size = UDim2.new(1, 0, 1, 0)
metaXPText.BackgroundTransparency = 1
metaXPText.TextColor3 = Color3.fromRGB(255, 255, 255)
metaXPText.Font = Enum.Font.GothamBold
metaXPText.TextSize = 8
metaXPText.Text = "0 / 522 ADN"
metaXPText.Parent = metaXPBarBg

local metaSlotsLabel = Instance.new("TextLabel")
metaSlotsLabel.Name = "MetaSlotsLabel"
metaSlotsLabel.Size = UDim2.new(0, 120, 1, 0)
metaSlotsLabel.Position = UDim2.new(1, -125, 0, 0)
metaSlotsLabel.BackgroundTransparency = 1
metaSlotsLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
metaSlotsLabel.Font = Enum.Font.GothamBold
metaSlotsLabel.TextSize = 9
metaSlotsLabel.Text = "SLOTS : 1 ARM | 1 PAS | 1 STAT"
metaSlotsLabel.Parent = metaBarContainer

-- --- 3. TOP-LEFT: 3-ROW INVENTORY (ARMES, PASSIFS, STATS avec Emplacements Verrouillés) ---
local invContainer = Instance.new("Frame")
invContainer.Name = "InventoryContainer"
invContainer.Size = UDim2.new(0, 310, 0, 134)
invContainer.Position = UDim2.new(0, 18, 0, 16)
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
	label.TextSize = 11
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

local weaponsRow, weaponSlots = createInvRow("Weapons", "ARMES", Color3.fromRGB(255, 100, 100), 8)
local _, passiveSlots = createInvRow("Passives", "PASSIFS", Color3.fromRGB(200, 150, 255), 48)
local _, statSlots = createInvRow("Stats", "STATS", Color3.fromRGB(100, 255, 150), 88)

-- Temporary Starter Gun Box (matches Unity tempWeaponBox in UIManager.cs)
local tempWeaponBox = Instance.new("Frame")
tempWeaponBox.Name = "TempWeaponBox"
tempWeaponBox.Size = UDim2.new(0, 30, 0, 30)
tempWeaponBox.Position = UDim2.new(0, 75, 0, 1)
tempWeaponBox.BackgroundColor3 = Color3.fromRGB(24, 20, 12)
tempWeaponBox.BorderSizePixel = 0
tempWeaponBox.Visible = false
tempWeaponBox.Parent = weaponsRow

local twbCorner = Instance.new("UICorner")
twbCorner.CornerRadius = UDim.new(0, 6)
twbCorner.Parent = tempWeaponBox

local twbStroke = Instance.new("UIStroke")
twbStroke.Color = Color3.fromRGB(255, 180, 50)
twbStroke.Thickness = 1.2
twbStroke.Transparency = 0.25
twbStroke.Parent = tempWeaponBox

local twbIcon = Instance.new("ImageLabel")
twbIcon.Name = "Icon"
twbIcon.Size = UDim2.new(1, -4, 1, -4)
twbIcon.Position = UDim2.new(0, 2, 0, 2)
twbIcon.BackgroundTransparency = 1
twbIcon.ZIndex = 2
twbIcon.Parent = tempWeaponBox

local twbTag = Instance.new("TextLabel")
twbTag.Name = "Tag"
twbTag.Size = UDim2.new(1, 0, 0, 10)
twbTag.Position = UDim2.new(0, 0, 1, -10)
twbTag.BackgroundColor3 = Color3.fromRGB(12, 10, 8)
twbTag.BackgroundTransparency = 0.2
twbTag.TextColor3 = Color3.fromRGB(255, 200, 70)
twbTag.Font = Enum.Font.GothamBold
twbTag.TextSize = 7
twbTag.Text = "INIT"
twbTag.ZIndex = 3
twbTag.Parent = tempWeaponBox

-- Texture resolution cache
local textureCache: { [string]: string } = {}

local function extractTextureString(inst: Instance): string?
	if inst:IsA("Decal") or inst:IsA("Texture") then
		if inst.Texture and inst.Texture ~= "" then return inst.Texture end
	elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		if inst.Image and inst.Image ~= "" then return inst.Image end
	elseif inst:IsA("StringValue") then
		if inst.Value and inst.Value ~= "" then return inst.Value end
	elseif inst:IsA("MeshPart") then
		if inst.TextureID and inst.TextureID ~= "" then return inst.TextureID end
	end
	return nil
end

local function resolveTexture(iconFile: string?, rawIcon: string?): string?
	if not iconFile or iconFile == "" then
		if rawIcon and rawIcon ~= "" and not string.find(rawIcon, "rbxassetid://10709791") then
			return rawIcon
		end
		return nil
	end

	local cleanName = string.gsub(iconFile, "%.png$", "")
	local cleanLower = string.lower(cleanName)

	if textureCache[cleanLower] then
		return textureCache[cleanLower]
	end

	local numMatch = string.match(cleanLower, "%d+_%d+$") or string.match(cleanLower, "%d+$")

	local candidates = {
		ReplicatedStorage:FindFirstChild("Icons"),
		ReplicatedStorage:FindFirstChild("Assets"),
		ReplicatedStorage:FindFirstChild("Images"),
		ReplicatedStorage:FindFirstChild("CustomCreeps"),
		ReplicatedStorage,
		Workspace:FindFirstChild("Icons"),
		Workspace:FindFirstChild("Assets"),
	}

	for _, folder in ipairs(candidates) do
		if folder then
			local found = folder:FindFirstChild(iconFile) or folder:FindFirstChild(cleanName)
			if found then
				local tex = extractTextureString(found)
				if tex then
					textureCache[cleanLower] = tex
					return tex
				end
			end
		end
	end

	for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
		local dLower = string.lower(string.gsub(desc.Name, "%.png$", ""))
		if dLower == cleanLower or string.find(dLower, cleanLower, 1, true) or (numMatch and string.find(dLower, numMatch, 1, true)) then
			local tex = extractTextureString(desc)
			if tex then
				textureCache[cleanLower] = tex
				return tex
			end
		end
	end

	for _, desc in ipairs(Workspace:GetDescendants()) do
		local dLower = string.lower(string.gsub(desc.Name, "%.png$", ""))
		if dLower == cleanLower or string.find(dLower, cleanLower, 1, true) or (numMatch and string.find(dLower, numMatch, 1, true)) then
			local tex = extractTextureString(desc)
			if tex then
				textureCache[cleanLower] = tex
				return tex
			end
		end
	end

	if rawIcon and rawIcon ~= "" and not string.find(rawIcon, "rbxassetid://10709791") then
		return rawIcon
	end

	return nil
end

local cachedTotalXP = 0
local cachedMaxTimelineXP = 522
local cachedNextUpcomingXP = 603
local cachedMaxWeaponSlots = 1
local cachedMaxPassiveSlots = 1
local cachedMaxStatSlots = 1
local cachedMaxWeaponRank = 1
local cachedMaxStatRank = 3

local cachedLastWeaponList: { any } = {}
local cachedLastPassiveList: { any } = {}
local cachedLastStatList: { any } = {}
local cachedHasTempWeapon = false

-- 100% Faithful to Unity UIManager.cs PopulateSlots & PopulatePassiveSlots
local function populateRowSlots(
	container: Frame,
	maxCount: number,
	borderColor: Color3,
	items: { { name: string, rank: number, maxRank: number?, tag: string?, glyph: string?, icon: string?, iconFile: string? } }
)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	for i = 1, maxCount do
		local box = Instance.new("Frame")
		box.Name = "Slot_" .. i
		box.Size = UDim2.new(0, 30, 0, 30)
		box.Position = UDim2.new(0, (i - 1) * 34, 0, 1)
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
			-- Slot Filled (slot-filled in Unity)
			bStroke.Color = borderColor
			bStroke.Transparency = 0.2
			box.BackgroundColor3 = Color3.fromRGB(22, 30, 48)

			local tagLabel = Instance.new("TextLabel")
			tagLabel.Name = "Tag"
			tagLabel.Size = UDim2.new(1, -2, 1, -2)
			tagLabel.Position = UDim2.new(0, 1, 0, 1)
			tagLabel.BackgroundTransparency = 1
			tagLabel.TextColor3 = borderColor
			tagLabel.Font = Enum.Font.GothamBlack
			tagLabel.TextSize = 8
			tagLabel.Text = item.tag or item.glyph or string.sub(item.name, 1, 4):upper()
			tagLabel.ZIndex = 1
			tagLabel.Parent = box

			local resolved = resolveTexture(item.iconFile, item.icon)
			if resolved and resolved ~= "" then
				local iconImg = Instance.new("ImageLabel")
				iconImg.Size = UDim2.new(1, -4, 1, -4)
				iconImg.Position = UDim2.new(0, 2, 0, 2)
				iconImg.BackgroundTransparency = 1
				iconImg.Image = resolved
				iconImg.ZIndex = 2
				iconImg.Parent = box
				tagLabel.Visible = false
			end

			-- Rank text badge (matching levelTexts "X/X" in Unity UIManager.cs)
			if item.rank and item.rank > 0 then
				local rankBadge = Instance.new("TextLabel")
				rankBadge.Name = "RankBadge"
				rankBadge.Size = UDim2.new(0, 18, 0, 11)
				rankBadge.Position = UDim2.new(1, -19, 1, -11)
				rankBadge.BackgroundColor3 = Color3.fromRGB(10, 15, 25)
				rankBadge.BackgroundTransparency = 0.2
				rankBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
				rankBadge.Font = Enum.Font.GothamBold
				rankBadge.TextSize = 8
				rankBadge.Text = if item.maxRank and item.maxRank > 1 then string.format("%d/%d", item.rank, item.maxRank) else tostring(item.rank)
				rankBadge.ZIndex = 3
				rankBadge.Parent = box

				local rCorner = Instance.new("UICorner")
				rCorner.CornerRadius = UDim.new(0, 3)
				rCorner.Parent = rankBadge
			end
		else
			-- Empty Slot (slot-empty in Unity): Dark sleek frame ready to receive an item
			box.BackgroundColor3 = Color3.fromRGB(12, 15, 24)
			bStroke.Color = Color3.fromRGB(45, 55, 75)
			bStroke.Transparency = 0.65
		end
	end
end

-- --- 4. FLOATING OVERHEAD VITALS (Mirroring Unity UIManager.cs floatingHealthBar, floatingXpBar, floatingOverdriveBar) ---
local overheadGui: BillboardGui? = nil
local overheadHpFill: Frame? = nil
local overheadHpNotches: Frame? = nil
local overheadXpFill: Frame? = nil
local overheadXpNotches: Frame? = nil
local overheadOdFill: Frame? = nil

local lastExpectedHpNotches = -1
local function updateHpNotches(maxHp: number)
	local notchesCount = math.floor(maxHp / 20)
	if notchesCount == lastExpectedHpNotches or not overheadHpNotches then return end
	lastExpectedHpNotches = notchesCount
	overheadHpNotches:ClearAllChildren()
	for i = 1, notchesCount - 1 do
		local line = Instance.new("Frame")
		line.Size = UDim2.new(0, 1, 1, 0)
		line.Position = UDim2.new(i / notchesCount, 0, 0, 0)
		line.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		line.BackgroundTransparency = 0.4
		line.BorderSizePixel = 0
		line.Parent = overheadHpNotches
	end
end

local lastExpectedXpNotches = -1
local function updateXpNotches(maxXp: number)
	local notchesCount = math.floor(maxXp / 10)
	if notchesCount == lastExpectedXpNotches or not overheadXpNotches then return end
	lastExpectedXpNotches = notchesCount
	overheadXpNotches:ClearAllChildren()
	for i = 1, notchesCount - 1 do
		local line = Instance.new("Frame")
		line.Size = UDim2.new(0, 1, 1, 0)
		line.Position = UDim2.new(i / notchesCount, 0, 0, 0)
		line.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		line.BackgroundTransparency = 0.5
		line.BorderSizePixel = 0
		line.Parent = overheadXpNotches
	end
end

local function setupOverheadVitals(char: Model)
	local hrp = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not hrp then return end

	local old = hrp:FindFirstChild("PlayerFloatingVitals")
	if old then old:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Name = "PlayerFloatingVitals"
	bb.Adornee = hrp
	bb.Size = UDim2.new(0, 85, 0, 22)
	bb.StudsOffset = Vector3.new(0, 3.8, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 200
	bb.ResetOnSpawn = false
	bb.Parent = hrp

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.Parent = bb

	-- 1. Health Bar (top, 8px)
	local hpBg = Instance.new("Frame")
	hpBg.Name = "HPBar"
	hpBg.LayoutOrder = 1
	hpBg.Size = UDim2.new(1, 0, 0, 8)
	hpBg.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	hpBg.BorderSizePixel = 0
	hpBg.Parent = bb

	local hpCorner = Instance.new("UICorner")
	hpCorner.CornerRadius = UDim.new(0, 2)
	hpCorner.Parent = hpBg

	local hpFill = Instance.new("Frame")
	hpFill.Name = "Fill"
	hpFill.Size = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = Color3.fromRGB(50, 220, 70)
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBg

	local hpFillCorner = Instance.new("UICorner")
	hpFillCorner.CornerRadius = UDim.new(0, 2)
	hpFillCorner.Parent = hpFill

	local hpNotches = Instance.new("Frame")
	hpNotches.Name = "Notches"
	hpNotches.Size = UDim2.new(1, 0, 1, 0)
	hpNotches.BackgroundTransparency = 1
	hpNotches.Parent = hpBg

	-- 2. XP Bar (middle, 4px)
	local xpBg = Instance.new("Frame")
	xpBg.Name = "XPBar"
	xpBg.LayoutOrder = 2
	xpBg.Size = UDim2.new(1, 0, 0, 4)
	xpBg.BackgroundColor3 = Color3.fromRGB(10, 15, 25)
	xpBg.BorderSizePixel = 0
	xpBg.Parent = bb

	local xpCorner = Instance.new("UICorner")
	xpCorner.CornerRadius = UDim.new(0, 2)
	xpCorner.Parent = xpBg

	local xpFill = Instance.new("Frame")
	xpFill.Name = "Fill"
	xpFill.Size = UDim2.new(0, 0, 1, 0)
	xpFill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
	xpFill.BorderSizePixel = 0
	xpFill.Parent = xpBg

	local xpNotches = Instance.new("Frame")
	xpNotches.Name = "Notches"
	xpNotches.Size = UDim2.new(1, 0, 1, 0)
	xpNotches.BackgroundTransparency = 1
	xpNotches.Parent = xpBg

	-- 3. Overdrive Bar (bottom, 4px)
	local odBg = Instance.new("Frame")
	odBg.Name = "ODBar"
	odBg.LayoutOrder = 3
	odBg.Size = UDim2.new(1, 0, 0, 4)
	odBg.BackgroundColor3 = Color3.fromRGB(20, 15, 10)
	odBg.BorderSizePixel = 0
	odBg.Parent = bb

	local odCorner = Instance.new("UICorner")
	odCorner.CornerRadius = UDim.new(0, 2)
	odCorner.Parent = odBg

	local odFill = Instance.new("Frame")
	odFill.Name = "Fill"
	odFill.Size = UDim2.new(0, 0, 1, 0)
	odFill.BackgroundColor3 = Color3.fromRGB(255, 140, 20)
	odFill.BorderSizePixel = 0
	odFill.Parent = odBg

	overheadGui = bb
	overheadHpFill = hpFill
	overheadHpNotches = hpNotches
	overheadXpFill = xpFill
	overheadXpNotches = xpNotches
	overheadOdFill = odFill
	lastExpectedHpNotches = -1
	lastExpectedXpNotches = -1
end

if player.Character then
	setupOverheadVitals(player.Character)
end
player.CharacterAdded:Connect(setupOverheadVitals)

-- Minimal Vitals Container (Invisible by default to leave the screen clean like Unity)
local vitalsContainer = Instance.new("Frame")
vitalsContainer.Name = "VitalsContainer"
vitalsContainer.Visible = false
vitalsContainer.Parent = screenGui

local hpBarBg = Instance.new("Frame")
local hpBarFill = Instance.new("Frame")
local hpText = Instance.new("TextLabel")
local armorText = Instance.new("TextLabel")

-- --- 5. BOTTOM CENTER: OVERDRIVE REACTOR ---
local odContainer = Instance.new("Frame")
odContainer.Name = "OverdriveContainer"
odContainer.Size = UDim2.new(0, 320, 0, 52)
odContainer.AnchorPoint = Vector2.new(0.5, 0.5)
odContainer.Position = UDim2.new(0.5, 0, 1, -54)
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

-- --- 6. LEVEL UP MODAL AVEC CENTRAGE RESPONSIVE ET COMPTE À REBOURS ---
local levelUpModal = Instance.new("Frame")
levelUpModal.Name = "LevelUpModal"
levelUpModal.Size = UDim2.new(1, 0, 1, 0)
levelUpModal.BackgroundColor3 = Color3.fromRGB(8, 12, 24)
levelUpModal.BackgroundTransparency = 0.15
levelUpModal.Visible = false
levelUpModal.ZIndex = 100
levelUpModal.Parent = screenGui

local modalTitle = Instance.new("TextLabel")
modalTitle.Name = "Title"
modalTitle.Size = UDim2.new(1, 0, 0, 40)
modalTitle.Position = UDim2.new(0.5, 0, 0, 36)
modalTitle.AnchorPoint = Vector2.new(0.5, 0)
modalTitle.BackgroundTransparency = 1
modalTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
modalTitle.Font = Enum.Font.GothamBlack
modalTitle.TextSize = 32
modalTitle.Text = "NIVEAU SUPÉRIEUR"
modalTitle.Parent = levelUpModal

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "Subtitle"
subtitleLabel.Size = UDim2.new(1, 0, 0, 22)
subtitleLabel.Position = UDim2.new(0.5, 0, 0, 78)
subtitleLabel.AnchorPoint = Vector2.new(0.5, 0)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
subtitleLabel.Font = Enum.Font.GothamMedium
subtitleLabel.TextSize = 15
subtitleLabel.Text = "Choisissez une amélioration pour votre Mécha"
subtitleLabel.Parent = levelUpModal

-- Compte à rebours
local timerContainer = Instance.new("Frame")
timerContainer.Name = "TimerContainer"
timerContainer.Size = UDim2.new(0, 340, 0, 24)
timerContainer.Position = UDim2.new(0.5, 0, 0, 106)
timerContainer.AnchorPoint = Vector2.new(0.5, 0)
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
cardsHolder.Position = UDim2.new(0.5, 0, 0.58, 0)
cardsHolder.AnchorPoint = Vector2.new(0.5, 0.5)
cardsHolder.BackgroundTransparency = 1
cardsHolder.Parent = levelUpModal

local cardsLayout = Instance.new("UIListLayout")
cardsLayout.Name = "CardsLayout"
cardsLayout.FillDirection = Enum.FillDirection.Horizontal
cardsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
cardsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
cardsLayout.Padding = UDim.new(0, 22)
cardsLayout.Parent = cardsHolder

-- --- MASTER RESPONSIVE LAYOUT ENGINE (Portrait Mobile & Landscape PC) ---
local function applyResponsiveLayout()
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	if vp.X <= 0 or vp.Y <= 0 then return end

	local isPortrait = (vp.X < vp.Y) or (vp.X < 720)

	if isPortrait then
		-- Mobile Portrait Adaptive Scale
		masterScale.Scale = math.clamp(vp.X / 440, 0.72, 1.15)

		-- Top-Center In-Run Bar
		topBarContainer.AnchorPoint = Vector2.new(0.5, 0)
		topBarContainer.Position = UDim2.new(0.5, 0, 0, 4)
		topBarContainer.Size = UDim2.new(0.96, 0, 0, 38)
		levelBadge.Size = UDim2.new(0, 56, 1, 0)
		levelBadge.TextSize = 11
		xpBarBg.Position = UDim2.new(0, 60, 0.5, -6)
		xpBarBg.Size = UDim2.new(1, -195, 0, 12)
		waveInfoLabel.Size = UDim2.new(0, 130, 1, 0)
		waveInfoLabel.Position = UDim2.new(1, -132, 0, 0)
		waveInfoLabel.TextSize = 9

		-- Meta Progression Bar
		metaBarContainer.AnchorPoint = Vector2.new(0.5, 0)
		metaBarContainer.Position = UDim2.new(0.5, 0, 0, 44)
		metaBarContainer.Size = UDim2.new(0.96, 0, 0, 22)
		metaLevelLabel.Size = UDim2.new(0, 95, 1, 0)
		metaLevelLabel.TextSize = 9
		metaXPBarBg.Position = UDim2.new(0, 100, 0.5, -4)
		metaXPBarBg.Size = UDim2.new(1, -195, 0, 8)
		metaSlotsLabel.Size = UDim2.new(0, 90, 1, 0)
		metaSlotsLabel.Position = UDim2.new(1, -92, 0, 0)
		metaSlotsLabel.TextSize = 8

		-- 3-Row Inventory (Centered below Meta Bar)
		invContainer.AnchorPoint = Vector2.new(0.5, 0)
		invContainer.Position = UDim2.new(0.5, 0, 0, 70)
		invContainer.Size = UDim2.new(0.96, 0, 0, 102)

		-- Vitals Bar (Bottom Left)
		vitalsContainer.AnchorPoint = Vector2.new(0, 1)
		vitalsContainer.Position = UDim2.new(0, 8, 1, -8)
		vitalsContainer.Size = UDim2.new(0.52, 0, 0, 52)
		hpBarBg.Size = UDim2.new(1, -16, 0, 15)
		hpBarBg.Position = UDim2.new(0, 8, 0, 6)
		hpText.TextSize = 10
		armorText.Position = UDim2.new(0, 8, 0, 26)
		armorText.TextSize = 9

		-- Overdrive Reactor (Bottom Right)
		odContainer.AnchorPoint = Vector2.new(1, 1)
		odContainer.Position = UDim2.new(1, -8, 1, -8)
		odContainer.Size = UDim2.new(0.44, 0, 0, 52)
		odBarBg.Size = UDim2.new(1, -14, 0, 15)
		odBarBg.Position = UDim2.new(0, 7, 0, 6)
		odBtn.Position = UDim2.new(0, 7, 0, 24)
		odBtn.TextSize = 9

		-- Level Up Modal Title & Cards
		modalTitle.Position = UDim2.new(0.5, 0, 0, 16)
		modalTitle.TextSize = 22
		subtitleLabel.Position = UDim2.new(0.5, 0, 0, 44)
		subtitleLabel.TextSize = 12
		timerContainer.Position = UDim2.new(0.5, 0, 0, 72)
		timerContainer.Size = UDim2.new(0.90, 0, 0, 20)

		cardsHolder.AnchorPoint = Vector2.new(0.5, 0)
		cardsHolder.Position = UDim2.new(0.5, 0, 0, 98)
		cardsHolder.Size = UDim2.new(0.96, 0, 1, -106)
		cardsLayout.FillDirection = Enum.FillDirection.Vertical
		cardsLayout.Padding = UDim.new(0, 8)

	else
		-- Desktop / Landscape Reference Scale
		local scaleX = vp.X / 1366
		local scaleY = vp.Y / 768
		masterScale.Scale = math.clamp(math.min(scaleX, scaleY), 0.65, 1.35)

		-- Top-Center In-Run Bar
		topBarContainer.AnchorPoint = Vector2.new(0.5, 0)
		topBarContainer.Position = UDim2.new(0.5, 0, 0, 14)
		topBarContainer.Size = UDim2.new(0, 560, 0, 44)
		levelBadge.Size = UDim2.new(0, 75, 1, 0)
		levelBadge.TextSize = 13
		xpBarBg.Position = UDim2.new(0, 80, 0.5, -7)
		xpBarBg.Size = UDim2.new(1, -315, 0, 14)
		waveInfoLabel.Size = UDim2.new(0, 225, 1, 0)
		waveInfoLabel.Position = UDim2.new(1, -230, 0, 0)
		waveInfoLabel.TextSize = 11

		-- Meta Progression Bar
		metaBarContainer.AnchorPoint = Vector2.new(0.5, 0)
		metaBarContainer.Position = UDim2.new(0.5, 0, 0, 64)
		metaBarContainer.Size = UDim2.new(0, 480, 0, 24)
		metaLevelLabel.Size = UDim2.new(0, 125, 1, 0)
		metaLevelLabel.TextSize = 10
		metaXPBarBg.Position = UDim2.new(0, 130, 0.5, -5)
		metaXPBarBg.Size = UDim2.new(1, -255, 0, 10)
		metaSlotsLabel.Size = UDim2.new(0, 120, 1, 0)
		metaSlotsLabel.Position = UDim2.new(1, -125, 0, 0)
		metaSlotsLabel.TextSize = 9

		-- 3-Row Inventory (Top Left)
		invContainer.AnchorPoint = Vector2.new(0, 0)
		invContainer.Position = UDim2.new(0, 18, 0, 14)
		invContainer.Size = UDim2.new(0, 310, 0, 134)

		-- Vitals Bar (Bottom Left)
		vitalsContainer.AnchorPoint = Vector2.new(0, 1)
		vitalsContainer.Position = UDim2.new(0, 24, 1, -24)
		vitalsContainer.Size = UDim2.new(0, 260, 0, 60)
		hpBarBg.Size = UDim2.new(1, -20, 0, 18)
		hpBarBg.Position = UDim2.new(0, 10, 0, 8)
		hpText.TextSize = 11
		armorText.Position = UDim2.new(0, 10, 0, 32)
		armorText.TextSize = 11

		-- Overdrive Reactor (Bottom Center)
		odContainer.AnchorPoint = Vector2.new(0.5, 1)
		odContainer.Position = UDim2.new(0.5, 0, 1, -24)
		odContainer.Size = UDim2.new(0, 320, 0, 52)
		odBarBg.Size = UDim2.new(1, -20, 0, 18)
		odBarBg.Position = UDim2.new(0, 10, 0, 8)
		odBtn.Position = UDim2.new(0, 10, 0, 28)
		odBtn.TextSize = 11

		-- Level Up Modal Title & Cards
		modalTitle.Position = UDim2.new(0.5, 0, 0, 36)
		modalTitle.TextSize = 32
		subtitleLabel.Position = UDim2.new(0.5, 0, 0, 78)
		subtitleLabel.TextSize = 15
		timerContainer.Position = UDim2.new(0.5, 0, 0, 106)
		timerContainer.Size = UDim2.new(0, 340, 0, 24)

		cardsHolder.AnchorPoint = Vector2.new(0.5, 0.5)
		cardsHolder.Position = UDim2.new(0.5, 0, 0.58, 0)
		cardsHolder.Size = UDim2.new(0, 940, 0, 420)
		cardsLayout.FillDirection = Enum.FillDirection.Horizontal
		cardsLayout.Padding = UDim.new(0, 22)
	end
end

local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
	applyResponsiveLayout()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local newCam = Workspace.CurrentCamera
	if newCam then
		newCam:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
		applyResponsiveLayout()
	end
end)

local countdownRemaining = 15.0
local countdownActive = false

local function createChoiceCard(index: number, cardData: any): Frame
	local isPortrait = isPortraitMode()

	local card = Instance.new("Frame")
	card.Name = "Card_" .. index
	card.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = cardsHolder

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, if isPortrait then 12 else 20)
	cCorner.Parent = card

	local cStroke = Instance.new("UIStroke")
	cStroke.Color = cardData.rarityColor or Color3.fromRGB(0, 200, 255)
	cStroke.Thickness = 2.0
	cStroke.Parent = card

	if isPortrait then
		-- Mobile Portrait Card (Horizontal banner style)
		card.Size = UDim2.new(1, 0, 0, 106)

		-- Category Badge (Top Left)
		local categoryBadge = Instance.new("TextLabel")
		categoryBadge.Name = "CategoryBadge"
		categoryBadge.Size = UDim2.new(0, 75, 0, 16)
		categoryBadge.Position = UDim2.new(0, 10, 0, 6)
		categoryBadge.BackgroundColor3 = Color3.fromRGB(10, 20, 30)
		categoryBadge.TextColor3 = cardData.rarityColor or Color3.fromRGB(255, 255, 255)
		categoryBadge.Font = Enum.Font.GothamBlack
		categoryBadge.TextSize = 9
		categoryBadge.Text = cardData.category or "UPGRADE"
		categoryBadge.Parent = card

		local catCorner = Instance.new("UICorner")
		catCorner.CornerRadius = UDim.new(0, 4)
		catCorner.Parent = categoryBadge

		-- Icon Box (Left side)
		local iconBox = Instance.new("Frame")
		iconBox.Name = "IconBox"
		iconBox.Size = UDim2.new(0, 58, 0, 58)
		iconBox.Position = UDim2.new(0, 10, 0, 28)
		iconBox.BackgroundColor3 = Color3.fromRGB(10, 20, 40)
		iconBox.BorderSizePixel = 0
		iconBox.Parent = card

		local iCorner = Instance.new("UICorner")
		iCorner.CornerRadius = UDim.new(0, 8)
		iCorner.Parent = iconBox

		local iStroke = Instance.new("UIStroke")
		iStroke.Color = cardData.rarityColor or Color3.fromRGB(0, 200, 255)
		iStroke.Thickness = 1.5
		iStroke.Parent = iconBox

		local iconBadge = Instance.new("TextLabel")
		iconBadge.Name = "IconBadge"
		iconBadge.Size = UDim2.new(1, -4, 1, -4)
		iconBadge.Position = UDim2.new(0, 2, 0, 2)
		iconBadge.BackgroundTransparency = 1
		iconBadge.Text = cardData.tag or string.sub(cardData.title, 1, 10):upper()
		iconBadge.TextColor3 = cardData.rarityColor
		iconBadge.Font = Enum.Font.GothamBlack
		iconBadge.TextSize = 9
		iconBadge.TextWrapped = true
		iconBadge.ZIndex = 1
		iconBadge.Parent = iconBox

		local resolvedImage = resolveTexture(cardData.iconFile, cardData.icon)
		if resolvedImage and resolvedImage ~= "" then
			local iconImg = Instance.new("ImageLabel")
			iconImg.Size = UDim2.new(1, -6, 1, -6)
			iconImg.Position = UDim2.new(0, 3, 0, 3)
			iconImg.BackgroundTransparency = 1
			iconImg.Image = resolvedImage
			iconImg.ZIndex = 2
			iconImg.Parent = iconBox
			iconBadge.Visible = false
		end

		-- Title
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, -195, 0, 18)
		title.Position = UDim2.new(0, 78, 0, 8)
		title.BackgroundTransparency = 1
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.Font = Enum.Font.GothamBlack
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.Text = cardData.title
		title.Parent = card

		-- SubLabel
		local subLabel = Instance.new("TextLabel")
		subLabel.Name = "SubLabel"
		subLabel.Size = UDim2.new(1, -195, 0, 16)
		subLabel.Position = UDim2.new(0, 78, 0, 26)
		subLabel.BackgroundTransparency = 1
		subLabel.TextColor3 = cardData.rarityColor
		subLabel.Font = Enum.Font.GothamBold
		subLabel.TextSize = 10
		subLabel.TextXAlignment = Enum.TextXAlignment.Left
		subLabel.Text = cardData.subtitle or ""
		subLabel.Parent = card

		-- Description
		local desc = Instance.new("TextLabel")
		desc.Name = "Desc"
		desc.Size = UDim2.new(1, -195, 0, 52)
		desc.Position = UDim2.new(0, 78, 0, 44)
		desc.BackgroundTransparency = 1
		desc.TextColor3 = Color3.fromRGB(190, 215, 255)
		desc.Font = Enum.Font.Gotham
		desc.TextSize = 10
		desc.TextWrapped = true
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.Text = cardData.description or ""
		desc.Parent = card

		-- Select Button (Right side)
		local selectBtn = Instance.new("TextButton")
		selectBtn.Name = "SelectBtn"
		selectBtn.Size = UDim2.new(0, 95, 0, 38)
		selectBtn.Position = UDim2.new(1, -105, 0.5, -19)
		selectBtn.BackgroundColor3 = cardData.rarityColor or Color3.fromRGB(0, 200, 255)
		selectBtn.TextColor3 = Color3.fromRGB(10, 15, 25)
		selectBtn.Font = Enum.Font.GothamBlack
		selectBtn.TextSize = 12
		selectBtn.Text = "CHOISIR"
		selectBtn.Parent = card

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = selectBtn

		local function pickThis()
			if not countdownActive then return end
			countdownActive = false
			levelUpModal.Visible = false
			Remotes.GetEvent("SelectLevelUpChoice"):FireServer(index)
		end
		selectBtn.Activated:Connect(pickThis)

	else
		-- Desktop / Landscape Card (Vertical card style)
		card.Size = UDim2.new(0, 280, 0, 400)

		local categoryBadge = Instance.new("TextLabel")
		categoryBadge.Name = "CategoryBadge"
		categoryBadge.Size = UDim2.new(0, 130, 0, 28)
		categoryBadge.Position = UDim2.new(0.5, -65, 0, -14)
		categoryBadge.BackgroundColor3 = Color3.fromRGB(10, 20, 30)
		categoryBadge.TextColor3 = cardData.rarityColor or Color3.fromRGB(255, 255, 255)
		categoryBadge.Font = Enum.Font.GothamBlack
		categoryBadge.TextSize = 11
		categoryBadge.Text = cardData.category or "UPGRADE"
		categoryBadge.Parent = card

		local catCorner = Instance.new("UICorner")
		catCorner.CornerRadius = UDim.new(0, 8)
		catCorner.Parent = categoryBadge

		local catStroke = Instance.new("UIStroke")
		catStroke.Color = cardData.rarityColor or Color3.fromRGB(0, 200, 255)
		catStroke.Thickness = 1.5
		catStroke.Parent = categoryBadge

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, -24, 0, 48)
		title.Position = UDim2.new(0, 12, 0, 28)
		title.BackgroundTransparency = 1
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.Font = Enum.Font.GothamBlack
		title.TextSize = 16
		title.TextWrapped = true
		title.Text = cardData.title
		title.Parent = card

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
		iStroke.Color = cardData.rarityColor or Color3.fromRGB(0, 200, 255)
		iStroke.Thickness = 2
		iStroke.Transparency = 0.3
		iStroke.Parent = iconBox

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

		local resolvedImage = resolveTexture(cardData.iconFile, cardData.icon)
		if resolvedImage and resolvedImage ~= "" then
			local iconImg = Instance.new("ImageLabel")
			iconImg.Size = UDim2.new(1, -10, 1, -10)
			iconImg.Position = UDim2.new(0, 5, 0, 5)
			iconImg.BackgroundTransparency = 1
			iconImg.Image = resolvedImage
			iconImg.ZIndex = 2
			iconImg.Parent = iconBox
			iconBadge.Visible = false
		end

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

		local selectBtn = Instance.new("TextButton")
		selectBtn.Name = "SelectBtn"
		selectBtn.Size = UDim2.new(1, -30, 0, 42)
		selectBtn.Position = UDim2.new(0, 15, 1, -54)
		selectBtn.BackgroundColor3 = cardData.rarityColor or Color3.fromRGB(0, 200, 255)
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
	end

	return card
end

-- Open Level Up Screen
Remotes.GetEvent("LevelUpOptions").OnClientEvent:Connect(function(cards: { any })
	for _, child in ipairs(cardsHolder:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	for idx, cardData in ipairs(cards) do
		if idx <= 3 then
			createChoiceCard(idx, cardData)
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
			Remotes.GetEvent("SelectLevelUpChoice"):FireServer(1)
		end
	end
end)

-- --- 7. NOTIFICATION BANNER: GLOBAL LEVEL UP ---
local globalLevelUpBanner = Instance.new("Frame")
globalLevelUpBanner.Name = "GlobalLevelUpBanner"
globalLevelUpBanner.Size = UDim2.new(0, 560, 0, 88)
globalLevelUpBanner.Position = UDim2.new(0.5, 0, 0, -110)
globalLevelUpBanner.AnchorPoint = Vector2.new(0.5, 0)
globalLevelUpBanner.BackgroundColor3 = Color3.fromRGB(16, 22, 36)
globalLevelUpBanner.BackgroundTransparency = 0.08
globalLevelUpBanner.BorderSizePixel = 0
globalLevelUpBanner.ZIndex = 200
globalLevelUpBanner.Visible = false
globalLevelUpBanner.Parent = screenGui

local gbCorner = Instance.new("UICorner")
gbCorner.CornerRadius = UDim.new(0, 10)
gbCorner.Parent = globalLevelUpBanner

local gbStroke = Instance.new("UIStroke")
gbStroke.Color = Color3.fromRGB(255, 215, 50)
gbStroke.Thickness = 2
gbStroke.Parent = globalLevelUpBanner

local gbTitle = Instance.new("TextLabel")
gbTitle.Name = "Title"
gbTitle.Size = UDim2.new(1, -20, 0, 28)
gbTitle.Position = UDim2.new(0, 10, 0, 8)
gbTitle.BackgroundTransparency = 1
gbTitle.TextColor3 = Color3.fromRGB(255, 225, 70)
gbTitle.Font = Enum.Font.GothamBlack
gbTitle.TextSize = 15
gbTitle.Text = "★ NOUVEAU NIVEAU GLOBAL DE COMPTE ★"
gbTitle.Parent = globalLevelUpBanner

local gbDesc = Instance.new("TextLabel")
gbDesc.Name = "Desc"
gbDesc.Size = UDim2.new(1, -24, 0, 42)
gbDesc.Position = UDim2.new(0, 12, 0, 36)
gbDesc.BackgroundTransparency = 1
gbDesc.TextColor3 = Color3.fromRGB(220, 240, 255)
gbDesc.Font = Enum.Font.GothamMedium
gbDesc.TextSize = 12
gbDesc.TextWrapped = true
gbDesc.Text = ""
gbDesc.Parent = globalLevelUpBanner

Remotes.GetEvent("GlobalLevelUp").OnClientEvent:Connect(function(data: any)
	if not data then return end
	local info = data.unlockInfo
	local titleText = string.format("★ NOUVEAU NIVEAU GLOBAL : NIV. %d - %s ★", data.newLevel or 1, (info and info.title) or "Opérateur")
	local descText = (info and info.description) or "+1 Niveau de compte permanent !"

	gbTitle.Text = titleText
	gbDesc.Text = descText
	globalLevelUpBanner.Visible = true

	-- Slide-in animation
	local slideIn = TweenService:Create(globalLevelUpBanner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 96),
	})
	slideIn:Play()

	task.delay(5.5, function()
		local slideOut = TweenService:Create(globalLevelUpBanner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -110),
		})
		slideOut:Play()
		slideOut.Completed:Connect(function()
			globalLevelUpBanner.Visible = false
		end)
	end)
end)

-- --- 8. GAME OVER / MISSION SUMMARY MODAL ---
local gameOverModal = Instance.new("Frame")
gameOverModal.Name = "GameOverModal"
gameOverModal.Size = UDim2.new(1, 0, 1, 0)
gameOverModal.BackgroundColor3 = Color3.fromRGB(8, 10, 18)
gameOverModal.BackgroundTransparency = 0.15
gameOverModal.Visible = false
gameOverModal.ZIndex = 150
gameOverModal.Parent = screenGui

local goCard = Instance.new("Frame")
goCard.Name = "SummaryCard"
goCard.Size = UDim2.new(0, 460, 0, 380)
goCard.Position = UDim2.new(0.5, 0, 0.5, 0)
goCard.AnchorPoint = Vector2.new(0.5, 0.5)
goCard.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
goCard.BorderSizePixel = 0
goCard.Parent = gameOverModal

local goCorner = Instance.new("UICorner")
goCorner.CornerRadius = UDim.new(0, 16)
goCorner.Parent = goCard

local goStroke = Instance.new("UIStroke")
goStroke.Color = Color3.fromRGB(255, 60, 70)
goStroke.Thickness = 2
goStroke.Parent = goCard

local goTitle = Instance.new("TextLabel")
goTitle.Name = "Title"
goTitle.Size = UDim2.new(1, 0, 0, 42)
goTitle.Position = UDim2.new(0, 0, 0, 20)
goTitle.BackgroundTransparency = 1
goTitle.TextColor3 = Color3.fromRGB(255, 60, 70)
goTitle.Font = Enum.Font.GothamBlack
goTitle.TextSize = 22
goTitle.Text = "MISSION TERMINÉE"
goTitle.Parent = goCard

local goSub = Instance.new("TextLabel")
goSub.Name = "Sub"
goSub.Size = UDim2.new(1, 0, 0, 22)
goSub.Position = UDim2.new(0, 0, 0, 62)
goSub.BackgroundTransparency = 1
goSub.TextColor3 = Color3.fromRGB(150, 180, 210)
goSub.Font = Enum.Font.Gotham
goSub.TextSize = 13
goSub.Text = "Votre Mécha a été neutralisé par l'Essaim."
goSub.Parent = goCard

local goStatsBox = Instance.new("Frame")
goStatsBox.Name = "StatsBox"
goStatsBox.Size = UDim2.new(1, -40, 0, 180)
goStatsBox.Position = UDim2.new(0, 20, 0, 96)
goStatsBox.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
goStatsBox.BorderSizePixel = 0
goStatsBox.Parent = goCard

local goStatsCorner = Instance.new("UICorner")
goStatsCorner.CornerRadius = UDim.new(0, 8)
goStatsCorner.Parent = goStatsBox

local goStatsText = Instance.new("TextLabel")
goStatsText.Name = "StatsText"
goStatsText.Size = UDim2.new(1, -24, 1, -16)
goStatsText.Position = UDim2.new(0, 12, 0, 8)
goStatsText.BackgroundTransparency = 1
goStatsText.TextColor3 = Color3.fromRGB(220, 240, 255)
goStatsText.Font = Enum.Font.GothamMedium
goStatsText.TextSize = 14
goStatsText.TextXAlignment = Enum.TextXAlignment.Left
goStatsText.TextYAlignment = Enum.TextYAlignment.Center
goStatsText.Text = "Initialisation du rapport télémétrique..."
goStatsText.Parent = goStatsBox

local restartBtn = Instance.new("TextButton")
restartBtn.Name = "RestartBtn"
restartBtn.Size = UDim2.new(1, -40, 0, 46)
restartBtn.Position = UDim2.new(0, 20, 1, -66)
restartBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
restartBtn.TextColor3 = Color3.fromRGB(10, 15, 25)
restartBtn.Font = Enum.Font.GothamBlack
restartBtn.TextSize = 14
restartBtn.Text = "RÉAPPARAÎTRE / NOUVELLE MISSION"
restartBtn.Parent = goCard

local restartCorner = Instance.new("UICorner")
restartCorner.CornerRadius = UDim.new(0, 8)
restartCorner.Parent = restartBtn

restartBtn.Activated:Connect(function()
	gameOverModal.Visible = false
	Remotes.GetEvent("RestartRun"):FireServer()
end)

-- --- 8B. ZONE WARP OVERLAY & LOCAL PORTAL VISUAL SYNC ---
local warpOverlay = Instance.new("Frame")
warpOverlay.Name = "ZoneWarpOverlay"
warpOverlay.Size = UDim2.new(1, 0, 1, 0)
warpOverlay.BackgroundColor3 = Color3.fromRGB(6, 12, 24)
warpOverlay.BackgroundTransparency = 0.15
warpOverlay.BorderSizePixel = 0
warpOverlay.Visible = false
warpOverlay.ZIndex = 220
warpOverlay.Parent = vfxGui

local warpLabel = Instance.new("TextLabel")
warpLabel.Name = "WarpLabel"
warpLabel.Size = UDim2.new(1, -40, 0, 60)
warpLabel.Position = UDim2.new(0, 20, 0.5, -30)
warpLabel.BackgroundTransparency = 1
warpLabel.Font = Enum.Font.GothamBlack
warpLabel.TextSize = 24
warpLabel.TextColor3 = Color3.fromRGB(0, 240, 255)
warpLabel.Text = "TRANSFERT INTER-SERVEURS EN COURS..."
warpLabel.Parent = warpOverlay

local currentZoneId = tonumber(Workspace:GetAttribute("ZoneId")) or 1
local currentZoneName = tostring(Workspace:GetAttribute("ZoneName") or "ZONE 1")
local currentRunLevel = 1

local function formatXPValue(val: number): string
	if math.abs(val - math.round(val)) < 0.005 then
		return string.format("%.0f", val)
	end
	local s = string.format("%.2f", val)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	return s
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
	task.defer(refreshLocalPortalVisuals)
end)

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "MechaArena" then
		task.delay(0.15, refreshLocalPortalVisuals)
	end
end)
task.defer(refreshLocalPortalVisuals)

local function showPortalBanner(message: string)
	gbTitle.Text = "⚡ TÉLÉPORTEUR INTER-ZONES ACTIVÉ ⚡"
	gbDesc.Text = message
	globalLevelUpBanner.Visible = true
	local slideIn = TweenService:Create(globalLevelUpBanner, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 96),
	})
	slideIn:Play()
	task.delay(5.0, function()
		local slideOut = TweenService:Create(globalLevelUpBanner, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -110),
		})
		slideOut:Play()
		slideOut.Completed:Connect(function()
			globalLevelUpBanner.Visible = false
		end)
	end)
end

-- --- 9. SYNCHRONISATION DU STATUT RÉSEAU & META-PROGRESSION ---
local currentSurvivingWave = 1
local prevHP: number? = nil

Remotes.GetEvent("MetaSync").OnClientEvent:Connect(function(data: any)
	if not data then return end

	if data.totalXP ~= nil then cachedTotalXP = data.totalXP end
	if data.maxTimelineXP ~= nil then cachedMaxTimelineXP = data.maxTimelineXP end
	if data.nextUpcomingXP ~= nil then cachedNextUpcomingXP = data.nextUpcomingXP end
	if data.weaponSlots ~= nil then cachedMaxWeaponSlots = data.weaponSlots end
	if data.passiveSlots ~= nil then cachedMaxPassiveSlots = data.passiveSlots end
	if data.statSlots ~= nil then cachedMaxStatSlots = data.statSlots end
	if data.maxWeaponRank ~= nil then cachedMaxWeaponRank = data.maxWeaponRank end
	if data.maxStatRank ~= nil then cachedMaxStatRank = data.maxStatRank end

	metaLevelLabel.Text = string.format("ADN : %d XP", cachedTotalXP)
	local ratio = math.clamp(cachedTotalXP / cachedMaxTimelineXP, 0, 1)
	metaXPBarFill.Size = UDim2.new(ratio, 0, 1, 0)
	metaXPText.Text = string.format("%d / %d ADN", cachedTotalXP, cachedMaxTimelineXP)

	metaSlotsLabel.Text = string.format("SLOTS : %d ARM | %d PAS | %d STAT", cachedMaxWeaponSlots, cachedMaxPassiveSlots, cachedMaxStatSlots)

	-- Refresh slot renderings with updated unlock boundaries
	populateRowSlots(weaponSlots, cachedMaxWeaponSlots, Color3.fromRGB(255, 80, 80), cachedLastWeaponList)
	populateRowSlots(passiveSlots, cachedMaxPassiveSlots, Color3.fromRGB(200, 150, 255), cachedLastPassiveList)
	populateRowSlots(statSlots, cachedMaxStatSlots, Color3.fromRGB(50, 255, 120), cachedLastStatList)
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
			warpLabel.Text = "⚡ TRANSFERT VERS " .. tostring(data.teleportingToZone) .. "..."
			warpOverlay.Visible = true
		else
			warpOverlay.Visible = false
		end
	end

	if data.portalUnlockedAlert then
		showPortalBanner(tostring(data.portalUnlockedAlert))
	end

	if data.isDead then
		gameOverModal.Visible = true
		goStatsText.Text = string.format(
			"• Secteur atteint : %s (Vague %d)\n• Niveau de combat : %s\n• Emplacements : %d Armes | %d Passifs | %d Stats\n• ADN de compte : %d XP enregistré !",
			currentZoneName,
			currentSurvivingWave,
			levelBadge.Text,
			cachedMaxWeaponSlots,
			cachedMaxPassiveSlots,
			cachedMaxStatSlots,
			cachedTotalXP
		)
	end

	if data.currentHP and data.maxHP then
		if prevHP ~= nil and data.currentHP < prevHP then
			triggerDamageFlash()
		end
		prevHP = data.currentHP

		local hpRatio = math.clamp(data.currentHP / data.maxHP, 0, 1)
		hpBarFill.Size = UDim2.new(hpRatio, 0, 1, 0)
		hpText.Text = string.format("%.0f / %.0f PV", data.currentHP, data.maxHP)

		if overheadHpFill then
			overheadHpFill.Size = UDim2.new(hpRatio, 0, 1, 0)
			overheadHpFill.BackgroundColor3 = if hpRatio < 0.3 then Color3.fromRGB(255, 50, 50) else Color3.fromRGB(50, 220, 70)
		end
		updateHpNotches(data.maxHP)

		if data.currentHP <= 0 then
			gameOverModal.Visible = true
		end
	end

	if data.stats and data.stats.Armor ~= nil then
		local armor = data.stats.Armor
		local reduction = math.floor((armor / (armor + 100)) * 100)
		armorText.Text = string.format("BLINDAGE : %.0f ARMURE (%d%% RÉDUCTION)", armor, reduction)
	end

	if data.currentOverdrive ~= nil and data.maxOverdrive ~= nil then
		local odRatio = math.clamp(data.currentOverdrive / data.maxOverdrive, 0, 1)
		odBarFill.Size = UDim2.new(odRatio, 0, 1, 0)

		if overheadOdFill then
			overheadOdFill.Size = UDim2.new(odRatio, 0, 1, 0)
			if data.isOverdriveActive then
				overheadOdFill.BackgroundColor3 = Color3.fromRGB(255, 40, 90)
			elseif odRatio >= 1.0 then
				overheadOdFill.BackgroundColor3 = Color3.fromRGB(255, 220, 40)
			else
				overheadOdFill.BackgroundColor3 = Color3.fromRGB(255, 140, 20)
			end
		end

		if data.isOverdriveActive then
			odBtn.Text = "OVERDRIVE ACTIF ! FEU FRÉNÉTIQUE !"
			odBtn.TextColor3 = Color3.fromRGB(255, 50, 80)
			odBarFill.BackgroundColor3 = Color3.fromRGB(255, 30, 80)
		elseif odRatio >= 1.0 then
			odBtn.Text = "OVERDRIVE PRÊT ! [ESPACE / TOUCHE F]"
			odBtn.TextColor3 = Color3.fromRGB(255, 240, 50)
			odBarFill.BackgroundColor3 = Color3.fromRGB(255, 200, 30)
		else
			odBtn.Text = string.format("RÉACTEUR OVERDRIVE : %.0f%%", odRatio * 100)
			odBtn.TextColor3 = Color3.fromRGB(255, 160, 60)
			odBarFill.BackgroundColor3 = Color3.fromRGB(255, 120, 30)
		end
	end

	if data.level and data.currentXP ~= nil and data.xpToNextLevel then
		currentRunLevel = data.level
		levelBadge.Text = "NIV. " .. data.level
		local xpRatio = math.clamp(data.currentXP / data.xpToNextLevel, 0, 1)
		xpBarFill.Size = UDim2.new(xpRatio, 0, 1, 0)
		xpText.Text = string.format("%s / %.0f XP", formatXPValue(data.currentXP), data.xpToNextLevel)

		if overheadXpFill then
			overheadXpFill.Size = UDim2.new(xpRatio, 0, 1, 0)
		end
		updateXpNotches(data.xpToNextLevel)
		refreshLocalPortalVisuals()
	end

	if data.wave then
		currentSurvivingWave = data.wave
		if data.waveState == "BOSS" then
			waveInfoLabel.TextColor3 = Color3.fromRGB(255, 75, 85)
			waveInfoLabel.Text = string.format("ZONE %d • BOSS VAGUE %d (%ds)", currentZoneId, data.wave, data.waveTimer or 0)
		else
			waveInfoLabel.TextColor3 = Color3.fromRGB(255, 210, 50)
			waveInfoLabel.Text = string.format("ZONE %d • VAGUE %d (%ds) | %d FOES", currentZoneId, data.wave, data.waveTimer or 0, data.activeEnemies or 0)
		end
	end

	-- Populate 3-Row Inventory Slots (Faithful to Unity UIManager.cs)
	if data.weapons then
		local wList: { { name: string, rank: number, maxRank: number?, tag: string?, glyph: string?, icon: string?, iconFile: string? } } = {}
		local hasTemp = false
		local tempIcon = nil
		local tempIconFile = nil

		for wId, rank in pairs(data.weapons) do
			local wDef = WeaponsData.GetWeapon(wId)
			if wId == "StarterGun" then
				hasTemp = true
				tempIcon = if wDef then wDef.icon else nil
				tempIconFile = if wDef then wDef.iconFile else nil
			else
				table.insert(wList, {
					name = if wDef then wDef.name else wId,
					rank = rank,
					maxRank = cachedMaxWeaponRank,
					tag = if wDef and wDef.tag then string.gsub(wDef.tag, "[%[%]%s]", "") else string.sub(wId, 1, 4):upper(),
					icon = if wDef then wDef.icon else nil,
					iconFile = if wDef then wDef.iconFile else nil,
				})
			end
		end

		cachedLastWeaponList = wList
		cachedHasTempWeapon = hasTemp

		-- Display separate Starter Gun box matching Unity tempWeaponBox
		if hasTemp then
			tempWeaponBox.Visible = true
			weaponSlots.Position = UDim2.new(0, 110, 0, 0)
			local res = resolveTexture(tempIconFile, tempIcon)
			if res and res ~= "" then
				twbIcon.Image = res
				twbTag.Visible = false
			else
				twbTag.Visible = true
			end
		else
			tempWeaponBox.Visible = false
			weaponSlots.Position = UDim2.new(0, 75, 0, 0)
		end

		populateRowSlots(weaponSlots, cachedMaxWeaponSlots, Color3.fromRGB(255, 80, 80), wList)
	end

	if data.passives then
		local pList: { { name: string, rank: number, maxRank: number?, tag: string?, glyph: string?, icon: string?, iconFile: string? } } = {}
		for _, p in ipairs(data.passives) do
			table.insert(pList, {
				name = p.name or "Passif",
				rank = 1,
				maxRank = 1,
				tag = "PASF",
				icon = p.icon,
				iconFile = p.iconFile,
			})
		end
		cachedLastPassiveList = pList
		populateRowSlots(passiveSlots, cachedMaxPassiveSlots, Color3.fromRGB(200, 150, 255), pList)
	end

	if data.stats then
		local sList: { { name: string, rank: number, maxRank: number?, tag: string?, glyph: string?, icon: string?, iconFile: string? } } = {}
		local statCardLevels = data.statCardLevels or {}
		local statEntries = { "MaxHP", "Speed", "DamageMultiplier", "FireRateMultiplier", "Armor", "CriticalChance", "PickupRadius", "LifeSteal", "BurnDamage", "RangeMultiplier" }

		for _, sKey in ipairs(statEntries) do
			local currentLvl = statCardLevels[sKey]
			if currentLvl and currentLvl > 0 then
				local conf = StatTypes.STAT_CONFIG[sKey]
				local tag = if conf and conf.tag then string.gsub(conf.tag, "[%[%]%s]", "") else string.sub(sKey, 1, 4):upper()
				table.insert(sList, {
					name = sKey,
					rank = currentLvl,
					maxRank = cachedMaxStatRank,
					tag = tag,
					icon = if conf then conf.icon else nil,
					iconFile = if conf then conf.iconFile else nil,
				})
			end
		end
		cachedLastStatList = sList
		populateRowSlots(statSlots, cachedMaxStatSlots, Color3.fromRGB(50, 255, 120), sList)
	end
end)
