--!strict
-- HudOverlays.luau: Damage vignette, Top toast banner, Game Over summary modal, and Zone Warp overlay

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local HudOverlays = {}

export type OverlaysController = {
	TriggerDamageFlash: () -> (),
	PresentBanner: (titleText: string, descText: string, duration: number) -> (),
	ShowGameOver: (summaryText: string?) -> (),
	SetWarpOverlay: (visible: boolean, targetZoneText: string?) -> (),
	ApplyViewport: (vp: Vector2, baseScale: number) -> (),
}

function HudOverlays.Create(screenGui: ScreenGui, vfxGui: ScreenGui, onRestartRun: () -> ()): OverlaysController
	-- 1. Fullscreen Damage Flash
	local damageFlash = Instance.new("Frame")
	damageFlash.Name = "DamageFlash"
	damageFlash.Size = UDim2.new(1, 0, 1, 0)
	damageFlash.BackgroundColor3 = Color3.fromRGB(220, 20, 30)
	damageFlash.BackgroundTransparency = 1
	damageFlash.BorderSizePixel = 0
	damageFlash.ZIndex = 5
	damageFlash.Active = false
	damageFlash.Parent = vfxGui

	local function triggerDamageFlash()
		damageFlash.BackgroundTransparency = 0.65
		TweenService:Create(damageFlash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
	end

	-- 2. Notification Banner (Global Unlock & Portal Alerts)
	local globalLevelUpBanner = Instance.new("Frame")
	globalLevelUpBanner.Name = "GlobalLevelUpBanner"
	globalLevelUpBanner.Size = UDim2.new(0, 520, 0, 82)
	globalLevelUpBanner.Position = UDim2.new(0.5, 0, 0, -120)
	globalLevelUpBanner.AnchorPoint = Vector2.new(0.5, 0)
	globalLevelUpBanner.BackgroundColor3 = Color3.fromRGB(16, 22, 36)
	globalLevelUpBanner.BackgroundTransparency = 0.08
	globalLevelUpBanner.BorderSizePixel = 0
	globalLevelUpBanner.ZIndex = 200
	globalLevelUpBanner.Visible = false
	globalLevelUpBanner.Parent = screenGui

	local bannerScale = Instance.new("UIScale")
	bannerScale.Name = "BannerScale"
	bannerScale.Parent = globalLevelUpBanner

	local gbCorner = Instance.new("UICorner")
	gbCorner.CornerRadius = UDim.new(0, 10)
	gbCorner.Parent = globalLevelUpBanner

	local gbStroke = Instance.new("UIStroke")
	gbStroke.Color = Color3.fromRGB(255, 215, 50)
	gbStroke.Thickness = 2
	gbStroke.Parent = globalLevelUpBanner

	local gbTitle = Instance.new("TextLabel")
	gbTitle.Name = "Title"
	gbTitle.Size = UDim2.new(1, -20, 0, 26)
	gbTitle.Position = UDim2.new(0, 10, 0, 8)
	gbTitle.BackgroundTransparency = 1
	gbTitle.TextColor3 = Color3.fromRGB(255, 225, 70)
	gbTitle.Font = Enum.Font.GothamBlack
	gbTitle.TextSize = 14
	gbTitle.TextWrapped = false
	gbTitle.TextTruncate = Enum.TextTruncate.AtEnd
	gbTitle.Text = "★ PALIER D'ADN DÉBLOQUÉ ★"
	gbTitle.Parent = globalLevelUpBanner

	local gbDesc = Instance.new("TextLabel")
	gbDesc.Name = "Desc"
	gbDesc.Size = UDim2.new(1, -24, 0, 40)
	gbDesc.Position = UDim2.new(0, 12, 0, 34)
	gbDesc.BackgroundTransparency = 1
	gbDesc.TextColor3 = Color3.fromRGB(220, 240, 255)
	gbDesc.Font = Enum.Font.GothamMedium
	gbDesc.TextSize = 12
	gbDesc.TextWrapped = true
	gbDesc.Text = ""
	gbDesc.Parent = globalLevelUpBanner

	local bannerGeneration = 0
	local function presentBanner(titleText: string, descText: string, duration: number)
		-- Disabled intrusive fullscreen banner overlay (user requested no obstructive canvas frames)
		globalLevelUpBanner.Visible = false
	end

	-- 3. Game Over Summary Modal
	local gameOverModal = Instance.new("Frame")
	gameOverModal.Name = "GameOverModal"
	gameOverModal.Size = UDim2.new(1, 0, 1, 0)
	gameOverModal.BackgroundColor3 = Color3.fromRGB(8, 10, 18)
	gameOverModal.BackgroundTransparency = 0.15
	gameOverModal.BorderSizePixel = 0
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

	local goScale = Instance.new("UIScale")
	goScale.Name = "GoScale"
	goScale.Parent = goCard

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
	goStatsText.TextWrapped = true
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
		onRestartRun()
	end)

	-- 4. Zone Warp Fullscreen Overlay
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
	warpLabel.TextWrapped = true
	warpLabel.TextColor3 = Color3.fromRGB(0, 240, 255)
	warpLabel.Text = "TRANSFERT INTER-SERVEURS EN COURS..."
	warpLabel.Parent = warpOverlay

	local function showGameOver(summaryText: string?)
		if summaryText then
			goStatsText.Text = summaryText
		end
		gameOverModal.Visible = true
	end

	local function setWarpOverlay(visible: boolean, targetZoneText: string?)
		if visible and targetZoneText then
			warpLabel.Text = "⚡ TRANSFERT VERS " .. targetZoneText .. "..."
		end
		warpOverlay.Visible = visible
	end

	local function applyViewport(vp: Vector2, baseScale: number)
		bannerScale.Scale = math.clamp(math.min(baseScale, (vp.X - 24) / 520), 0.50, 1.08)
		goScale.Scale = math.clamp(math.min(baseScale, (vp.X - 28) / 460, (vp.Y - 40) / 380), 0.50, 1.10)
	end

	return {
		TriggerDamageFlash = triggerDamageFlash,
		PresentBanner = presentBanner,
		ShowGameOver = showGameOver,
		SetWarpOverlay = setWarpOverlay,
		ApplyViewport = applyViewport,
	}
end

return HudOverlays
