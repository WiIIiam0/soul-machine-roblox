--!strict
-- ArenaBuilder.luau: Builds an atmospheric cyberpunk/mecha battle arena with neon grids, laser barriers, and lighting

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local ArenaBuilder = {}

function ArenaBuilder.BuildArena()
	if Workspace:FindFirstChild("MechaArena") then
		return
	end

	local arena = Instance.new("Model")
	arena.Name = "MechaArena"

	-- Main Arena Floor (300 x 300)
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(300, 4, 300)
	floor.Position = Vector3.new(0, -2, 0)
	floor.Color = Color3.fromRGB(15, 18, 24)
	floor.Material = Enum.Material.Metal
	floor.Anchored = true
	floor.CanCollide = true
	floor.Parent = arena

	-- Center Ring Neon
	local centerRing = Instance.new("Part")
	centerRing.Name = "CenterRing"
	centerRing.Size = Vector3.new(36, 0.2, 36)
	centerRing.Position = Vector3.new(0, 0.1, 0)
	centerRing.Shape = Enum.PartType.Cylinder
	centerRing.Orientation = Vector3.new(0, 0, 90)
	centerRing.Color = Color3.fromRGB(0, 200, 255)
	centerRing.Material = Enum.Material.Neon
	centerRing.Anchored = true
	centerRing.CanCollide = false
	centerRing.Parent = arena

	-- Grid Lines (Visual Cyber Grid)
	for i = -120, 120, 30 do
		-- X-axis line
		local lineX = Instance.new("Part")
		lineX.Name = "GridX"
		lineX.Size = Vector3.new(280, 0.1, 0.8)
		lineX.Position = Vector3.new(0, 0.05, i)
		lineX.Color = Color3.fromRGB(0, 140, 200)
		lineX.Material = Enum.Material.Neon
		lineX.Transparency = 0.6
		lineX.Anchored = true
		lineX.CanCollide = false
		lineX.Parent = arena

		-- Z-axis line
		local lineZ = Instance.new("Part")
		lineZ.Name = "GridZ"
		lineZ.Size = Vector3.new(0.8, 0.1, 280)
		lineZ.Position = Vector3.new(i, 0.05, 0)
		lineZ.Color = Color3.fromRGB(0, 140, 200)
		lineZ.Material = Enum.Material.Neon
		lineZ.Transparency = 0.6
		lineZ.Anchored = true
		lineZ.CanCollide = false
		lineZ.Parent = arena
	end

	-- Perimeter Laser Barriers (North, South, East, West)
	local wallConfigs = {
		{ name = "WallNorth", size = Vector3.new(300, 16, 2), pos = Vector3.new(0, 8, 150) },
		{ name = "WallSouth", size = Vector3.new(300, 16, 2), pos = Vector3.new(0, 8, -150) },
		{ name = "WallEast",  size = Vector3.new(2, 16, 300), pos = Vector3.new(150, 8, 0) },
		{ name = "WallWest",  size = Vector3.new(2, 16, 300), pos = Vector3.new(-150, 8, 0) },
	}

	for _, cfg in ipairs(wallConfigs) do
		local wall = Instance.new("Part")
		wall.Name = cfg.name
		wall.Size = cfg.size
		wall.Position = cfg.pos
		wall.Color = Color3.fromRGB(0, 180, 255)
		wall.Material = Enum.Material.Neon
		wall.Transparency = 0.75
		wall.Anchored = true
		wall.CanCollide = true
		wall.Parent = arena
	end

	-- 4 Corner Energy Towers
	local cornerPositions = {
		Vector3.new(140, 0, 140),
		Vector3.new(-140, 0, 140),
		Vector3.new(140, 0, -140),
		Vector3.new(-140, 0, -140),
	}

	for idx, cPos in ipairs(cornerPositions) do
		local tower = Instance.new("Part")
		tower.Name = "Tower_" .. idx
		tower.Size = Vector3.new(6, 28, 6)
		tower.Position = cPos + Vector3.new(0, 14, 0)
		tower.Color = Color3.fromRGB(20, 24, 32)
		tower.Material = Enum.Material.DiamondPlate
		tower.Anchored = true
		tower.CanCollide = true
		tower.Parent = arena

		local towerLight = Instance.new("Part")
		towerLight.Name = "TowerCore"
		towerLight.Size = Vector3.new(4, 26, 4)
		towerLight.Position = tower.Position
		towerLight.Color = Color3.fromRGB(0, 240, 255)
		towerLight.Material = Enum.Material.Neon
		towerLight.Anchored = true
		towerLight.CanCollide = false
		towerLight.Parent = arena

		local pLight = Instance.new("PointLight")
		pLight.Color = Color3.fromRGB(0, 220, 255)
		pLight.Brightness = 3
		pLight.Range = 45
		pLight.Parent = towerLight
	end

	-- Central Spawn Location
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MechaSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Color = Color3.fromRGB(30, 35, 45)
	spawn.Material = Enum.Material.Metal
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Duration = 0
	spawn.Parent = arena

	local spawnDecal = Instance.new("Decal")
	spawnDecal.Face = Enum.NormalId.Top
	spawnDecal.Texture = "rbxassetid://10709791130"
	spawnDecal.Parent = spawn

	arena.Parent = Workspace

	-- Lighting Sci-Fi Atmosphere
	Lighting.ClockTime = 20.5 -- Night / Dusk
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.fromRGB(35, 40, 55)
	Lighting.OutdoorAmbient = Color3.fromRGB(20, 25, 40)
	Lighting.FogColor = Color3.fromRGB(10, 14, 25)
	Lighting.FogStart = 150
	Lighting.FogEnd = 350

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Intensity = 1.2
		bloom.Size = 24
		bloom.Threshold = 0.85
		bloom.Parent = Lighting
	end
end

return ArenaBuilder
