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

local jointOriginalC0: { [Instance]: CFrame } = {}

local function getOriginalC0(motor: Instance): CFrame
	local orig = jointOriginalC0[motor]
	if not orig then
		local success, val = pcall(function()
			return (motor :: any).C0
		end)
		orig = if success and typeof(val) == "CFrame" then val else CFrame.identity
		jointOriginalC0[motor] = orig
	end
	return orig
end

-- Applique la rotation de manière universelle :
-- 1. Sur AnimationConstraint (nouveaux rigs R15 AJU) : modifie .Transform (propriété standard writable)
-- 2. Sur Motor6D classique (R6 et anciens rigs R15) : modifie .C0 et .Transform en pcall protégé
local function setJointRotation(joint: Instance?, rotOffset: CFrame)
	if not joint then return end

	-- Transform est toujours assignable sur AnimationConstraint ET Motor6D
	pcall(function()
		(joint :: any).Transform = rotOffset
	end)

	-- Si c'est un Motor6D classique avec C0 writable
	if joint:IsA("Motor6D") then
		pcall(function()
			local orig = getOriginalC0(joint)
			(joint :: any).C0 = orig * rotOffset
		end)
	end
end

local function resetJointRotation(joint: Instance?)
	if not joint then return end

	pcall(function()
		(joint :: any).Transform = CFrame.identity
	end)

	if joint:IsA("Motor6D") then
		pcall(function()
			(joint :: any).C0 = getOriginalC0(joint)
		end)
	end
end

local cachedChar: Model? = nil
local cachedNeck: Instance? = nil
local cachedWaist: Instance? = nil
local cachedRightShoulder: Instance? = nil
local cachedRootJoint: Instance? = nil
local cachedLeftHip: Instance? = nil
local cachedRightHip: Instance? = nil
local cachedIsR15: boolean = false
local jointsReadyLogged: boolean = false

local function getCharacterJoints(char: Model)
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local isR15 = if humanoid then (humanoid.RigType == Enum.HumanoidRigType.R15) else true

	-- Vérifie si le cache est complet et encore actif dans le personnage
	if cachedChar == char and cachedNeck and cachedNeck.Parent then
		if isR15 and cachedWaist and cachedWaist.Parent then
			return cachedNeck, cachedWaist, cachedRightShoulder, cachedRootJoint, cachedLeftHip, cachedRightHip, isR15
		elseif not isR15 and cachedRootJoint and cachedRootJoint.Parent then
			return cachedNeck, cachedWaist, cachedRightShoulder, cachedRootJoint, cachedLeftHip, cachedRightHip, isR15
		end
	end

	cachedChar = char
	cachedIsR15 = isR15
	cachedNeck = nil
	cachedWaist = nil
	cachedRightShoulder = nil
	cachedRootJoint = nil
	cachedLeftHip = nil
	cachedRightHip = nil

	if isR15 then
		-- Recherche directe dans la hiérarchie standard R15 (Motor6D ou AnimationConstraint)
		local upperTorso = char:FindFirstChild("UpperTorso") :: BasePart?
		local lowerTorso = char:FindFirstChild("LowerTorso") :: BasePart?
		local head = char:FindFirstChild("Head") :: BasePart?
		local rightArm = char:FindFirstChild("RightUpperArm") :: BasePart? or char:FindFirstChild("Right Arm") :: BasePart?
		local leftLeg = char:FindFirstChild("LeftUpperLeg") :: BasePart?
		local rightLeg = char:FindFirstChild("RightUpperLeg") :: BasePart?

		if upperTorso then
			cachedWaist = upperTorso:FindFirstChild("Waist")
				or upperTorso:FindFirstChildWhichIsA("Motor6D")
				or upperTorso:FindFirstChildWhichIsA("AnimationConstraint")
		end
		if head then
			cachedNeck = head:FindFirstChild("Neck")
				or head:FindFirstChildWhichIsA("Motor6D")
				or head:FindFirstChildWhichIsA("AnimationConstraint")
		end
		if lowerTorso then
			cachedRootJoint = lowerTorso:FindFirstChild("Root")
				or lowerTorso:FindFirstChildWhichIsA("Motor6D")
				or lowerTorso:FindFirstChildWhichIsA("AnimationConstraint")
		end
		if rightArm then
			cachedRightShoulder = rightArm:FindFirstChild("RightShoulder")
				or rightArm:FindFirstChildWhichIsA("Motor6D")
				or rightArm:FindFirstChildWhichIsA("AnimationConstraint")
		end
		if leftLeg then
			cachedLeftHip = leftLeg:FindFirstChild("LeftHip")
				or leftLeg:FindFirstChildWhichIsA("Motor6D")
				or leftLeg:FindFirstChildWhichIsA("AnimationConstraint")
		end
		if rightLeg then
			cachedRightHip = rightLeg:FindFirstChild("RightHip")
				or rightLeg:FindFirstChildWhichIsA("Motor6D")
				or rightLeg:FindFirstChildWhichIsA("AnimationConstraint")
		end
	else
		-- Recherche directe dans la hiérarchie standard R6
		local torso = char:FindFirstChild("Torso") :: BasePart?
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?

		if torso then
			cachedNeck = torso:FindFirstChild("Neck")
			cachedRightShoulder = torso:FindFirstChild("Right Shoulder") or torso:FindFirstChild("RightShoulder")
			cachedLeftHip = torso:FindFirstChild("Left Hip") or torso:FindFirstChild("LeftHip")
			cachedRightHip = torso:FindFirstChild("Right Hip") or torso:FindFirstChild("RightHip")
		end
		if hrp then
			cachedRootJoint = hrp:FindFirstChild("RootJoint") or hrp:FindFirstChild("Root")
		end
	end

	-- Fallback récursif complet si une articulation n'était pas à son emplacement usuel
	if not cachedNeck or (isR15 and not cachedWaist) or (not isR15 and not cachedRootJoint) then
		for _, desc in ipairs(char:GetDescendants()) do
			if desc:IsA("Motor6D") or desc:IsA("AnimationConstraint") then
				local n = string.lower(desc.Name):gsub("[%s_%-]", "")
				local p1Name = if (desc :: any).Part1 then string.lower((desc :: any).Part1.Name):gsub("[%s_%-]", "") else ""

				if not cachedNeck and (n == "neck" or p1Name == "head") then
					cachedNeck = desc
				elseif not cachedWaist and (n == "waist" or p1Name == "uppertorso") then
					cachedWaist = desc
				elseif not cachedRightShoulder and (n == "rightshoulder" or p1Name == "rightupperarm" or p1Name == "rightarm") then
					cachedRightShoulder = desc
				elseif not cachedRootJoint and (n == "root" or n == "rootjoint" or p1Name == "lowertorso" or (not isR15 and p1Name == "torso")) then
					cachedRootJoint = desc
				elseif not cachedLeftHip and (n == "lefthip" or p1Name == "leftupperleg" or p1Name == "leftleg") then
					cachedLeftHip = desc
				elseif not cachedRightHip and (n == "righthip" or p1Name == "rightupperleg" or p1Name == "rightleg") then
					cachedRightHip = desc
				end
			end
		end
	end

	-- Enregistrement des C0 originaux pour chaque articulation trouvée
	if cachedNeck then getOriginalC0(cachedNeck) end
	if cachedWaist then getOriginalC0(cachedWaist) end
	if cachedRightShoulder then getOriginalC0(cachedRightShoulder) end
	if cachedRootJoint then getOriginalC0(cachedRootJoint) end
	if cachedLeftHip then getOriginalC0(cachedLeftHip) end
	if cachedRightHip then getOriginalC0(cachedRightHip) end

	local isReady = if isR15 then (cachedWaist ~= nil) else (cachedRootJoint ~= nil)
	if isReady and not jointsReadyLogged then
		jointsReadyLogged = true
		print(string.format("[TopDownCamera] JOINTS READY! Rig: %s | Waist: %s | Neck: %s | RS: %s | Root: %s",
			if isR15 then "R15" else "R6",
			tostring(cachedWaist ~= nil),
			tostring(cachedNeck ~= nil),
			tostring(cachedRightShoulder ~= nil),
			tostring(cachedRootJoint ~= nil)
		))
	end

	return cachedNeck, cachedWaist, cachedRightShoulder, cachedRootJoint, cachedLeftHip, cachedRightHip, isR15
end

-- 5. Character Rotation Setup (AlignOrientation: smooth torque, zero physics conflict)
local function setupCharacter(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hrp or not humanoid then return end

	humanoid.AutoRotate = false
	currentFacingDir = nil
	jointsReadyLogged = false

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
		alignRot.MaxTorque = math.huge
		alignRot.Responsiveness = 200
		alignRot.Parent = hrp
	else
		alignRot.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignRot.Attachment0 = rootAttachment
		alignRot.RigidityEnabled = true
		alignRot.MaxTorque = math.huge
		alignRot.Responsiveness = 200
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

		-- OPTION A : LOCOMOTION ET DÉSAXAGE DU BUSTE
		-- 1. LOCOMOTION : En mouvement, les jambes et le HumanoidRootPart s'orientent TOUJOURS dans le sens du déplacement.
		--    Les jambes avancent droit devant dans la direction pressée (zéro patinage, zéro effet de marche arrière).
		-- 2. VISÉE : À l'arrêt, le personnage fait face à l'ennemi. En course, le buste se désaxe jusqu'à 80° pour viser.
		local isMoving = (moveDir.Magnitude > 0.05) or (humanoid.MoveDirection.Magnitude > 0.05)
		local effectiveMoveDir: Vector3 = if moveDir.Magnitude > 0.05
			then moveDir.Unit
			else (if humanoid.MoveDirection.Magnitude > 0.05 then humanoid.MoveDirection.Unit else Vector3.new(0, 0, -1))

		local hasCombatTarget = (closestPart ~= nil and aimDir ~= nil)

		local desiredHrpFacing: Vector3

		if isMoving then
			-- En déplacement : les jambes s'orientent STRICTEMENT dans le sens de la course
			desiredHrpFacing = effectiveMoveDir
			lastMoveFacingDir = effectiveMoveDir
		elseif hasCombatTarget and aimDir then
			-- À l'arrêt : le personnage fait face à la cible
			desiredHrpFacing = aimDir
			lastAimDir = aimDir
		elseif lastAimDir then
			desiredHrpFacing = lastAimDir
		elseif lastMoveFacingDir then
			desiredHrpFacing = lastMoveFacingDir
		else
			desiredHrpFacing = Vector3.new(0, 0, -1)
		end

		if not currentFacingDir or currentFacingDir.X ~= currentFacingDir.X then
			currentFacingDir = desiredHrpFacing
		else
			local lerped = currentFacingDir:Lerp(desiredHrpFacing, math.clamp(dt * 25, 0, 1))
			if lerped.Magnitude > 0.001 then
				currentFacingDir = lerped.Unit
			else
				currentFacingDir = desiredHrpFacing
			end
		end

		alignRot.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + currentFacingDir)

		-- Récupération dynamique et sécurisée des articulations (compatible R15 et R6)
		local neck, waist, rightShoulder, rootJoint, leftHip, rightHip, isR15 = getCharacterJoints(char)

		-- Visée du haut du corps (Désaxage anatomique jusqu'à 80°)
		if hasCombatTarget and closestPart and aimDir then
			local toEnemy = closestPart.Position - hrp.Position
			local localAim = hrp.CFrame:VectorToObjectSpace(toEnemy)
			local flatDist = math.sqrt(localAim.X * localAim.X + localAim.Z * localAim.Z)

			if flatDist > 0.1 then
				local targetYaw = math.atan2(-localAim.X, -localAim.Z)
				local targetPitch = math.clamp(math.atan2(localAim.Y, flatDist), -math.rad(35), math.rad(35))

				-- 1. Torse : désaxage anatomique jusqu'à 80°
				local maxWaist = math.rad(80)
				local waistYaw = math.clamp(targetYaw, -maxWaist, maxWaist)

				if isR15 and waist then
					-- R15 : rotation directe de l'UpperTorso sur le LowerTorso (Transform / C0 universel)
					setJointRotation(waist, CFrame.Angles(0, waistYaw, 0))
				elseif not isR15 and rootJoint then
					-- R6 : rotation du Torso et contre-rotation des hanches pour garder les jambes dans l'axe de course
					setJointRotation(rootJoint, CFrame.Angles(0, 0, -waistYaw))
					setJointRotation(leftHip, CFrame.Angles(0, 0, waistYaw))
					setJointRotation(rightHip, CFrame.Angles(0, 0, waistYaw))
				end

				-- 2. Tête : regard vers la cible
				local remainingYaw = targetYaw - waistYaw
				local headYaw = math.clamp(remainingYaw, -math.rad(45), math.rad(45))
				local headPitch = math.clamp(-targetPitch, -math.rad(30), math.rad(30))
				if neck then
					if isR15 then
						setJointRotation(neck, CFrame.Angles(headPitch, headYaw, 0))
					else
						setJointRotation(neck, CFrame.Angles(0, 0, -headYaw) * CFrame.Angles(headPitch, 0, 0))
					end
				end

				-- 3. Bras droit tenant le Blaster : pointé vers la cible
				if rightShoulder then
					local armYaw = math.clamp(remainingYaw, -math.rad(35), math.rad(35))

					if isR15 then
						-- R15 : lever le bras vers l'avant (-85° sur X) + pitch + compensation yaw
						local aimOffset = CFrame.Angles(0, armYaw, 0) * CFrame.Angles(-math.rad(85) + targetPitch, 0, math.rad(-3))
						setJointRotation(rightShoulder, aimOffset)
					else
						-- R6
						local aimOffset = CFrame.Angles(0, 0, math.rad(90) + targetPitch) * CFrame.Angles(0, armYaw, 0)
						setJointRotation(rightShoulder, aimOffset)
					end
				end
			end
		else
			-- Hors combat : retour aux poses neutres naturelles
			if isR15 then
				resetJointRotation(waist)
			else
				resetJointRotation(rootJoint)
				resetJointRotation(leftHip)
				resetJointRotation(rightHip)
			end
			resetJointRotation(neck)
			resetJointRotation(rightShoulder)
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
