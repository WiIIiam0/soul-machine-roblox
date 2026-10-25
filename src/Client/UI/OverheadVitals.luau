--!strict
-- OverheadVitals.luau: Floating overhead BillboardGui bars (Health, In-Run XP, Overdrive) above the local character

local OverheadVitals = {}

local overheadHpFill: Frame? = nil
local overheadHpNotches: Frame? = nil
local overheadXpFill: Frame? = nil
local overheadXpNotches: Frame? = nil
local overheadOdFill: Frame? = nil

local lastExpectedHpNotches = -1
local lastExpectedXpNotches = -1

local lastHpRatio = 1.0
local lastMaxHp = 100
local lastXpRatio = 0.0
local lastMaxXp = 12
local lastOdRatio = 0.0
local lastIsOdActive = false

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

function OverheadVitals.UpdateHealth(currentHP: number, maxHP: number)
	local safeMax = math.max(1, maxHP)
	local hpRatio = math.clamp(currentHP / safeMax, 0, 1)
	lastHpRatio = hpRatio
	lastMaxHp = safeMax

	if overheadHpFill then
		overheadHpFill.Size = UDim2.new(hpRatio, 0, 1, 0)
		overheadHpFill.BackgroundColor3 = if hpRatio < 0.3 then Color3.fromRGB(255, 50, 50) else Color3.fromRGB(50, 220, 70)
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
			overheadOdFill.BackgroundColor3 = Color3.fromRGB(255, 40, 90)
		elseif odRatio >= 1.0 then
			overheadOdFill.BackgroundColor3 = Color3.fromRGB(255, 220, 40)
		else
			overheadOdFill.BackgroundColor3 = Color3.fromRGB(255, 140, 20)
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
	hpFill.Size = UDim2.new(lastHpRatio, 0, 1, 0)
	hpFill.BackgroundColor3 = if lastHpRatio < 0.3 then Color3.fromRGB(255, 50, 50) else Color3.fromRGB(50, 220, 70)
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

	-- 2. In-Run XP Bar (middle, 4px)
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
	xpFill.Size = UDim2.new(lastXpRatio, 0, 1, 0)
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
	odFill.Size = UDim2.new(lastOdRatio, 0, 1, 0)
	odFill.BackgroundColor3 = Color3.fromRGB(255, 140, 20)
	odFill.BorderSizePixel = 0
	odFill.Parent = odBg

	overheadHpFill = hpFill
	overheadHpNotches = hpNotches
	overheadXpFill = xpFill
	overheadXpNotches = xpNotches
	overheadOdFill = odFill
	lastExpectedHpNotches = -1
	lastExpectedXpNotches = -1

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
