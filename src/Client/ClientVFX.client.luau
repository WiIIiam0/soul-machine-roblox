--!strict
-- ClientVFX.client.luau: Client-side visual effects (explosions, shockwaves, overdrive lightning aura)

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local vfxEvent = Remotes.GetEvent("VFXEvent")

local function createExplosion(pos: Vector3, radius: number, color: Color3)
	-- Outer expanding blast sphere
	local sphere = Instance.new("Part")
	sphere.Name = "BlastSphere"
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.new(1, 1, 1)
	sphere.Position = pos
	sphere.Color = color
	sphere.Material = Enum.Material.Neon
	sphere.Transparency = 0.2
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CastShadow = false
	sphere.Parent = Workspace

	local sphereTween = TweenService:Create(sphere, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 1,
	})

	sphereTween:Play()
	sphereTween.Completed:Connect(function()
		sphere:Destroy()
	end)

	-- Shockwave ring
	local ring = Instance.new("Part")
	ring.Name = "ShockwaveRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 1, 1)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(255, 255, 255)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.3
	ring.Anchored = true
	ring.CanCollide = false
	ring.CastShadow = false
	ring.Parent = Workspace

	local ringTween = TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, radius * 2.4, radius * 2.4),
		Transparency = 1,
	})

	ringTween:Play()
	ringTween.Completed:Connect(function()
		ring:Destroy()
	end)
end

local function createDeathBurst(pos: Vector3, color: Color3, isBoss: boolean)
	local blastRadius = if isBoss then 16 else 6
	createExplosion(pos, blastRadius, color)
end

local function createBurnTransferBeam(startPos: Vector3, endPos: Vector3)
	local dist = (endPos - startPos).Magnitude
	if dist <= 0.1 then return end

	local beamPart = Instance.new("Part")
	beamPart.Name = "BurnTransferBeam"
	beamPart.Size = Vector3.new(0.5, 0.5, dist)
	beamPart.CFrame = CFrame.lookAt((startPos + endPos) * 0.5, endPos)
	beamPart.Color = Color3.fromRGB(255, 120, 20)
	beamPart.Material = Enum.Material.Neon
	beamPart.Transparency = 0.1
	beamPart.Anchored = true
	beamPart.CanCollide = false
	beamPart.CastShadow = false
	beamPart.Parent = Workspace

	local tw = TweenService:Create(beamPart, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(0.05, 0.05, dist),
	})
	tw:Play()
	tw.Completed:Connect(function()
		beamPart:Destroy()
	end)
end

local function applyOverdriveAura(targetPlayer: Player, enable: boolean)
	local char = targetPlayer.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	local existing = hrp:FindFirstChild("OverdriveAura")
	if enable then
		if not existing then
			local attachment = Instance.new("Attachment")
			attachment.Name = "OverdriveAura"
			attachment.Parent = hrp

			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "Sparks"
			emitter.Rate = 60
			emitter.Lifetime = NumberRange.new(0.3, 0.6)
			emitter.Speed = NumberRange.new(4, 10)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 80)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 50, 80)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 0, 255)),
			})
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.8),
				NumberSequenceKeypoint.new(1, 0.1),
			})
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.Parent = attachment

			local light = Instance.new("PointLight")
			light.Name = "OverdriveGlow"
			light.Color = Color3.fromRGB(255, 50, 100)
			light.Brightness = 4
			light.Range = 20
			light.Parent = attachment
		end
	else
		if existing then
			existing:Destroy()
		end
	end
end

vfxEvent.OnClientEvent:Connect(function(eventType: string, ...: any)
	if eventType == "Explosion" then
		local pos, radius, color = ...
		createExplosion(pos, radius or 10, color or Color3.fromRGB(255, 100, 20))
	elseif eventType == "EnemyDeath" then
		local pos, color, isBoss = ...
		createDeathBurst(pos, color or Color3.fromRGB(255, 50, 50), isBoss or false)
	elseif eventType == "BurnTransfer" then
		local startPos, endPos = ...
		if startPos and endPos then
			createBurnTransferBeam(startPos, endPos)
		end
	elseif eventType == "OverdriveStart" then
		local targetPlayer = ...
		applyOverdriveAura(targetPlayer, true)
	elseif eventType == "OverdriveEnd" then
		local targetPlayer = ...
		applyOverdriveAura(targetPlayer, false)
	end
end)
