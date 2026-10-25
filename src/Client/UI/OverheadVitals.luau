--!strict
-- OverheadVitals.luau: Floating overhead BillboardGui bars (Level badge on the left, Health, In-Run XP, Overdrive) above the local character

local TweenService = game:GetService("TweenService")

local OverheadVitals = {}

local overheadHpFill: Frame? = nil
local overheadHpNotches: Frame? = nil
local overheadXpFill: Frame? = nil
local overheadXpNotches: Frame? = nil
local overheadOdFill: Frame? = nil
local overheadLevelLabel: TextLabel? = nil
local overheadLevelBadge: Frame? = nil
local overheadLevelStroke: UIStroke? = nil

local lastExpectedHpNotches = -1
local lastExpectedXpNotches = -1

local lastHpRatio = 1.0
local lastMaxHp = 100
local lastXpRatio = 0.0
local lastMaxXp = 12
local lastOdRatio = 0.0
local lastIsOdActive = false
local lastLevel = 1

local function rebuildNotches(container: Frame?, count: number, transparency: number)
	if not container then return end
	container:ClearAllChildren()
	-- Cap visual notches so ultra-high late-game HP/XP never spawns hundreds of UI frames
	local capped = math.min(count, 40)
	for i = 1, capped - 1 do
		local line = Instance.new("Frame")
		line.Size = UDim2.new(0, 1, 1, 0)
		line.Position = UDim2.new(i / capped, 0, 0, 0)
		line.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		line.BackgroundTransparency = transparency
		line.BorderSizePixel = 0
		line.Parent = container
	end
end

function OverheadVitals.UpdateLevel(level: number)
	local prev = lastLevel
	lastLevel = math.max(1, level)

	if overheadLevelLabel then
		overheadLevelLabel.Text = tostring(lastLevel)
	end

	-- Level-up celebratory pop animation on the badge
	if lastLevel > prev and overheadLevelBadge and overheadLevelStroke then
		local origColor = Color3.fromRGB(0, 210, 255)
		overheadLevelStroke.Color = Color3.fromRGB(255, 230, 80)
		overheadLevelStroke.Thickness = 2.0

		local pulseTw = TweenService:Create(overheadLevelStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = origColor,
			Thickness = 1.2,
		})
		pulseTw:Play()
	end
end

function OverheadVitals.UpdateHealth(currentHP: number, maxHP: number)
	local safeMax = math.max(1, maxHP)
	local hpRatio = math.clamp(currentHP / safeMax, 0, 1)
	lastHpRatio = hpRatio
	lastMaxHp = safeMax

	if overheadHpFill then
		overheadHpFill.Size = UDim2.new(hpRatio, 0, 1, 0)
		overheadHpFill.BackgroundColor3 = if hpRatio < 0.3 then Color3.fromRGB(255, 71, 87) else Color3.fromRGB(46, 213, 115)
	end

	local notchesCount = math.floor(safeMax / 20)
	if notchesCount ~= lastExpectedHpNotches and overheadHpNotches then
		lastExpectedHpNotches = notchesCount
		rebuildNotches(overheadHpNotches, notchesCount, 0.4)
	end
end

function OverheadVitals.UpdateXP(currentXP: number, xpToNextLevel: number)
	local safeMax = math.max(1, xpToNextLevel)
	local xpRatio = math.clamp(currentXP / safeMax, 0, 1)
	lastXpRatio = xpRatio
	lastMaxXp = safeMax

	if overheadXpFill then
		overheadXpFill.Size = UDim2.new(xpRatio, 0, 1, 0)
	end

	local notchesCount = math.floor(safeMax / 10)
	if notchesCount ~= lastExpectedXpNotches and overheadXpNotches then
		lastExpectedXpNotches = notchesCount
		rebuildNotches(overheadXpNotches, notchesCount, 0.5)
	end
end

function OverheadVitals.UpdateOverdrive(currentOverdrive: number, maxOverdrive: number, isOverdriveActive: boolean)
	local safeMax = math.max(1, maxOverdrive)
	local odRatio = math.clamp(currentOverdrive / safeMax, 0, 1)
	lastOdRatio = odRatio
	lastIsOdActive = isOverdriveActive

	if overheadOdFill then
		overheadOdFill.Size = UDim2.new(odRatio, 0, 1, 0)
		if isOverdriveActive then
			overheadOdFill.BackgroundColor3 = Color3.fromRGB(255, 45, 95)
		elseif odRatio >= 1.0 then
			overheadOdFill.BackgroundColor3 = Color3.fromRGB(255, 225, 45)
		else
			overheadOdFill.BackgroundColor3 = Color3.fromRGB(255, 145, 25)
		end
	end
end

local function setupCharacter(char: Model)
	local hrp = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not hrp then return end

	local old = hrp:FindFirstChild("PlayerFloatingVitals")
	if old then old:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Name = "PlayerFloatingVitals"
	bb.Adornee = hrp
	bb.Size = UDim2.new(0, 112, 0, 24)
	bb.StudsOffset = Vector3.new(0, 3.8, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 200
	bb.ResetOnSpawn = false
	bb.Parent = hrp

	-- Root container
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.new(1, 0, 1, 0)
	root.BackgroundTransparency = 1
	root.Parent = bb

	-- 1. Sleek Modern Cyber Level Badge on the Left (24x24 px)
	local levelBadge = Instance.new("Frame")
	levelBadge.Name = "LevelBadge"
	levelBadge.Size = UDim2.new(0, 24, 0, 24)
	levelBadge.Position = UDim2.new(0, 0, 0, 0)
	levelBadge.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
	levelBadge.BackgroundTransparency = 0.15
	levelBadge.BorderSizePixel = 0
	levelBadge.Parent = root

	local lbCorner = Instance.new("UICorner")
	lbCorner.CornerRadius = UDim.new(0, 6)
	lbCorner.Parent = levelBadge

	local lbStroke = Instance.new("UIStroke")
	lbStroke.Color = Color3.fromRGB(0, 210, 255)
	lbStroke.Thickness = 1.2
	lbStroke.Transparency = 0.35
	lbStroke.Parent = levelBadge

	local lbGradient = Instance.new("UIGradient")
	lbGradient.Rotation = 90
	lbGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 38, 56)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 14, 22)),
	})
	lbGradient.Parent = levelBadge

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelNumber"
	levelLabel.Size = UDim2.new(1, 0, 1, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextColor3 = Color3.fromRGB(240, 250, 255)
	levelLabel.Font = Enum.Font.GothamBlack
	levelLabel.TextSize = 13
	levelLabel.Text = tostring(lastLevel)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Center
	levelLabel.TextYAlignment = Enum.TextYAlignment.Center
	levelLabel.Parent = levelBadge

	-- 2. Vertical Bars Stack on the Right (Width: 100% - 28px)
	local barsStack = Instance.new("Frame")
	barsStack.Name = "BarsStack"
	barsStack.Position = UDim2.new(0, 28, 0, 0)
	barsStack.Size = UDim2.new(1, -28, 1, 0)
	barsStack.BackgroundTransparency = 1
	barsStack.Parent = root

	local stackList = Instance.new("UIListLayout")
	stackList.FillDirection = Enum.FillDirection.Vertical
	stackList.SortOrder = Enum.SortOrder.LayoutOrder
	stackList.Padding = UDim.new(0, 2)
	stackList.Parent = barsStack

	-- 2a. Health Bar (top, 10px)
	local hpBg = Instance.new("Frame")
	hpBg.Name = "HPBar"
	hpBg.LayoutOrder = 1
	hpBg.Size = UDim2.new(1, 0, 0, 10)
	hpBg.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
	hpBg.BorderSizePixel = 0
	hpBg.Parent = barsStack

	local hpCorner = Instance.new("UICorner")
	hpCorner.CornerRadius = UDim.new(0, 3)
	hpCorner.Parent = hpBg

	local hpStroke = Instance.new("UIStroke")
	hpStroke.Color = Color3.fromRGB(35, 45, 65)
	hpStroke.Thickness = 1.0
	hpStroke.Transparency = 0.4
	hpStroke.Parent = hpBg

	local hpFill = Instance.new("Frame")
	hpFill.Name = "Fill"
	hpFill.Size = UDim2.new(lastHpRatio, 0, 1, 0)
	hpFill.BackgroundColor3 = if lastHpRatio < 0.3 then Color3.fromRGB(255, 71, 87) else Color3.fromRGB(46, 213, 115)
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

	-- 2b. In-Run XP Bar (middle, 5px)
	local xpBg = Instance.new("Frame")
	xpBg.Name = "XPBar"
	xpBg.LayoutOrder = 2
	xpBg.Size = UDim2.new(1, 0, 0, 5)
	xpBg.BackgroundColor3 = Color3.fromRGB(10, 16, 26)
	xpBg.BorderSizePixel = 0
	xpBg.Parent = barsStack

	local xpCorner = Instance.new("UICorner")
	xpCorner.CornerRadius = UDim.new(0, 2)
	xpCorner.Parent = xpBg

	local xpFill = Instance.new("Frame")
	xpFill.Name = "Fill"
	xpFill.Size = UDim2.new(lastXpRatio, 0, 1, 0)
	xpFill.BackgroundColor3 = Color3.fromRGB(0, 210, 255)
	xpFill.BorderSizePixel = 0
	xpFill.Parent = xpBg

	local xpFillCorner = Instance.new("UICorner")
	xpFillCorner.CornerRadius = UDim.new(0, 2)
	xpFillCorner.Parent = xpFill

	local xpNotches = Instance.new("Frame")
	xpNotches.Name = "Notches"
	xpNotches.Size = UDim2.new(1, 0, 1, 0)
	xpNotches.BackgroundTransparency = 1
	xpNotches.Parent = xpBg

	-- 2c. Overdrive Bar (bottom, 5px)
	local odBg = Instance.new("Frame")
	odBg.Name = "ODBar"
	odBg.LayoutOrder = 3
	odBg.Size = UDim2.new(1, 0, 0, 5)
	odBg.BackgroundColor3 = Color3.fromRGB(22, 16, 12)
	odBg.BorderSizePixel = 0
	odBg.Parent = barsStack

	local odCorner = Instance.new("UICorner")
	odCorner.CornerRadius = UDim.new(0, 2)
	odCorner.Parent = odBg

	local odFill = Instance.new("Frame")
	odFill.Name = "Fill"
	odFill.Size = UDim2.new(lastOdRatio, 0, 1, 0)
	odFill.BackgroundColor3 = Color3.fromRGB(255, 145, 25)
	odFill.BorderSizePixel = 0
	odFill.Parent = odBg

	local odFillCorner = Instance.new("UICorner")
	odFillCorner.CornerRadius = UDim.new(0, 2)
	odFillCorner.Parent = odFill

	overheadHpFill = hpFill
	overheadHpNotches = hpNotches
	overheadXpFill = xpFill
	overheadXpNotches = xpNotches
	overheadOdFill = odFill
	overheadLevelLabel = levelLabel
	overheadLevelBadge = levelBadge
	overheadLevelStroke = lbStroke
	lastExpectedHpNotches = -1
	lastExpectedXpNotches = -1

	OverheadVitals.UpdateLevel(lastLevel)
	OverheadVitals.UpdateHealth(lastHpRatio * lastMaxHp, lastMaxHp)
	OverheadVitals.UpdateXP(lastXpRatio * lastMaxXp, lastMaxXp)
	OverheadVitals.UpdateOverdrive(lastOdRatio * 100, 100, lastIsOdActive)
end

function OverheadVitals.BindPlayer(player: Player)
	if player.Character then
		task.spawn(setupCharacter, player.Character)
	end
	player.CharacterAdded:Connect(setupCharacter)
end

return OverheadVitals
