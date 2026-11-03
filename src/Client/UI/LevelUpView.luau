--!strict
-- LevelUpView.luau: Responsive Level-Up 3-card selection modal with 15s countdown timer

local RunService = game:GetService("RunService")

local TextureResolver = require(script.Parent.TextureResolver)

local LevelUpView = {}

export type LevelUpController = {
	modal: Frame,
	ApplyViewport: (vp: Vector2, topInset: number) -> (),
	Open: (cards: { any }) -> (),
}

function LevelUpView.Create(parentGui: ScreenGui, onSelectChoice: (index: number) -> ()): LevelUpController
	local levelUpModal = Instance.new("Frame")
	levelUpModal.Name = "LevelUpModal"
	levelUpModal.Size = UDim2.new(1, 0, 1, 0)
	levelUpModal.Position = UDim2.new(0, 0, 0, 0)
	levelUpModal.BackgroundColor3 = Color3.fromRGB(8, 12, 24)
	levelUpModal.BackgroundTransparency = 0.14
	levelUpModal.BorderSizePixel = 0
	levelUpModal.Visible = false
	levelUpModal.ZIndex = 100
	levelUpModal.Parent = parentGui

	-- Centered content wrapper with its own deterministic UIScale
	local contentRoot = Instance.new("Frame")
	contentRoot.Name = "ContentRoot"
	contentRoot.Size = UDim2.new(0, 940, 0, 560)
	contentRoot.AnchorPoint = Vector2.new(0.5, 0.5)
	contentRoot.Position = UDim2.new(0.5, 0, 0.5, 0)
	contentRoot.BackgroundTransparency = 1
	contentRoot.Parent = levelUpModal

	local modalScale = Instance.new("UIScale")
	modalScale.Name = "ModalScale"
	modalScale.Parent = contentRoot

	local modalTitle = Instance.new("TextLabel")
	modalTitle.Name = "Title"
	modalTitle.Size = UDim2.new(1, 0, 0, 40)
	modalTitle.Position = UDim2.new(0.5, 0, 0, 0)
	modalTitle.AnchorPoint = Vector2.new(0.5, 0)
	modalTitle.BackgroundTransparency = 1
	modalTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	modalTitle.Font = Enum.Font.GothamBlack
	modalTitle.TextSize = 32
	modalTitle.Text = "NIVEAU SUPÉRIEUR"
	modalTitle.Parent = contentRoot

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Size = UDim2.new(1, 0, 0, 22)
	subtitleLabel.Position = UDim2.new(0.5, 0, 0, 42)
	subtitleLabel.AnchorPoint = Vector2.new(0.5, 0)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
	subtitleLabel.Font = Enum.Font.GothamMedium
	subtitleLabel.TextSize = 15
	subtitleLabel.Text = "Choisissez une amélioration pour votre Mécha"
	subtitleLabel.Parent = contentRoot

	local timerContainer = Instance.new("Frame")
	timerContainer.Name = "TimerContainer"
	timerContainer.Size = UDim2.new(0, 340, 0, 22)
	timerContainer.Position = UDim2.new(0.5, 0, 0, 72)
	timerContainer.AnchorPoint = Vector2.new(0.5, 0)
	timerContainer.BackgroundColor3 = Color3.fromRGB(15, 20, 35)
	timerContainer.BorderSizePixel = 0
	timerContainer.Parent = contentRoot

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
	cardsHolder.Size = UDim2.new(1, 0, 0, 420)
	cardsHolder.Position = UDim2.new(0.5, 0, 0, 118)
	cardsHolder.AnchorPoint = Vector2.new(0.5, 0)
	cardsHolder.BackgroundTransparency = 1
	cardsHolder.Parent = contentRoot

	local cardsLayout = Instance.new("UIListLayout")
	cardsLayout.Name = "CardsLayout"
	cardsLayout.FillDirection = Enum.FillDirection.Horizontal
	cardsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	cardsLayout.Padding = UDim.new(0, 22)
	cardsLayout.Parent = cardsHolder

	local countdownRemaining = 15.0
	local countdownActive = false
	local currentCompactMode = false
	local activeCardsData: { any } = {}

	local function pickChoice(index: number)
		if not countdownActive then return end
		countdownActive = false
		levelUpModal.Visible = false
		onSelectChoice(index)
	end

	local function createChoiceCard(index: number, cardData: any, compactVertical: boolean)
		local card = Instance.new("Frame")
		card.Name = "Card_" .. index
		card.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
		card.BackgroundTransparency = 0.08
		card.BorderSizePixel = 0
		card.Parent = cardsHolder

		local rarityColor = cardData.rarityColor or Color3.fromRGB(0, 200, 255)

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, if compactVertical then 12 else 20)
		cCorner.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = rarityColor
		cStroke.Thickness = 2.0
		cStroke.Parent = card

		if compactVertical then
			card.Size = UDim2.new(0, 440, 0, 108)

			local categoryBadge = Instance.new("TextLabel")
			categoryBadge.Name = "CategoryBadge"
			categoryBadge.Size = UDim2.new(0, 76, 0, 16)
			categoryBadge.Position = UDim2.new(0, 10, 0, 6)
			categoryBadge.BackgroundColor3 = Color3.fromRGB(10, 20, 30)
			categoryBadge.TextColor3 = rarityColor
			categoryBadge.Font = Enum.Font.GothamBlack
			categoryBadge.TextSize = 9
			categoryBadge.TextWrapped = false
			categoryBadge.Text = cardData.category or "UPGRADE"
			categoryBadge.Parent = card

			local catCorner = Instance.new("UICorner")
			catCorner.CornerRadius = UDim.new(0, 4)
			catCorner.Parent = categoryBadge

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
			iStroke.Color = rarityColor
			iStroke.Thickness = 1.5
			iStroke.Parent = iconBox

			if cardData.isComposite == true then
				iconBox.ClipsDescendants = true

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
				diag.Parent = iconBox

				local tRes = TextureResolver.Resolve(cardData.triggerIconFile, cardData.triggerIcon)
				local trigColor = cardData.triggerColor or Color3.new(1, 1, 1)
				if tRes and tRes ~= "" then
					local tImg = Instance.new("ImageLabel")
					tImg.Name = "TriggerIcon"
					tImg.Size = UDim2.new(0, 24, 0, 24)
					tImg.Position = UDim2.new(0, 3, 0, 3)
					tImg.BackgroundTransparency = 1
					tImg.Image = tRes
					tImg.ImageColor3 = trigColor
					tImg.ZIndex = 3
					tImg.Parent = iconBox
				else
					local tLbl = Instance.new("TextLabel")
					tLbl.Name = "TriggerTag"
					tLbl.Size = UDim2.new(0, 24, 0, 24)
					tLbl.Position = UDim2.new(0, 2, 0, 2)
					tLbl.BackgroundTransparency = 1
					tLbl.TextColor3 = trigColor
					tLbl.Font = Enum.Font.GothamBlack
					tLbl.TextSize = 9
					tLbl.Text = cardData.triggerTag or "TRG"
					tLbl.ZIndex = 3
					tLbl.Parent = iconBox
				end

				local eRes = TextureResolver.Resolve(cardData.effectIconFile, cardData.effectIcon)
				local effColor = cardData.effectColor or Color3.new(1, 1, 1)
				if eRes and eRes ~= "" then
					local eImg = Instance.new("ImageLabel")
					eImg.Name = "EffectIcon"
					eImg.Size = UDim2.new(0, 24, 0, 24)
					eImg.Position = UDim2.new(1, -27, 1, -27)
					eImg.BackgroundTransparency = 1
					eImg.Image = eRes
					eImg.ImageColor3 = effColor
					eImg.ZIndex = 3
					eImg.Parent = iconBox
				else
					local eLbl = Instance.new("TextLabel")
					eLbl.Name = "EffectTag"
					eLbl.Size = UDim2.new(0, 24, 0, 24)
					eLbl.Position = UDim2.new(1, -26, 1, -26)
					eLbl.BackgroundTransparency = 1
					eLbl.TextColor3 = effColor
					eLbl.Font = Enum.Font.GothamBlack
					eLbl.TextSize = 9
					eLbl.Text = cardData.effectTag or "EFF"
					eLbl.ZIndex = 3
					eLbl.Parent = iconBox
				end
			else
				iconBox.ClipsDescendants = false

				local iconBadge = Instance.new("TextLabel")
				iconBadge.Name = "IconBadge"
				iconBadge.Size = UDim2.new(1, -4, 1, -4)
				iconBadge.Position = UDim2.new(0, 2, 0, 2)
				iconBadge.BackgroundTransparency = 1
				iconBadge.Text = cardData.tag or string.sub(tostring(cardData.title or ""), 1, 6):upper()
				iconBadge.TextColor3 = cardData.iconColor or rarityColor
				iconBadge.Font = Enum.Font.GothamBlack
				iconBadge.TextSize = 9
				iconBadge.TextWrapped = true
				iconBadge.ZIndex = 1
				iconBadge.Parent = iconBox

				local resolvedImage = TextureResolver.Resolve(cardData.iconFile, cardData.icon)
				if resolvedImage and resolvedImage ~= "" then
					local iconImg = Instance.new("ImageLabel")
					iconImg.Size = UDim2.new(1, -6, 1, -6)
					iconImg.Position = UDim2.new(0, 3, 0, 3)
					iconImg.BackgroundTransparency = 1
					iconImg.Image = resolvedImage
					iconImg.ImageColor3 = cardData.iconColor or Color3.new(1, 1, 1)
					iconImg.ZIndex = 2
					iconImg.Parent = iconBox
					iconBadge.Visible = false
				end
			end

			local title = Instance.new("TextLabel")
			title.Name = "Title"
			title.Size = UDim2.new(1, -190, 0, 18)
			title.Position = UDim2.new(0, 78, 0, 8)
			title.BackgroundTransparency = 1
			title.TextColor3 = Color3.fromRGB(255, 255, 255)
			title.Font = Enum.Font.GothamBlack
			title.TextSize = 13
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextTruncate = Enum.TextTruncate.AtEnd
			title.TextWrapped = false
			title.Text = tostring(cardData.title or "")
			title.Parent = card

			local subLabel = Instance.new("TextLabel")
			subLabel.Name = "SubLabel"
			subLabel.Size = UDim2.new(1, -190, 0, 15)
			subLabel.Position = UDim2.new(0, 78, 0, 26)
			subLabel.BackgroundTransparency = 1
			subLabel.TextColor3 = rarityColor
			subLabel.Font = Enum.Font.GothamBold
			subLabel.TextSize = 10
			subLabel.TextXAlignment = Enum.TextXAlignment.Left
			subLabel.TextWrapped = false
			subLabel.Text = tostring(cardData.subtitle or "")
			subLabel.Parent = card

			local desc = Instance.new("TextLabel")
			desc.Name = "Desc"
			desc.Size = UDim2.new(1, -190, 0, 54)
			desc.Position = UDim2.new(0, 78, 0, 44)
			desc.BackgroundTransparency = 1
			desc.TextColor3 = Color3.fromRGB(190, 215, 255)
			desc.Font = Enum.Font.Gotham
			desc.TextSize = 10
			desc.TextWrapped = true
			desc.TextXAlignment = Enum.TextXAlignment.Left
			desc.TextYAlignment = Enum.TextYAlignment.Top
			desc.Text = tostring(cardData.description or "")
			desc.Parent = card

			local selectBtn = Instance.new("TextButton")
			selectBtn.Name = "SelectBtn"
			selectBtn.Size = UDim2.new(0, 92, 0, 38)
			selectBtn.Position = UDim2.new(1, -102, 0.5, -19)
			selectBtn.BackgroundColor3 = rarityColor
			selectBtn.TextColor3 = Color3.fromRGB(10, 15, 25)
			selectBtn.Font = Enum.Font.GothamBlack
			selectBtn.TextSize = 12
			selectBtn.Text = "CHOISIR"
			selectBtn.Parent = card

			local btnCorner = Instance.new("UICorner")
			btnCorner.CornerRadius = UDim.new(0, 6)
			btnCorner.Parent = selectBtn

			selectBtn.Activated:Connect(function()
				pickChoice(index)
			end)
		else
			card.Size = UDim2.new(0, 280, 0, 400)

			local categoryBadge = Instance.new("TextLabel")
			categoryBadge.Name = "CategoryBadge"
			categoryBadge.Size = UDim2.new(0, 130, 0, 28)
			categoryBadge.Position = UDim2.new(0.5, -65, 0, -14)
			categoryBadge.BackgroundColor3 = Color3.fromRGB(10, 20, 30)
			categoryBadge.TextColor3 = rarityColor
			categoryBadge.Font = Enum.Font.GothamBlack
			categoryBadge.TextSize = 11
			categoryBadge.TextWrapped = false
			categoryBadge.Text = cardData.category or "UPGRADE"
			categoryBadge.Parent = card

			local catCorner = Instance.new("UICorner")
			catCorner.CornerRadius = UDim.new(0, 8)
			catCorner.Parent = categoryBadge

			local catStroke = Instance.new("UIStroke")
			catStroke.Color = rarityColor
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
			title.Text = tostring(cardData.title or "")
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
			iStroke.Color = rarityColor
			iStroke.Thickness = 2
			iStroke.Transparency = 0.3
			iStroke.Parent = iconBox

			if cardData.isComposite == true then
				iconBox.ClipsDescendants = true

				local diag = Instance.new("Frame")
				diag.Name = "Diagonal"
				diag.Size = UDim2.new(1.42, 0, 0, 1.5)
				diag.AnchorPoint = Vector2.new(0.5, 0.5)
				diag.Position = UDim2.new(0.5, 0, 0.5, 0)
				diag.Rotation = -45
				diag.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				diag.BackgroundTransparency = 0.65
				diag.BorderSizePixel = 0
				diag.ZIndex = 2
				diag.Parent = iconBox

				local tRes = TextureResolver.Resolve(cardData.triggerIconFile, cardData.triggerIcon)
				local trigColor = cardData.triggerColor or Color3.new(1, 1, 1)
				if tRes and tRes ~= "" then
					local tImg = Instance.new("ImageLabel")
					tImg.Name = "TriggerIcon"
					tImg.Size = UDim2.new(0, 34, 0, 34)
					tImg.Position = UDim2.new(0, 4, 0, 4)
					tImg.BackgroundTransparency = 1
					tImg.Image = tRes
					tImg.ImageColor3 = trigColor
					tImg.ZIndex = 3
					tImg.Parent = iconBox
				else
					local tLbl = Instance.new("TextLabel")
					tLbl.Name = "TriggerTag"
					tLbl.Size = UDim2.new(0, 34, 0, 34)
					tLbl.Position = UDim2.new(0, 3, 0, 3)
					tLbl.BackgroundTransparency = 1
					tLbl.TextColor3 = trigColor
					tLbl.Font = Enum.Font.GothamBlack
					tLbl.TextSize = 11
					tLbl.Text = cardData.triggerTag or "TRG"
					tLbl.ZIndex = 3
					tLbl.Parent = iconBox
				end

				local eRes = TextureResolver.Resolve(cardData.effectIconFile, cardData.effectIcon)
				local effColor = cardData.effectColor or Color3.new(1, 1, 1)
				if eRes and eRes ~= "" then
					local eImg = Instance.new("ImageLabel")
					eImg.Name = "EffectIcon"
					eImg.Size = UDim2.new(0, 34, 0, 34)
					eImg.Position = UDim2.new(1, -38, 1, -38)
					eImg.BackgroundTransparency = 1
					eImg.Image = eRes
					eImg.ImageColor3 = effColor
					eImg.ZIndex = 3
					eImg.Parent = iconBox
				else
					local eLbl = Instance.new("TextLabel")
					eLbl.Name = "EffectTag"
					eLbl.Size = UDim2.new(0, 34, 0, 34)
					eLbl.Position = UDim2.new(1, -37, 1, -37)
					eLbl.BackgroundTransparency = 1
					eLbl.TextColor3 = effColor
					eLbl.Font = Enum.Font.GothamBlack
					eLbl.TextSize = 11
					eLbl.Text = cardData.effectTag or "EFF"
					eLbl.ZIndex = 3
					eLbl.Parent = iconBox
				end
			else
				iconBox.ClipsDescendants = false

				local iconBadge = Instance.new("TextLabel")
				iconBadge.Name = "IconBadge"
				iconBadge.Size = UDim2.new(1, -8, 1, -8)
				iconBadge.Position = UDim2.new(0, 4, 0, 4)
				iconBadge.BackgroundTransparency = 1
				iconBadge.Text = cardData.tag or string.sub(tostring(cardData.title or ""), 1, 10):upper()
				iconBadge.TextColor3 = cardData.iconColor or rarityColor
				iconBadge.Font = Enum.Font.GothamBlack
				iconBadge.TextSize = 11
				iconBadge.TextWrapped = true
				iconBadge.ZIndex = 1
				iconBadge.Parent = iconBox

				local resolvedImage = TextureResolver.Resolve(cardData.iconFile, cardData.icon)
				if resolvedImage and resolvedImage ~= "" then
					local iconImg = Instance.new("ImageLabel")
					iconImg.Size = UDim2.new(1, -10, 1, -10)
					iconImg.Position = UDim2.new(0, 5, 0, 5)
					iconImg.BackgroundTransparency = 1
					iconImg.Image = resolvedImage
					iconImg.ImageColor3 = cardData.iconColor or Color3.new(1, 1, 1)
					iconImg.ZIndex = 2
					iconImg.Parent = iconBox
					iconBadge.Visible = false
				end
			end

			local subLabel = Instance.new("TextLabel")
			subLabel.Name = "SubLabel"
			subLabel.Size = UDim2.new(1, -20, 0, 24)
			subLabel.Position = UDim2.new(0, 10, 0, 178)
			subLabel.BackgroundTransparency = 1
			subLabel.TextColor3 = rarityColor
			subLabel.Font = Enum.Font.GothamBold
			subLabel.TextSize = 12
			subLabel.TextWrapped = false
			subLabel.Text = tostring(cardData.subtitle or "")
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
			desc.Text = tostring(cardData.description or "")
			desc.Parent = card

			local selectBtn = Instance.new("TextButton")
			selectBtn.Name = "SelectBtn"
			selectBtn.Size = UDim2.new(1, -30, 0, 42)
			selectBtn.Position = UDim2.new(0, 15, 1, -54)
			selectBtn.BackgroundColor3 = rarityColor
			selectBtn.TextColor3 = Color3.fromRGB(10, 15, 25)
			selectBtn.Font = Enum.Font.GothamBlack
			selectBtn.TextSize = 14
			selectBtn.Text = "SÉLECTIONNER"
			selectBtn.Parent = card

			local btnCorner = Instance.new("UICorner")
			btnCorner.CornerRadius = UDim.new(0, 8)
			btnCorner.Parent = selectBtn

			selectBtn.Activated:Connect(function()
				pickChoice(index)
			end)
		end
	end

	local function rebuildCards()
		for _, child in ipairs(cardsHolder:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for idx, cardData in ipairs(activeCardsData) do
			if idx <= 3 then
				createChoiceCard(idx, cardData, currentCompactMode)
			end
		end
	end

	local function applyViewport(vp: Vector2, topInset: number)
		local availW = math.max(240, vp.X - 28)
		local availH = math.max(240, vp.Y - topInset - 28)
		local wantCompact = (vp.X < 680) and (vp.Y > vp.X * 0.9)

		if wantCompact then
			contentRoot.Size = UDim2.new(0, 460, 0, 460)
			contentRoot.Position = UDim2.new(0.5, 0, 0.5, math.floor(topInset * 0.5))
			modalTitle.TextSize = 24
			subtitleLabel.Position = UDim2.new(0.5, 0, 0, 32)
			subtitleLabel.TextSize = 13
			timerContainer.Position = UDim2.new(0.5, 0, 0, 58)
			timerContainer.Size = UDim2.new(0, 320, 0, 20)
			cardsHolder.Position = UDim2.new(0.5, 0, 0, 90)
			cardsHolder.Size = UDim2.new(1, 0, 0, 360)
			cardsLayout.FillDirection = Enum.FillDirection.Vertical
			cardsLayout.Padding = UDim.new(0, 10)
			modalScale.Scale = math.clamp(math.min(availW / 460, availH / 460), 0.52, 1.05)
		else
			contentRoot.Size = UDim2.new(0, 940, 0, 540)
			contentRoot.Position = UDim2.new(0.5, 0, 0.5, math.floor(topInset * 0.5))
			modalTitle.TextSize = 32
			subtitleLabel.Position = UDim2.new(0.5, 0, 0, 42)
			subtitleLabel.TextSize = 15
			timerContainer.Position = UDim2.new(0.5, 0, 0, 72)
			timerContainer.Size = UDim2.new(0, 340, 0, 22)
			cardsHolder.Position = UDim2.new(0.5, 0, 0, 118)
			cardsHolder.Size = UDim2.new(1, 0, 0, 410)
			cardsLayout.FillDirection = Enum.FillDirection.Horizontal
			cardsLayout.Padding = UDim.new(0, 22)
			modalScale.Scale = math.clamp(math.min(availW / 940, availH / 540), 0.45, 1.12)
		end

		if wantCompact ~= currentCompactMode then
			currentCompactMode = wantCompact
			if levelUpModal.Visible and #activeCardsData > 0 then
				rebuildCards()
			end
		end
	end

	local function openModal(cards: { any })
		activeCardsData = cards
		rebuildCards()
		countdownRemaining = 15.0
		countdownActive = true
		timerFill.Size = UDim2.new(1, 0, 1, 0)
		timerLabel.Text = "TEMPS RESTANT : 15s"
		levelUpModal.Visible = true
	end

	RunService.Heartbeat:Connect(function(dt: number)
		if countdownActive and levelUpModal.Visible then
			countdownRemaining -= dt
			local ratio = math.clamp(countdownRemaining / 15.0, 0, 1)
			timerFill.Size = UDim2.new(ratio, 0, 1, 0)
			timerLabel.Text = string.format("TEMPS RESTANT : %.1fs", math.max(0, countdownRemaining))

			if countdownRemaining <= 0 then
				pickChoice(1)
			end
		end
	end)

	return {
		modal = levelUpModal,
		ApplyViewport = applyViewport,
		Open = openModal,
	}
end

return LevelUpView
