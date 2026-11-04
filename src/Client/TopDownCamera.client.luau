--!strict
-- TopDownCamera.client.luau: Top-Down camera, auto-aim targeting nearest enemies, and drift-free movement controller

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local CAMERA_OFFSET = Vector3.new(0, 42, 28)

camera.CameraType = Enum.CameraType.Scriptable

-- 1. Free and visible mouse cursor for clicking UI
UserInputService.MouseBehavior = Enum.MouseBehavior.Default
UserInputService.MouseIconEnabled = true

UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(function()
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

-- 2. Disable default Roblox ControlModule to eliminate any ClickToMove or camera-relative drift
task.spawn(function()
	local playerScripts = player:WaitForChild("PlayerScripts", 10)
	if not playerScripts then return end
	local playerModuleScript = playerScripts:WaitForChild("PlayerModule", 10)
	if not playerModuleScript then return end

	local success, playerModule = pcall(require, playerModuleScript)
	if success and playerModule and typeof(playerModule.GetControls) == "function" then
		local controls = playerModule:GetControls()
		if controls and typeof(controls.Disable) == "function" then
			controls:Disable()
		end
	end
end)

-- 3. Target Lock-On Indicator UI
local targetBillboard = Instance.new("BillboardGui")
targetBillboard.Name = "TargetLockReticle"
targetBillboard.Size = UDim2.new(0, 44, 0, 44)
targetBillboard.AlwaysOnTop = true
targetBillboard.Enabled = false
targetBillboard.Parent = player:WaitForChild("PlayerGui")

local reticleCircle = Instance.new("Frame")
reticleCircle.Name = "ReticleCircle"
reticleCircle.Size = UDim2.new(1, 0, 1, 0)
reticleCircle.BackgroundTransparency = 1
reticleCircle.Parent = targetBillboard

local reticleStroke = Instance.new("UIStroke")
reticleStroke.Color = Color3.fromRGB(255, 60, 90)
reticleStroke.Thickness = 2
reticleStroke.Transparency = 0.15
reticleStroke.Parent = reticleCircle

local reticleCorner = Instance.new("UICorner")
reticleCorner.CornerRadius = UDim.new(0.5, 0)
reticleCorner.Parent = reticleCircle

local centerDot = Instance.new("Frame")
centerDot.Name = "CenterDot"
centerDot.Size = UDim2.new(0, 6, 0, 6)
centerDot.Position = UDim2.new(0.5, -3, 0.5, -3)
centerDot.BackgroundColor3 = Color3.fromRGB(255, 60, 90)
centerDot.BorderSizePixel = 0
centerDot.Parent = reticleCircle

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(0.5, 0)
dotCorner.Parent = centerDot

local function updateTargetReticle(targetPart: BasePart?)
	if targetPart and targetPart.Parent then
		targetBillboard.Adornee = targetPart
		targetBillboard.Enabled = true
	else
		targetBillboard.Enabled = false
		targetBillboard.Adornee = nil
	end
end

-- 4. Mobile Touch Drag Movement (Left Half of Screen)
local touchMoveDir = Vector3.zero
local touchStartPos: Vector2? = nil
local activeTouchInput: InputObject? = nil

UserInputService.TouchStarted:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	local pos = input.Position
	local screenWidth = camera.ViewportSize.X
	if pos.X < screenWidth * 0.5 and not activeTouchInput then
		activeTouchInput = input
		touchStartPos = Vector2.new(pos.X, pos.Y)
		touchMoveDir = Vector3.zero
	end
end)

UserInputService.TouchMoved:Connect(function(input: InputObject, gameProcessed: boolean)
	if input == activeTouchInput and touchStartPos then
		local currentPos = Vector2.new(input.Position.X, input.Position.Y)
		local delta = currentPos - touchStartPos
		if delta.Magnitude > 14 then
			local dir = delta.Unit
			touchMoveDir = Vector3.new(dir.X, 0, dir.Y)
		else
			touchMoveDir = Vector3.zero
		end
	end
end)

local function onTouchEnded(input: InputObject)
	if input == activeTouchInput then
		activeTouchInput = nil
		touchStartPos = nil
		touchMoveDir = Vector3.zero
	end
end

UserInputService.TouchEnded:Connect(onTouchEnded)

local jointOriginalC0: { [Motor6D]: CFrame } = {}

local function getOriginalC0(motor: Motor6D): CFrame
	local orig = jointOriginalC0[motor]
	if not orig then
		orig = motor.C0
		jointOriginalC0[motor] = orig
	end
	return orig
end

local cachedChar: Model? = nil
local cachedNeck: Motor6D? = nil
local cachedWaist: Motor6D? = nil
local cachedRightShoulder: Motor6D? = nil
local cachedRootJoint: Motor6D? = nil

local function getCharacterJoints(char: Model)
	if cachedChar == char and cachedNeck and cachedNeck.Parent then
		return cachedNeck, cachedWaist, cachedRightShoulder, cachedRootJoint
	end

	cachedChar = char
	cachedNeck = nil
	cachedWaist = nil
	cachedRightShoulder = nil
	cachedRootJoint = nil

	for _, desc in ipairs(char:GetDescendants()) do
		if desc:IsA("Motor6D") then
			local n = string.lower(desc.Name):gsub("%s+", "")
			if n == "neck" then
				cachedNeck = desc
				getOriginalC0(desc)
			elseif n == "waist" then
				cachedWaist = desc
				getOriginalC0(desc)
			elseif n == "rightshoulder" then
				cachedRightShoulder = desc
				getOriginalC0(desc)
			elseif n == "root" or n == "rootjoint" then
				cachedRootJoint = desc
				getOriginalC0(desc)
			end
		end
	end

	return cachedNeck, cachedWaist, cachedRightShoulder, cachedRootJoint
end

-- 5. Character Rotation Setup (AlignOrientation: smooth torque, zero physics conflict)
local function setupCharacter(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hrp or not humanoid then return end

	humanoid.AutoRotate = false
	currentFacingDir = nil

	getCharacterJoints(character)

	local rootAttachment = hrp:FindFirstChild("RootAttachment") :: Attachment?
	if not rootAttachment then
		rootAttachment = Instance.new("Attachment")
		rootAttachment.Name = "RootAttachment"
		rootAttachment.Parent = hrp
	end

	local alignRot = hrp:FindFirstChild("MechaAimOrientation") :: AlignOrientation?
	if not alignRot then
		alignRot = Instance.new("AlignOrientation")
		alignRot.Name = "MechaAimOrientation"
		alignRot.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignRot.Attachment0 = rootAttachment
		alignRot.RigidityEnabled = true
		alignRot.Parent = hrp
	end
end

if player.Character then
	task.spawn(setupCharacter, player.Character)
end
player.CharacterAdded:Connect(setupCharacter)

local lastAimDir: Vector3? = nil
local lastMoveFacingDir: Vector3? = nil
local currentFacingDir: Vector3? = nil

local function isPlayerFrozenInLevelUp(): boolean
	if player:GetAttribute("IsLevelUpFrozen") == true then
		return true
	end
	local pGui = player:FindFirstChild("PlayerGui")
	local hud = if pGui then pGui:FindFirstChild("SoulMachineHUD") else nil
	local modal = if hud then hud:FindFirstChild("LevelUpModal") :: Frame? else nil
	if modal and modal.Visible then
		return true
	end
	return false
end

-- 6. Movement & Camera Update Loop
local function onRenderStep(dt: number)
	local char = player.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end

	local pPos = hrp.Position

	-- Solid Top-Down Camera
	local targetCamPos = pPos + CAMERA_OFFSET
	local lookTarget = pPos + Vector3.new(0, 1.5, 0)
	camera.CFrame = CFrame.lookAt(targetCamPos, lookTarget)

	-- Immobilisation complète pendant le choix d'amélioration (Level-Up)
	if isPlayerFrozenInLevelUp() then
		touchMoveDir = Vector3.zero
		humanoid:Move(Vector3.zero, false)
		updateTargetReticle(nil)
		return
	end

	-- Direct Keyboard Movement (WASD + ZQSD + Arrows)
	local moveX = 0
	local moveZ = 0

	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Z) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		moveZ -= 1 -- Up on screen (-Z)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		moveZ += 1 -- Down on screen (+Z)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		moveX -= 1 -- Left on screen (-X)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		moveX += 1 -- Right on screen (+X)
	end

	local moveDir = Vector3.new(moveX, 0, moveZ)

	-- Mobile Touch Movement
	if touchMoveDir.Magnitude > 0.05 then
		moveDir = touchMoveDir
	end

	-- Gamepad support with 0.25 deadzone
	local gamepads = UserInputService:GetConnectedGamepads()
	if #gamepads > 0 then
		local states = UserInputService:GetGamepadState(gamepads[1])
		for _, state in ipairs(states) do
			if state.KeyCode == Enum.KeyCode.Thumbstick1 then
				local stickPos = state.Position
				if stickPos.Magnitude > 0.25 then
					moveDir = Vector3.new(stickPos.X, 0, -stickPos.Y)
				end
			end
		end
	end

	-- Apply Movement: if no keys pressed, explicitly zero out velocity (stops any drift)
	if moveDir.Magnitude > 0.05 then
		humanoid:Move(moveDir.Unit, false)
	else
		humanoid:Move(Vector3.zero, false)
	end

	-- 7. AUTO-AIM AT CLOSEST ENEMY & OPTION A DÉSAXAGE ANATOMIQUE
	local alignRot = hrp:FindFirstChild("MechaAimOrientation") :: AlignOrientation?
	if alignRot then
		local closestPart: BasePart? = nil
		local closestDistSq = 55 * 55 -- 55 studs combat targeting range

		local enemiesFolder = Workspace:FindFirstChild("ActiveEnemies")
		if enemiesFolder then
			for _, enemyModel in ipairs(enemiesFolder:GetChildren()) do
				if enemyModel:IsA("Model") then
					local eRoot = enemyModel.PrimaryPart or enemyModel:FindFirstChild("HumanoidRootPart") :: BasePart?
					if eRoot and eRoot.Parent then
						local dx = eRoot.Position.X - pPos.X
						local dz = eRoot.Position.Z - pPos.Z
						local dSq = dx * dx + dz * dz
						if dSq < closestDistSq then
							closestDistSq = dSq
							closestPart = eRoot
						end
					end
				end
			end
		end

		local aimDir: Vector3? = nil

		if closestPart then
			local toEnemy = closestPart.Position - pPos
			local flatToEnemy = Vector3.new(toEnemy.X, 0, toEnemy.Z)
			if flatToEnemy.Magnitude > 0.1 then
				aimDir = flatToEnemy.Unit
			end
			updateTargetReticle(closestPart)
		else
			updateTargetReticle(nil)
		end

		-- OPTION A : DÉSAXAGE ANATOMIQUE (The Division / Helldivers)
		-- 1. Si on se déplace et qu'un ennemi est devant ou sur les côtés (angle <= 98°) :
		--    Les jambes courent droit dans la direction de la touche. Le torse se désaxe jusqu'à 75° pour viser.
		-- 2. Si l'ennemi passe dans le dos (> 98°) :
		--    Le personnage pivote face à l'ennemi pour lui faire face et le canarder en reculant.
		-- 3. À l'arrêt : le personnage fait face à sa cible.
		-- 4. Hors combat : s'oriente naturellement dans le sens de la course.
		local isMoving = moveDir.Magnitude > 0.05
		local hasCombatTarget = (closestPart ~= nil and aimDir ~= nil)

		local desiredHrpFacing: Vector3

		if isMoving then
			if hasCombatTarget and aimDir then
				local dot = moveDir.Unit:Dot(aimDir)
				if dot >= -0.15 then
					-- Ennemi devant ou sur les flancs (angle <= ~98°) : course avant naturelle
					desiredHrpFacing = moveDir.Unit
					lastMoveFacingDir = moveDir.Unit
				else
					-- Ennemi dans le dos (> 98°) : volte-face pour affronter la cible en reculant
					desiredHrpFacing = aimDir
					lastAimDir = aimDir
				end
			else
				desiredHrpFacing = moveDir.Unit
				lastMoveFacingDir = moveDir.Unit
			end
		elseif hasCombatTarget and aimDir then
			desiredHrpFacing = aimDir
			lastAimDir = aimDir
		elseif lastAimDir then
			desiredHrpFacing = lastAimDir
		elseif lastMoveFacingDir then
			desiredHrpFacing = lastMoveFacingDir
		else
			desiredHrpFacing = Vector3.new(0, 0, -1)
		end

		if not currentFacingDir then
			currentFacingDir = desiredHrpFacing
		else
			local turnSpeed = if hasCombatTarget then 24 else 20
			currentFacingDir = currentFacingDir:Lerp(desiredHrpFacing, math.clamp(dt * turnSpeed, 0, 1)).Unit
		end

		alignRot.CFrame = CFrame.lookAt(Vector3.zero, currentFacingDir)

		-- Articulations du personnage
		local neck, waist, rightShoulder, rootJoint = getCharacterJoints(char)

		if rootJoint then
			rootJoint.C0 = getOriginalC0(rootJoint)
		end

		-- Visée du haut du corps avec désaxage naturel
		if hasCombatTarget and closestPart and aimDir then
			local toEnemy = closestPart.Position - hrp.Position
			local localAim = hrp.CFrame:VectorToObjectSpace(toEnemy)
			local flatDist = math.sqrt(localAim.X * localAim.X + localAim.Z * localAim.Z)

			if flatDist > 0.1 then
				local targetYaw = math.atan2(-localAim.X, -localAim.Z)
				local targetPitch = math.clamp(math.atan2(localAim.Y, flatDist), -math.rad(35), math.rad(35))

				-- 1. Torse (Waist) : désaxage naturel jusqu'à 75°
				local maxWaist = math.rad(75)
				local waistYaw = math.clamp(targetYaw, -maxWaist, maxWaist)
				if waist then
					local origWaist = getOriginalC0(waist)
					waist.C0 = origWaist * CFrame.Angles(0, waistYaw, 0)
				end

				-- 2. Tête (Neck) : regarde la cible (pitch vertical + compensation résiduelle du regard)
				local remainingYaw = targetYaw - waistYaw
				local headYaw = math.clamp(remainingYaw, -math.rad(45), math.rad(45))
				local headPitch = math.clamp(-targetPitch, -math.rad(30), math.rad(30))
				if neck then
					local origNeck = getOriginalC0(neck)
					neck.C0 = origNeck * CFrame.Angles(headPitch, headYaw, 0)
				end

				-- 3. Bras droit (RightShoulder) : lève le blaster et vise la cible avec précision
				if rightShoulder then
					local origRS = getOriginalC0(rightShoulder)
					local armYaw = math.clamp(remainingYaw, -math.rad(30), math.rad(30))

					if humanoid.RigType == Enum.HumanoidRigType.R15 then
						-- En R15 : arm raised forward (-85° sur X) + pitch + armYaw
						local aimOffset = CFrame.Angles(0, armYaw, 0) * CFrame.Angles(-math.rad(85) + targetPitch, 0, math.rad(-3))
						rightShoulder.C0 = origRS * aimOffset
						rightShoulder.Transform = CFrame.identity
					else
						-- En R6
						local aimOffset = CFrame.Angles(0, 0, math.rad(90) + targetPitch) * CFrame.Angles(0, armYaw, 0)
						rightShoulder.C0 = origRS * aimOffset
						rightShoulder.Transform = CFrame.identity
					end
				end
			end
		else
			-- Hors combat : retour aux poses neutres naturelles
			if neck then
				neck.C0 = getOriginalC0(neck)
			end
			if waist then
				waist.C0 = getOriginalC0(waist)
			end
			if rightShoulder then
				rightShoulder.C0 = getOriginalC0(rightShoulder)
			end
		end
	end
end

RunService.RenderStepped:Connect(onRenderStep)

-- 8. Overdrive Activation (Space, F, or Touch Button)
local function handleOverdriveAction(actionName: string, inputState: Enum.UserInputState, inputObj: InputObject)
	if inputState == Enum.UserInputState.Begin and not isPlayerFrozenInLevelUp() then
		Remotes.GetEvent("TriggerOverdrive"):FireServer()
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("TriggerOverdriveAction", handleOverdriveAction, false, Enum.KeyCode.F, Enum.KeyCode.Space)
