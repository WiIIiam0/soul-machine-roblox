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

local function attachPlayerWeapon(character: Model)
	local rightHand = character:WaitForChild("RightHand", 5) :: BasePart?
	if not rightHand then return end

	local existing = rightHand:FindFirstChild("PlayerWeaponModel")
	if existing then return end

	local weaponModel = Instance.new("Model")
	weaponModel.Name = "PlayerWeaponModel"

	local gunBody = Instance.new("Part")
	gunBody.Name = "GunBody"
	gunBody.Size = Vector3.new(0.35, 0.55, 1.8)
	gunBody.Material = Enum.Material.Metal
	gunBody.Color = Color3.fromRGB(25, 28, 35)
	gunBody.CanCollide = false
	gunBody.Massless = true
	gunBody.CFrame = rightHand.CFrame * CFrame.new(0, -0.3, -0.4) * CFrame.Angles(math.rad(-10), 0, 0)
	gunBody.Parent = weaponModel

	local gunBarrel = Instance.new("Part")
	gunBarrel.Name = "GunBarrel"
	gunBarrel.Size = Vector3.new(0.2, 0.2, 0.9)
	gunBarrel.Material = Enum.Material.Neon
	gunBarrel.Color = Color3.fromRGB(0, 220, 255)
	gunBarrel.CanCollide = false
	gunBarrel.Massless = true
	gunBarrel.CFrame = gunBody.CFrame * CFrame.new(0, 0.1, -0.9)
	gunBarrel.Parent = weaponModel

	local w1 = Instance.new("WeldConstraint")
	w1.Part0 = rightHand
	w1.Part1 = gunBody
	w1.Parent = gunBody

	local w2 = Instance.new("WeldConstraint")
	w2.Part0 = gunBody
	w2.Part1 = gunBarrel
	w2.Parent = gunBarrel

	weaponModel.Parent = rightHand
end

local cachedNeck: Motor6D? = nil
local cachedWaist: Motor6D? = nil
local cachedRightShoulder: Motor6D? = nil
local origNeckC0: CFrame? = nil
local origWaistC0: CFrame? = nil
local origRightShoulderC0: CFrame? = nil

local function refreshCharacterJoints(character: Model)
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("Motor6D") then
			local n = string.lower(desc.Name):gsub("%s+", "")
			if n == "neck" then
				cachedNeck = desc
				origNeckC0 = desc.C0
			elseif n == "waist" then
				cachedWaist = desc
				origWaistC0 = desc.C0
			elseif n == "rightshoulder" then
				cachedRightShoulder = desc
				origRightShoulderC0 = desc.C0
			end
		end
	end
end

-- 5. Character Rotation Setup (AlignOrientation: smooth torque, zero physics conflict)
local function setupCharacter(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hrp or not humanoid then return end

	humanoid.AutoRotate = false
	currentFacingDir = nil

	refreshCharacterJoints(character)
	task.spawn(attachPlayerWeapon, character)

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
		-- When moving (WASD): the character ALWAYS faces the direction of travel (pure, clean forward running).
		-- When stationary (stopped): the character turns to face the combat target (aimDir).
		local isMoving = moveDir.Magnitude > 0.05
		local desiredFacing: Vector3

		if isMoving then
			desiredFacing = moveDir.Unit
			lastMoveFacingDir = moveDir.Unit
		elseif aimDir then
			desiredFacing = aimDir
			lastAimDir = aimDir
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
			currentFacingDir = currentFacingDir:Lerp(desiredFacing, math.clamp(dt * 20, 0, 1)).Unit
		end

		alignRot.CFrame = CFrame.lookAt(Vector3.zero, currentFacingDir)

		-- Dynamic Upper-Body Aiming (Head, Torso and Right Arm aim weapon towards enemy)
		if not cachedNeck or not cachedWaist or not cachedRightShoulder then
			refreshCharacterJoints(char)
		end

		if closestPart and aimDir then
			local toEnemy = closestPart.Position - hrp.Position
			local localAim = hrp.CFrame:VectorToObjectSpace(toEnemy)
			local flatDist = math.sqrt(localAim.X * localAim.X + localAim.Z * localAim.Z)

			if flatDist > 0.1 then
				local targetYaw = math.atan2(-localAim.X, -localAim.Z)
				local targetPitch = math.atan2(localAim.Y, flatDist)

				-- Head: turn up to 75° to LOOK directly at the enemy
				local headYaw = math.clamp(targetYaw, -math.rad(75), math.rad(75))
				local headPitch = math.clamp(-targetPitch, -math.rad(30), math.rad(30))

				if cachedNeck and origNeckC0 then
					cachedNeck.C0 = origNeckC0 * CFrame.Angles(headPitch, headYaw, 0)
				end

				-- Torso / Waist: swivel up to 50° towards the enemy
				local maxWaistYaw = if isMoving then math.rad(45) else math.rad(25)
				local waistYaw = math.clamp(targetYaw * 0.7, -maxWaistYaw, maxWaistYaw)

				if cachedWaist and origWaistC0 then
					cachedWaist.C0 = origWaistC0 * CFrame.Angles(0, waistYaw, 0)
				end

				-- Right Arm: raise and aim weapon directly at the enemy!
				local armYaw = math.clamp(targetYaw, -math.rad(75), math.rad(75))
				local armPitch = math.clamp(targetPitch, -math.rad(35), math.rad(35))

				if cachedRightShoulder and origRightShoulderC0 then
					cachedRightShoulder.C0 = origRightShoulderC0 * CFrame.Angles(math.rad(82) + armPitch, armYaw, math.rad(-12))
				end
			end
		else
			-- Outside combat: smoothly restore natural neutral pose
			if cachedWaist and origWaistC0 then
				cachedWaist.C0 = origWaistC0
			end
			if cachedNeck and origNeckC0 then
				cachedNeck.C0 = origNeckC0
			end
			if cachedRightShoulder and origRightShoulderC0 then
				cachedRightShoulder.C0 = origRightShoulderC0
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
