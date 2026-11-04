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

-- Synchronisation de la marche / course : marche arrière réelle ("tirer à reculons")
local function updateLocomotionAnimation(humanoid: Humanoid, hrp: BasePart, moveDir: Vector3, hasCombatTarget: boolean)
	local isMoving = moveDir.Magnitude > 0.05
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	local animSpeed = 1.0
	if isMoving and hasCombatTarget then
		local facingForward = hrp.CFrame.LookVector
		local dot = facingForward:Dot(moveDir.Unit)
		-- Si on recule par rapport à la cible ("tirer à reculons"): animation inversée réaliste !
		if dot < -0.25 then
			animSpeed = -1.0
		end
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Looped and (track.Priority == Enum.AnimationPriority.Core or track.Priority == Enum.AnimationPriority.Movement) then
			local name = string.lower(track.Name)
			if string.find(name, "run") or string.find(name, "walk") or track.WeightCurrent > 0.3 then
				track:AdjustSpeed(animSpeed)
			end
		end
	end
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

	-- 7. AUTO-AIM AT CLOSEST ENEMY & TWIN-STICK STRAFE MOVEMENT
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

		-- Locomotion & Weapon Aiming:
		-- En combat : le personnage s'oriente face à sa cible (tête, torse et blaster pointés sur l'ennemi).
		-- Lors du déplacement en combat :
		--   - Avance vers l'ennemi : course normale
		--   - Recule face à l'ennemi ("tirer à reculons") : l'animation de course s'inverse pour une vraie marche arrière
		--   - Déplacement latéral ("strafe") : hanches orientées vers le mouvement, torse verrouillé sur la cible
		-- Hors combat : s'oriente naturellement dans le sens du déplacement.
		local isMoving = moveDir.Magnitude > 0.05
		local hasCombatTarget = (closestPart ~= nil and aimDir ~= nil)

		local desiredFacing: Vector3

		if hasCombatTarget and aimDir then
			desiredFacing = aimDir
			lastAimDir = aimDir
		elseif isMoving then
			desiredFacing = moveDir.Unit
			lastMoveFacingDir = moveDir.Unit
		elseif lastAimDir then
			desiredFacing = lastAimDir
		elseif lastMoveFacingDir then
			desiredFacing = lastMoveFacingDir
		else
			desiredFacing = Vector3.new(0, 0, -1)
		end

		if not currentFacingDir then
			currentFacingDir = desiredFacing
		else
			local turnSpeed = if hasCombatTarget then 28 else 20
			currentFacingDir = currentFacingDir:Lerp(desiredFacing, math.clamp(dt * turnSpeed, 0, 1)).Unit
		end

		alignRot.CFrame = CFrame.lookAt(Vector3.zero, currentFacingDir)

		-- Articulations du personnage et locomotion
		local neck, waist, rightShoulder, rootJoint = getCharacterJoints(char)

		-- Synchronisation réaliste de la marche arrière / strafe
		updateLocomotionAnimation(humanoid, hrp, moveDir, hasCombatTarget)

		-- Ajustement dynamique du bassin (RootJoint) pour le strafe latéral en combat
		if rootJoint then
			local origRoot = getOriginalC0(rootJoint)
			if hasCombatTarget and isMoving then
				local facingForward = hrp.CFrame.LookVector
				local crossY = facingForward.X * moveDir.Unit.Z - facingForward.Z * moveDir.Unit.X
				local dot = facingForward:Dot(moveDir.Unit)
				if math.abs(dot) < 0.65 then
					local strafeAngle = math.clamp(-crossY * math.rad(25), -math.rad(25), math.rad(25))
					rootJoint.C0 = origRoot * CFrame.Angles(0, strafeAngle, 0)
				else
					rootJoint.C0 = origRoot
				end
			else
				rootJoint.C0 = origRoot
			end
		end

		-- Visée du haut du corps (Tête, Torse et Bras Droit tenant le Blaster)
		if hasCombatTarget and closestPart and aimDir then
			local toEnemy = closestPart.Position - hrp.Position
			local localAim = hrp.CFrame:VectorToObjectSpace(toEnemy)
			local flatDist = math.sqrt(localAim.X * localAim.X + localAim.Z * localAim.Z)

			if flatDist > 0.1 then
				local targetYaw = math.atan2(-localAim.X, -localAim.Z)
				local targetPitch = math.atan2(localAim.Y, flatDist)

				-- Tête : regarde l'ennemi droit dans les yeux
				if neck then
					local origNeck = getOriginalC0(neck)
					local headYaw = math.clamp(targetYaw, -math.rad(60), math.rad(60))
					local headPitch = math.clamp(-targetPitch, -math.rad(30), math.rad(30))
					neck.C0 = origNeck * CFrame.Angles(headPitch, headYaw, 0)
				end

				-- Torse : rotation légère pour accompagner la visée
				if waist then
					local origWaist = getOriginalC0(waist)
					local waistYaw = math.clamp(targetYaw * 0.4, -math.rad(25), math.rad(25))
					waist.C0 = origWaist * CFrame.Angles(0, waistYaw, 0)
				end

				-- Bras droit : lève le blaster et vise la cible !
				if rightShoulder then
					local origRS = getOriginalC0(rightShoulder)
					local armPitch = math.clamp(targetPitch, -math.rad(35), math.rad(35))
					local armYaw = math.clamp(targetYaw, -math.rad(45), math.rad(45))

					if humanoid.RigType == Enum.HumanoidRigType.R15 then
						-- En R15 : lever le bras vers l'avant (-85° autour de X) + ajustement pitch/yaw
						local aimOffset = CFrame.Angles(0, armYaw, 0) * CFrame.Angles(-math.rad(85) + armPitch, 0, math.rad(-5))
						rightShoulder.C0 = origRS * aimOffset
					else
						-- En R6
						local aimOffset = CFrame.Angles(0, 0, math.rad(90) + armPitch) * CFrame.Angles(0, armYaw, 0)
						rightShoulder.C0 = origRS * aimOffset
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
