--!strict
-- TopDownCamera.client.luau: Pure Top-Down camera, free mouse aiming, and drift-free movement controller

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

-- 1. Free and visible mouse cursor (prevents ShiftLock center dot)
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

-- 3. Character Rotation Setup (AlignOrientation: smooth torque, zero physics conflict)
local function setupCharacter(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hrp or not humanoid then return end

	humanoid.AutoRotate = false

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

-- 4. Movement & Camera Update Loop
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

	-- Gamepad support with 0.25 deadzone to ignore stick drift
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

	-- Mouse Aiming
	local alignRot = hrp:FindFirstChild("MechaAimOrientation") :: AlignOrientation?
	if alignRot then
		local mousePos = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
		local planeY = pPos.Y

		local aimDir: Vector3? = nil

		if ray.Direction.Y ~= 0 then
			local t = (planeY - ray.Origin.Y) / ray.Direction.Y
			if t > 0 then
				local hitPoint = ray.Origin + (ray.Direction * t)
				local toCursor = (hitPoint - pPos)
				local flatToCursor = Vector3.new(toCursor.X, 0, toCursor.Z)
				if flatToCursor.Magnitude > 1.2 then
					aimDir = flatToCursor.Unit
				end
			end
		end

		if not aimDir and moveDir.Magnitude > 0.05 then
			aimDir = moveDir.Unit
		end

		if aimDir then
			alignRot.CFrame = CFrame.lookAt(Vector3.zero, aimDir)
		end
	end
end

RunService.RenderStepped:Connect(onRenderStep)

-- 5. Overdrive Activation (Space, F, or Gamepad Button)
local function handleOverdriveAction(actionName: string, inputState: Enum.UserInputState, inputObj: InputObject)
	if inputState == Enum.UserInputState.Begin then
		Remotes.GetEvent("TriggerOverdrive"):FireServer()
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("TriggerOverdriveAction", handleOverdriveAction, false, Enum.KeyCode.F, Enum.KeyCode.Space)
