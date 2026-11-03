--!strict
-- InventoryView.luau: Compact 3-Row Bottom Inventory (ARMES, PASSIFS, STATS) with strict slot-count width and zero line wrapping

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponsData = require(Shared:WaitForChild("WeaponsData"))
local StatTypes = require(Shared:WaitForChild("StatTypes"))
local PassivesData = require(Shared:WaitForChild("PassivesData"))

local TextureResolver = require(script.Parent.TextureResolver)

local InventoryView = {}

local INV_LABEL_WIDTH = 66
local INV_SLOTS_X = 70
local INV_SLOT_SIZE = 30
local INV_SLOT_STEP = 36
local INV_PAD_X = 10
local INV_HEIGHT = 120

local PASSIVE_TRIGGER_TAGS: { [string]: string } = {
	OnEnemyKilled = "KILL",
	OnDamageDealt = "HIT",
	OnDamageTaken = "TANK",
	OnHeal = "SOIN",
	OnMove = "MOVE",
	OnStandStill = "FIXE",
	OnCritHit = "CRIT",
	OnLevelUp = "NIV",
	OnOverdrive = "OVER",
	OnGainXP = "XP",
	OnWaveStart = "VAG",
	OnWeaponFire = "TIR",
}

local PASSIVE_EFFECT_TAGS: { [string]: string } = {
	Heal = "SOIN",
	GainMaxHP = "PV+",
	GainStatDamage = "DMG+",
	GainStatSpeed = "VIT+",
	GainStatFireRate = "CAD+",
	GainCritChance = "CRT+",
	GainStatArmor = "ARM+",
	GainLifeSteal = "VOL+",
	ChargeOverdrive = "OD+",
	GainXP = "XP+",
}

export type SlotEntry = {
	name: string,
	rank: number,
	maxRank: number?,
	tag: string?,
	glyph: string?,
	icon: string?,
	iconFile: string?,
	iconColor: Color3?,
	borderColor: Color3?,
	isComposite: boolean?,
	triggerIconFile: string?,
	effectIconFile: string?,
	triggerColor: Color3?,
	effectColor: Color3?,
	triggerTag: string?,
	effectTag: string?,
}

export type InventoryController = {
	container: Frame,
	ApplyViewport: (vp: Vector2, baseScale: number) -> (),
	SetCaps: (weaponSlots: number, passiveSlots: number, statSlots: number, maxWeaponRank: number, maxStatRank: number) -> (),
	UpdateWeapons: (weaponsMap: { [string]: number }) -> (),
	UpdatePassives: (passivesList: { any }) -> (),
	UpdateStats: (statCardLevels: { [string]: number }?) -> (),
}

local function populateRowSlots(container: Frame, maxCount: number, defaultBorderColor: Color3, items: { SlotEntry })
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for i = 1, maxCount do
		local box = Instance.new("Frame")
		box.Name = "Slot_" .. i
		box.Size = UDim2.new(0, INV_SLOT_SIZE, 0, INV_SLOT_SIZE)
		box.Position = UDim2.new(0, (i - 1) * INV_SLOT_STEP, 0, 1)
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
			local slotBorder = item.borderColor or defaultBorderColor
			bStroke.Color = slotBorder
			bStroke.Transparency = 0.2
			box.BackgroundColor3 = Color3.fromRGB(22, 30, 48)

			if item.isComposite == true then
				box.ClipsDescendants = true

				-- Unity-style -45deg diagonal separator line (/)
				local diag = Instance.new("Frame")
				diag.Name = "Diagonal"
				diag.Size = UDim2.new(1.42, 0, 0, 1)
				diag.AnchorPoint = Vector2.new(0.5, 0.5)
				diag.Position = UDim2.new(0.5, 0, 0.5, 0)
				diag.Rotation = -45
				diag.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				diag.BackgroundTransparency = 0.65
				diag.BorderSizePixel = 0
				diag.ZIndex = 2
				diag.Parent = box

				-- Trigger icon (top-left)
				local tRes = TextureResolver.Resolve(item.triggerIconFile, item.triggerIcon)
				local trigColor = item.triggerColor or Color3.new(1, 1, 1)
				if tRes and tRes ~= "" then
					local tImg = Instance.new("ImageLabel")
					tImg.Name = "TriggerIcon"
					tImg.Size = UDim2.new(0, 13, 0, 13)
					tImg.Position = UDim2.new(0, 2, 0, 2)
					tImg.BackgroundTransparency = 1
					tImg.Image = tRes
					tImg.ImageColor3 = trigColor
					tImg.ZIndex = 3
					tImg.Parent = box
				else
					local tLbl = Instance.new("TextLabel")
					tLbl.Name = "TriggerTag"
					tLbl.Size = UDim2.new(0, 14, 0, 13)
					tLbl.Position = UDim2.new(0, 1, 0, 1)
					tLbl.BackgroundTransparency = 1
					tLbl.TextColor3 = trigColor
					tLbl.Font = Enum.Font.GothamBlack
					tLbl.TextSize = 7
					tLbl.TextWrapped = false
					tLbl.Text = item.triggerTag or "TRG"
					tLbl.ZIndex = 3
					tLbl.Parent = box
				end

				-- Effect icon (bottom-right)
				local eRes = TextureResolver.Resolve(item.effectIconFile, item.effectIcon)
				local effColor = item.effectColor or Color3.new(1, 1, 1)
				if eRes and eRes ~= "" then
					local eImg = Instance.new("ImageLabel")
					eImg.Name = "EffectIcon"
					eImg.Size = UDim2.new(0, 13, 0, 13)
					eImg.Position = UDim2.new(1, -15, 1, -15)
					eImg.BackgroundTransparency = 1
					eImg.Image = eRes
					eImg.ImageColor3 = effColor
					eImg.ZIndex = 3
					eImg.Parent = box
				else
					local eLbl = Instance.new("TextLabel")
					eLbl.Name = "EffectTag"
					eLbl.Size = UDim2.new(0, 14, 0, 13)
					eLbl.Position = UDim2.new(1, -15, 1, -14)
					eLbl.BackgroundTransparency = 1
					eLbl.TextColor3 = effColor
					eLbl.Font = Enum.Font.GothamBlack
					eLbl.TextSize = 7
					eLbl.TextWrapped = false
					eLbl.Text = item.effectTag or "EFF"
					eLbl.ZIndex = 3
					eLbl.Parent = box
				end
			else
				box.ClipsDescendants = false

				local rawTag = item.tag or item.glyph or string.sub(item.name, 1, 4):upper()
				local tagLabel = Instance.new("TextLabel")
				tagLabel.Name = "Tag"
				tagLabel.Size = UDim2.new(1, -2, 1, -2)
				tagLabel.Position = UDim2.new(0, 1, 0, 1)
				tagLabel.BackgroundTransparency = 1
				tagLabel.TextColor3 = item.iconColor or slotBorder
				tagLabel.Font = Enum.Font.GothamBlack
				tagLabel.TextSize = 8
				tagLabel.TextWrapped = false
				tagLabel.TextTruncate = Enum.TextTruncate.None
				tagLabel.Text = string.sub(rawTag, 1, 4)
				tagLabel.ZIndex = 1
				tagLabel.Parent = box

				local resolved = TextureResolver.Resolve(item.iconFile, item.icon)
				if resolved and resolved ~= "" then
					local iconImg = Instance.new("ImageLabel")
					iconImg.Size = UDim2.new(1, -4, 1, -4)
					iconImg.Position = UDim2.new(0, 2, 0, 2)
					iconImg.BackgroundTransparency = 1
					iconImg.Image = resolved
					iconImg.ImageColor3 = item.iconColor or Color3.new(1, 1, 1)
					iconImg.ZIndex = 2
					iconImg.Parent = box
					tagLabel.Visible = false
				end
			end

			if item.rank and item.rank > 0 then
				local rankBadge = Instance.new("TextLabel")
				rankBadge.Name = "RankBadge"
				rankBadge.Size = UDim2.new(0, 22, 0, 11)
				rankBadge.Position = UDim2.new(1, -22, 1, -11)
				rankBadge.BackgroundColor3 = Color3.fromRGB(10, 15, 25)
				rankBadge.BackgroundTransparency = 0.18
				rankBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
				rankBadge.Font = Enum.Font.GothamBold
				rankBadge.TextSize = 8
				rankBadge.TextWrapped = false
				rankBadge.Text = if item.maxRank and item.maxRank > 1 then string.format("%d/%d", item.rank, item.maxRank) else tostring(item.rank)
				rankBadge.ZIndex = 4
				rankBadge.Parent = box

				local rCorner = Instance.new("UICorner")
				rCorner.CornerRadius = UDim.new(0, 3)
				rCorner.Parent = rankBadge
			end
		else
			box.ClipsDescendants = false
			box.BackgroundColor3 = Color3.fromRGB(12, 15, 24)
			bStroke.Color = Color3.fromRGB(45, 55, 75)
			bStroke.Transparency = 0.65
		end
	end
end

function InventoryView.Create(parentGui: ScreenGui, bottomOffset: number): InventoryController
	local invNaturalWidth = 156

	local invContainer = Instance.new("Frame")
	invContainer.Name = "InventoryContainer"
	invContainer.AnchorPoint = Vector2.new(0, 1)
	invContainer.Position = UDim2.new(0, 14, 1, -bottomOffset)
	invContainer.Size = UDim2.new(0, invNaturalWidth, 0, INV_HEIGHT)
	invContainer.BackgroundColor3 = Color3.fromRGB(10, 15, 25)
	invContainer.BackgroundTransparency = 0.22
	invContainer.BorderSizePixel = 0
	invContainer.ZIndex = 12
	invContainer.Parent = parentGui

	local invScale = Instance.new("UIScale")
	invScale.Name = "InvScale"
	invScale.Parent = invContainer

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
		row.Size = UDim2.new(1, -(INV_PAD_X * 2), 0, 32)
		row.Position = UDim2.new(0, INV_PAD_X, 0, yPos)
		row.BackgroundTransparency = 1
		row.Parent = invContainer

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(0, INV_LABEL_WIDTH, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = labelColor
		label.Font = Enum.Font.GothamBold
		label.TextSize = 11
		label.TextWrapped = false
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = labelText
		label.Parent = row

		local slots = Instance.new("Frame")
		slots.Name = "Slots"
		slots.Size = UDim2.new(1, -INV_SLOTS_X, 1, 0)
		slots.Position = UDim2.new(0, INV_SLOTS_X, 0, 0)
		slots.BackgroundTransparency = 1
		slots.Parent = row

		return row, slots
	end

	local weaponsRow, weaponSlots = createInvRow("Weapons", "ARMES", Color3.fromRGB(255, 100, 100), 8)
	local _, passiveSlots = createInvRow("Passives", "PASSIFS", Color3.fromRGB(200, 150, 255), 44)
	local _, statSlots = createInvRow("Stats", "STATS", Color3.fromRGB(100, 255, 150), 80)

	local tempWeaponBox = Instance.new("Frame")
	tempWeaponBox.Name = "TempWeaponBox"
	tempWeaponBox.Size = UDim2.new(0, INV_SLOT_SIZE, 0, INV_SLOT_SIZE)
	tempWeaponBox.Position = UDim2.new(0, INV_SLOTS_X, 0, 1)
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
	twbTag.TextWrapped = false
	twbTag.Text = "INIT"
	twbTag.ZIndex = 3
	twbTag.Parent = tempWeaponBox

	local maxWeaponSlots = 1
	local maxPassiveSlots = 1
	local maxStatSlots = 1
	local maxWeaponRank = 1
	local maxStatRank = 3

	local lastWeapons: { SlotEntry } = {}
	local lastPassives: { SlotEntry } = {}
	local lastStats: { SlotEntry } = {}
	local hasTempWeapon = false
	local lastViewport = Vector2.new(1366, 768)
	local lastBaseScale = 1.0

	local function applyViewport(vp: Vector2, baseScale: number)
		lastViewport = vp
		lastBaseScale = baseScale
		invContainer.Position = UDim2.new(0, 14, 1, -bottomOffset)
		local invFitScale = (vp.X - 28) / math.max(1, invNaturalWidth)
		invScale.Scale = math.clamp(math.min(baseScale, invFitScale), 0.45, 1.10)
	end

	local function recomputeWidth()
		local wCols = maxWeaponSlots + (if hasTempWeapon then 1 else 0)
		local maxCols = math.max(1, wCols, maxPassiveSlots, maxStatSlots)
		local slotsPixelWidth = (maxCols * INV_SLOT_STEP) - (INV_SLOT_STEP - INV_SLOT_SIZE)
		invNaturalWidth = (INV_PAD_X * 2) + INV_SLOTS_X + slotsPixelWidth
		invContainer.Size = UDim2.new(0, invNaturalWidth, 0, INV_HEIGHT)
		applyViewport(lastViewport, lastBaseScale)
	end

	local function setCaps(wSlots: number, pSlots: number, sSlots: number, wRank: number, sRank: number)
		maxWeaponSlots = math.max(1, wSlots)
		maxPassiveSlots = math.max(1, pSlots)
		maxStatSlots = math.max(1, sSlots)
		maxWeaponRank = math.max(1, wRank)
		maxStatRank = math.max(1, sRank)

		for _, entry in ipairs(lastWeapons) do
			entry.maxRank = maxWeaponRank
		end
		for _, entry in ipairs(lastStats) do
			entry.maxRank = maxStatRank
		end

		populateRowSlots(weaponSlots, maxWeaponSlots, Color3.fromRGB(255, 80, 80), lastWeapons)
		populateRowSlots(passiveSlots, maxPassiveSlots, Color3.fromRGB(200, 150, 255), lastPassives)
		populateRowSlots(statSlots, maxStatSlots, Color3.fromRGB(50, 255, 120), lastStats)
		recomputeWidth()
	end

	local function updateWeapons(weaponsMap: { [string]: number })
		local wList: { SlotEntry } = {}
		local hasTemp = false
		local tempIcon = nil
		local tempIconFile = nil

		for wId, rank in pairs(weaponsMap) do
			local wDef = WeaponsData.GetWeapon(wId)
			local statColor = StatTypes.GetStatColor(wDef and wDef.uiStatColor)
			local color = statColor or Color3.fromRGB(255, 80, 80)
			if wId == "StarterGun" then
				hasTemp = true
				tempIcon = if wDef then wDef.icon else nil
				tempIconFile = if wDef then wDef.iconFile else nil
			else
				table.insert(wList, {
					name = if wDef then wDef.name else wId,
					rank = rank,
					maxRank = maxWeaponRank,
					tag = if wDef and wDef.tag then string.gsub(wDef.tag, "[%[%]%s]", "") else string.sub(wId, 1, 4):upper(),
					icon = if wDef then wDef.icon else nil,
					iconFile = if wDef then wDef.iconFile else nil,
					iconColor = statColor or Color3.new(1, 1, 1),
					borderColor = color,
				})
			end
		end

		table.sort(wList, function(a, b)
			return a.name < b.name
		end)

		lastWeapons = wList
		hasTempWeapon = hasTemp

		if hasTemp then
			tempWeaponBox.Visible = true
			weaponSlots.Position = UDim2.new(0, INV_SLOTS_X + INV_SLOT_STEP, 0, 0)
			local res = TextureResolver.Resolve(tempIconFile, tempIcon)
			if res and res ~= "" then
				twbIcon.Image = res
				twbIcon.ImageColor3 = Color3.new(1, 1, 1)
				twbTag.Visible = false
			else
				twbTag.Visible = true
			end
		else
			tempWeaponBox.Visible = false
			weaponSlots.Position = UDim2.new(0, INV_SLOTS_X, 0, 0)
		end

		populateRowSlots(weaponSlots, maxWeaponSlots, Color3.fromRGB(255, 80, 80), wList)
		recomputeWidth()
	end

	local function updatePassives(passivesList: { any })
		local pList: { SlotEntry } = {}
		for _, p in ipairs(passivesList) do
			local trig = p.trigger
			local eff = p.effect
			local tIcon = p.triggerIconFile or PassivesData.GetTriggerIconFile(trig)
			local eIcon = p.effectIconFile or PassivesData.GetEffectIconFile(eff)
			local tStat = p.triggerScalingStat or PassivesData.GetTriggerScalingStat(trig)
			local eStat = p.effectScalingStat or PassivesData.GetEffectScalingStat(eff)
			local tCol = StatTypes.GetStatColor(tStat) or Color3.new(1, 1, 1)
			local eCol = StatTypes.GetStatColor(eStat) or Color3.new(1, 1, 1)
			local tTag = PASSIVE_TRIGGER_TAGS[tostring(trig or "")] or "TRG"
			local eTag = PASSIVE_EFFECT_TAGS[tostring(eff or "")] or "EFF"

			table.insert(pList, {
				name = p.name or "Passif",
				rank = 0,
				maxRank = 0,
				tag = tTag,
				icon = p.icon,
				iconFile = eIcon,
				isComposite = true,
				triggerIconFile = tIcon,
				effectIconFile = eIcon,
				triggerColor = tCol,
				effectColor = eCol,
				triggerTag = tTag,
				effectTag = eTag,
				borderColor = Color3.fromRGB(200, 150, 255),
			})
		end
		lastPassives = pList
		populateRowSlots(passiveSlots, maxPassiveSlots, Color3.fromRGB(200, 150, 255), pList)
	end

	local function updateStats(statCardLevels: { [string]: number }?)
		local sList: { SlotEntry } = {}
		local levels = statCardLevels or {}
		local statEntries = { "MaxHP", "Speed", "DamageMultiplier", "FireRateMultiplier", "Armor", "CriticalChance", "PickupRadius", "LifeSteal", "BurnDamage", "RangeMultiplier" }

		for _, sKey in ipairs(statEntries) do
			local currentLvl = levels[sKey]
			if currentLvl and currentLvl > 0 then
				local conf = StatTypes.STAT_CONFIG[sKey]
				local tag = if conf and conf.tag then string.gsub(conf.tag, "[%[%]%s]", "") else string.sub(sKey, 1, 4):upper()
				local color = conf.color or Color3.fromRGB(50, 255, 120)
				table.insert(sList, {
					name = sKey,
					rank = currentLvl,
					maxRank = maxStatRank,
					tag = tag,
					icon = if conf then conf.icon else nil,
					iconFile = if conf then conf.iconFile else nil,
					iconColor = color,
					borderColor = color,
				})
			end
		end

		lastStats = sList
		populateRowSlots(statSlots, maxStatSlots, Color3.fromRGB(50, 255, 120), sList)
	end

	populateRowSlots(weaponSlots, maxWeaponSlots, Color3.fromRGB(255, 80, 80), lastWeapons)
	populateRowSlots(passiveSlots, maxPassiveSlots, Color3.fromRGB(200, 150, 255), lastPassives)
	populateRowSlots(statSlots, maxStatSlots, Color3.fromRGB(50, 255, 120), lastStats)
	recomputeWidth()

	return {
		container = invContainer,
		ApplyViewport = applyViewport,
		SetCaps = setCaps,
		UpdateWeapons = updateWeapons,
		UpdatePassives = updatePassives,
		UpdateStats = updateStats,
	}
end

return InventoryView
