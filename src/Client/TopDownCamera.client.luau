--!strict
-- TopDownCamera.client.luau: Isometric top-down camera and mecha aiming controls

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

local CAMERA_OFFSET = Vector3.new(0, 36, 24) -- 60 degree top-down angle
local CAMERA_LERP = 0.15

-- Enable custom camera
camera.CameraType = Enum.CameraType.Scriptable

local function onRenderStep(dt: number)
	local char = player.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	local pPos = hrp.Position
	local targetCamPos = pPos + CAMERA_OFFSET
	local lookTarget = pPos + Vector3.new(0, 1.5, 0)

	-- Smooth camera follow
	local targetCFrame = CFrame.lookAt(targetCamPos, lookTarget)
	camera.CFrame = camera.CFrame:Lerp(targetCFrame, CAMERA_LERP)

	-- Turn mecha toward mouse cursor or joystick direction
	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	local planeY = pPos.Y

	-- Ray-plane intersection at player height
	if ray.Direction.Y ~= 0 then
		local t = (planeY - ray.Origin.Y) / ray.Direction.Y
		if t > 0 then
			local hitPoint = ray.Origin + (ray.Direction * t)
			local toCursor = (hitPoint - pPos)
			local flatToCursor = Vector3.new(toCursor.X, 0, toCursor.Z)
			if flatToCursor.Magnitude > 1.0 then
				hrp.CFrame = CFrame.lookAt(pPos, pPos + flatToCursor.Unit)
			end
		end
	end
end

RunService.RenderStepped:Connect(onRenderStep)

-- Overdrive activation hotkey (Space or Gamepad Button)
local function handleOverdriveAction(actionName: string, inputState: Enum.UserInputState, inputObj: InputObject)
	if inputState == Enum.UserInputState.Begin then
		Remotes.GetEvent("TriggerOverdrive"):FireServer()
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("TriggerOverdriveAction", handleOverdriveAction, false, Enum.KeyCode.F, Enum.KeyCode.Space)
