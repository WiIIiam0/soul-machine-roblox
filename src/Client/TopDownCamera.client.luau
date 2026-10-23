--!strict
-- TopDownCamera.client.luau: Isometric top-down camera and stable mecha aiming controls

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

local CAMERA_OFFSET = Vector3.new(0, 42, 28) -- Top-down isometric perspective

camera.CameraType = Enum.CameraType.Scriptable

-- Setup AlignOrientation on character to rotate smoothly without physics drift
local function setupMechaRotation(character: Model)
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
		alignRot.Responsiveness = 45
		alignRot.MaxTorque = math.huge
		alignRot.Parent = hrp
	end
end

if player.Character then
	task.spawn(setupMechaRotation, player.Character)
end
player.CharacterAdded:Connect(setupMechaRotation)

local function onRenderStep(dt: number)
	local char = player.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end

	local pPos = hrp.Position
	local targetCamPos = pPos + CAMERA_OFFSET
	local lookTarget = pPos + Vector3.new(0, 1.5, 0)

	-- Direct stable top-down camera position (no camera lag or jitter)
	camera.CFrame = CFrame.lookAt(targetCamPos, lookTarget)

	-- Aim rotation via AlignOrientation
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

		-- Fallback to humanoid MoveDirection if no cursor aim (e.g. controller or idle)
		if not aimDir and humanoid.MoveDirection.Magnitude > 0.1 then
			aimDir = humanoid.MoveDirection.Unit
		end

		if aimDir then
			alignRot.CFrame = CFrame.lookAt(Vector3.zero, aimDir)
		end
	end
end

RunService.RenderStepped:Connect(onRenderStep)

-- Overdrive activation hotkey (Space or F or Gamepad Button)
local function handleOverdriveAction(actionName: string, inputState: Enum.UserInputState, inputObj: InputObject)
	if inputState == Enum.UserInputState.Begin then
		Remotes.GetEvent("TriggerOverdrive"):FireServer()
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("TriggerOverdriveAction", handleOverdriveAction, false, Enum.KeyCode.F, Enum.KeyCode.Space)
