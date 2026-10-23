--!strict
-- ArenaBuilder.luau: Builds an atmospheric cyberpunk/mecha battle arena dressed with PoHRoblox industrial blocks
-- Textures used from PoHRoblox BlockRegistry:
--   NetheritePlating (composite dark metal floor)
--   HazardStripes (yellow/black perimeter safety stripes)
--   IronArmor (riveted steel walkways and crosswalks)
--   ReactorCore (central plasma reactor generator)
--   RedstoneLamp (industrial beacon pylons)
--   ObserverSensor (mecha optical sensors)

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local ArenaBuilder = {}

local TEXTURES = {
	NetheritePlating = "rbxthumb://type=Asset&id=18180391155&w=420&h=420",
	IronArmor = "rbxthumb://type=Asset&id=8677286764&w=420&h=420",
	HazardStripes = "rbxthumb://type=Asset&id=14710653033&w=420&h=420",
	ReactorCore = "rbxthumb://type=Asset&id=8677288287&w=420&h=420",
	RedstoneLamp = "rbxthumb://type=Asset&id=103228454367733&w=420&h=420",
	ObserverSensor = "rbxthumb://type=Asset&id=10402849066&w=420&h=420",
}

local function addTopTexture(part: BasePart, textureId: string, studsU: number, studsV: number): Texture
	local tex = Instance.new("Texture")
	tex.Texture = textureId
	tex.Face = Enum.NormalId.Top
	tex.StudsPerTileU = studsU
	tex.StudsPerTileV = studsV
	tex.Parent = part
	return tex
end

local function addAllFacesTexture(part: BasePart, textureId: string, studsU: number, studsV: number)
	for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
		local tex = Instance.new("Texture")
		tex.Texture = textureId
		tex.Face = face
		tex.StudsPerTileU = studsU
		tex.StudsPerTileV = studsV
		tex.Parent = part
	end
end

function ArenaBuilder.BuildArena()
	local existing = Workspace:FindFirstChild("MechaArena")
	if existing then
		existing:Destroy()
	end

	local arena = Instance.new("Model")
	arena.Name = "MechaArena"

	-- 1. Main Arena Floor (300 x 300) with NetheritePlating
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(300, 4, 300)
	floor.Position = Vector3.new(0, -2, 0)
	floor.Color = Color3.fromRGB(50, 48, 55)
	floor.Material = Enum.Material.SmoothPlastic
	floor.Anchored = true
	floor.CanCollide = true
	floor.Parent = arena
	addTopTexture(floor, TEXTURES.NetheritePlating, 8, 8)

	-- 2. Perimeter Warning Borders (Hazard Stripes - 12 studs wide along outer walls)
	local hazardBorders = {
		{ name = "HazardNorth", size = Vector3.new(300, 0.2, 12), pos = Vector3.new(0, 0.05, 144) },
		{ name = "HazardSouth", size = Vector3.new(300, 0.2, 12), pos = Vector3.new(0, 0.05, -144) },
		{ name = "HazardEast",  size = Vector3.new(12, 0.2, 276), pos = Vector3.new(144, 0.05, 0) },
		{ name = "HazardWest",  size = Vector3.new(12, 0.2, 276), pos = Vector3.new(-144, 0.05, 0) },
	}

	for _, cfg in ipairs(hazardBorders) do
		local hPart = Instance.new("Part")
		hPart.Name = cfg.name
		hPart.Size = cfg.size
		hPart.Position = cfg.pos
		hPart.Color = Color3.fromRGB(245, 210, 20)
		hPart.Material = Enum.Material.SmoothPlastic
		hPart.Anchored = true
		hPart.CanCollide = false
		hPart.Parent = arena
		addTopTexture(hPart, TEXTURES.HazardStripes, 4, 4)
	end

	-- 3. Crosswalk Industrial Walkways (IronArmor - 16 studs wide cross through center)
	local walkways = {
		{ name = "WalkwayX", size = Vector3.new(276, 0.1, 16), pos = Vector3.new(0, 0.02, 0) },
		{ name = "WalkwayZ", size = Vector3.new(16, 0.1, 276), pos = Vector3.new(0, 0.02, 0) },
	}

	for _, cfg in ipairs(walkways) do
		local wPart = Instance.new("Part")
		wPart.Name = cfg.name
		wPart.Size = cfg.size
		wPart.Position = cfg.pos
		wPart.Color = Color3.fromRGB(195, 200, 210)
		wPart.Material = Enum.Material.SmoothPlastic
		wPart.Anchored = true
		wPart.CanCollide = false
		wPart.Parent = arena
		addTopTexture(wPart, TEXTURES.IronArmor, 6, 6)
	end

	-- 4. Central Plasma Reactor Generator Core (ReactorCore)
	local reactorPad = Instance.new("Part")
	reactorPad.Name = "ReactorPad"
	reactorPad.Size = Vector3.new(36, 0.25, 36)
	reactorPad.Position = Vector3.new(0, 0.08, 0)
	reactorPad.Color = Color3.fromRGB(240, 50, 40)
	reactorPad.Material = Enum.Material.Neon
	reactorPad.Anchored = true
	reactorPad.CanCollide = false
	reactorPad.Parent = arena
	addTopTexture(reactorPad, TEXTURES.ReactorCore, 6, 6)

	local reactorLight = Instance.new("PointLight")
	reactorLight.Color = Color3.fromRGB(255, 60, 40)
	reactorLight.Brightness = 2.5
	reactorLight.Range = 36
	reactorLight.Parent = reactorPad

	-- Inner Cyber Ring around the reactor
	local centerRing = Instance.new("Part")
	centerRing.Name = "CenterRing"
	centerRing.Size = Vector3.new(44, 0.1, 44)
	centerRing.Position = Vector3.new(0, 0.12, 0)
	centerRing.Shape = Enum.PartType.Cylinder
	centerRing.Orientation = Vector3.new(0, 0, 90)
	centerRing.Color = Color3.fromRGB(0, 220, 255)
	centerRing.Material = Enum.Material.Neon
	centerRing.Transparency = 0.3
	centerRing.Anchored = true
	centerRing.CanCollide = false
	centerRing.Parent = arena

	-- 5. Perimeter Laser Barriers (North, South, East, West)
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

	-- 6. Industrial Beacon Lamps (RedstoneLamp) along perimeter
	local beaconPositions = {
		-- North & South
		Vector3.new(-90, 0.5, 144), Vector3.new(0, 0.5, 144), Vector3.new(90, 0.5, 144),
		Vector3.new(-90, 0.5, -144), Vector3.new(0, 0.5, -144), Vector3.new(90, 0.5, -144),
		-- East & West
		Vector3.new(144, 0.5, -90), Vector3.new(144, 0.5, 0), Vector3.new(144, 0.5, 90),
		Vector3.new(-144, 0.5, -90), Vector3.new(-144, 0.5, 0), Vector3.new(-144, 0.5, 90),
	}

	for bIdx, bPos in ipairs(beaconPositions) do
		local lamp = Instance.new("Part")
		lamp.Name = "PerimeterLamp_" .. bIdx
		lamp.Size = Vector3.new(4, 1.2, 4)
		lamp.Position = bPos
		lamp.Color = Color3.fromRGB(255, 175, 60)
		lamp.Material = Enum.Material.Neon
		lamp.Anchored = true
		lamp.CanCollide = false
		lamp.Parent = arena
		addAllFacesTexture(lamp, TEXTURES.RedstoneLamp, 2, 2)

		local lLight = Instance.new("PointLight")
		lLight.Color = Color3.fromRGB(255, 180, 70)
		lLight.Brightness = 1.8
		lLight.Range = 22
		lLight.Parent = lamp
	end

	-- 7. 4 Corner Heavy Energy Towers with ObserverSensor & IronArmor
	local cornerPositions = {
		Vector3.new(138, 0, 138),
		Vector3.new(-138, 0, 138),
		Vector3.new(138, 0, -138),
		Vector3.new(-138, 0, -138),
	}

	for idx, cPos in ipairs(cornerPositions) do
		-- Tower Base (IronArmor riveted plating)
		local tower = Instance.new("Part")
		tower.Name = "Tower_" .. idx
		tower.Size = Vector3.new(8, 28, 8)
		tower.Position = cPos + Vector3.new(0, 14, 0)
		tower.Color = Color3.fromRGB(180, 185, 195)
		tower.Material = Enum.Material.SmoothPlastic
		tower.Anchored = true
		tower.CanCollide = true
		tower.Parent = arena
		addAllFacesTexture(tower, TEXTURES.IronArmor, 4, 4)

		-- Tower Glowing Core
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

		-- Sensor Cap on top of tower (ObserverSensor)
		local cap = Instance.new("Part")
		cap.Name = "TowerCap_" .. idx
		cap.Size = Vector3.new(6, 4, 6)
		cap.Position = cPos + Vector3.new(0, 30, 0)
		cap.Color = Color3.fromRGB(115, 115, 120)
		cap.Material = Enum.Material.SmoothPlastic
		cap.Anchored = true
		cap.CanCollide = false
		cap.Parent = arena
		addAllFacesTexture(cap, TEXTURES.ObserverSensor, 3, 3)
	end

	-- 8. Central Spawn Location
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MechaSpawn"
	spawn.Size = Vector3.new(12, 0.5, 12)
	spawn.Position = Vector3.new(0, 0.15, 0)
	spawn.Color = Color3.fromRGB(40, 45, 60)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Parent = arena

	arena.Parent = Workspace

	-- 9. Lighting Sci-Fi Atmosphere
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
