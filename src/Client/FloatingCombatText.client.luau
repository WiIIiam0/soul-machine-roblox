--!strict
-- FloatingCombatText.client.luau: Animated 3D damage numbers, crits, heals, and burn ticks

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local floatingEvent = Remotes.GetEvent("FloatingText")

local fctFolder: Folder

local function getFctFolder(): Folder
	if not fctFolder or not fctFolder.Parent then
		local found = Workspace:FindFirstChild("CombatTextFolder") :: Folder?
		if not found then
			found = Instance.new("Folder")
			found.Name = "CombatTextFolder"
			found.Parent = Workspace
		end
		fctFolder = found
	end
	return fctFolder
end

floatingEvent.OnClientEvent:Connect(function(pos: Vector3, text: string, color: Color3, isCrit: boolean)
	local attachPart = Instance.new("Part")
	attachPart.Name = "FCT_Anchor"
	attachPart.Size = Vector3.new(0.1, 0.1, 0.1)
	attachPart.Transparency = 1
	attachPart.CanCollide = false
	attachPart.Anchored = true
	attachPart.Position = pos + Vector3.new(math.random(-10, 10) * 0.1, 0, math.random(-10, 10) * 0.1)
	attachPart.Parent = getFctFolder()

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageUI"
	billboard.Adornee = attachPart
	billboard.Size = if isCrit then UDim2.new(0, 120, 0, 32) else UDim2.new(0, 80, 0, 24)
	billboard.AlwaysOnTop = true
	billboard.Parent = attachPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = if isCrit then Enum.Font.GothamBlack else Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Parent = billboard

	-- Float up tween
	local targetPos = attachPart.Position + Vector3.new(0, if isCrit then 4.5 else 3.2, 0)
	local moveTween = TweenService:Create(attachPart, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = targetPos,
	})

	-- Fade out tween
	local fadeTween = TweenService:Create(label, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	moveTween:Play()
	fadeTween:Play()

	fadeTween.Completed:Connect(function()
		attachPart:Destroy()
	end)
end)
