--!strict
-- ArenaBuilder.luau: Builds an authentic LEGO Voxel mecha battle arena dressed with PoHRoblox industrial blocks
-- Textures used from PoHRoblox BlockRegistry:
--   NetheritePlating (composite dark metal floor)
--   HazardStripes (yellow/black perimeter safety stripes)
--   IronArmor (riveted steel walkways and crosswalks)
--   ReactorCore (central plasma reactor generator)
--   RedstoneLamp (industrial beacon pylons)
--   ObserverSensor (mecha optical sensors)

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZonesData = require(Shared:WaitForChild("ZonesData"))

local ArenaBuilder = {}
ArenaBuilder.PORTAL_POSITION = Vector3.new(0, 0, -56)
ArenaBuilder.PORTAL_RADIUS = 4.8

local TEXTURES = {
	NetheritePlating = "rbxthumb://type=Asset&id=18180391155&w=420&h=420",
	IronArmor = "rbxthumb://type=Asset&id=8677286764&w=420&h=420",
	HazardStripes = "rbxthumb://type=Asset&id=14710653033&w=420&h=420",
	ReactorCore = "rbxthumb://type=Asset&id=8677288287&w=420&h=420",
	RedstoneLamp = "rbxthumb://type=Asset&id=103228454367733&w=420&h=420",
	ObserverSensor = "rbxthumb://type=Asset&id=10402849066&w=420&h=420",
}

-- Authentic LEGO 3D Studs (Picots cylindriques Voxel / LEGO de PoHRoblox)
local BLOCK_SIZE = 4
local BRICK_SEAM_GAP = 0.06
local STUD_HEIGHT = 0.36
local STUD_DIAMETER = 1.15
local STUD_OFFSETS_2X2 = {
	Vector3.new(-1, 0, -1),
	Vector3.new(1, 0, -1),
	Vector3.new(-1, 0, 1),
	Vector3.new(1, 0, 1),
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

-- Crée un vrai bloc LEGO 4x4 avec ses 4 picots cylindriques 3D texturés (fidèle à PoHRoblox VoxelBrickRenderer)
local function createLegoBlock(
	parent: Instance,
	worldX: number,
	worldZ: number,
	color: Color3,
	material: Enum.Material,
	textureId: string
): BasePart
	local brickWidth = BLOCK_SIZE - BRICK_SEAM_GAP
	local brickHeight = 2.0 - (BRICK_SEAM_GAP * 0.5)

	local brick = Instance.new("Part")
	brick.Name = string.format("LegoBrick_%d_%d", math.floor(worldX), math.floor(worldZ))
	brick.Size = Vector3.new(brickWidth, brickHeight, brickWidth)
	brick.Position = Vector3.new(worldX, -brickHeight * 0.5, worldZ)
	brick.Color = color
	brick.Material = material
	brick.Anchored = true
	brick.CanCollide = true
	brick.CanTouch = false
	brick.TopSurface = Enum.SurfaceType.Smooth
	brick.BottomSurface = Enum.SurfaceType.Smooth
	brick.Parent = parent

	-- Texture sur la face supérieure du bloc (4 studs par tuile)
	addTopTexture(brick, textureId, BLOCK_SIZE, BLOCK_SIZE)

	-- 4 picots cylindriques LEGO 3D sur le dessus
	local topY = 0.0
	for _, offset in ipairs(STUD_OFFSETS_2X2) do
		local stud = Instance.new("Part")
		stud.Name = "LegoStud"
		stud.Shape = Enum.PartType.Cylinder
		stud.Size = Vector3.new(STUD_HEIGHT, STUD_DIAMETER, STUD_DIAMETER)
		stud.CFrame = CFrame.new(
			worldX + offset.X,
			topY + STUD_HEIGHT * 0.5,
			worldZ + offset.Z
		) * CFrame.Angles(0, 0, math.rad(90))
		stud.Anchored = true
		stud.CanCollide = false
		stud.CanQuery = false
		stud.CanTouch = false
		stud.CastShadow = true
		stud.Color = color
		stud.Material = material
		stud.TopSurface = Enum.SurfaceType.Smooth
		stud.BottomSurface = Enum.SurfaceType.Smooth
		stud.Parent = brick

		-- Texture dézoomée à l'échelle exacte du bloc parent (fidèle à PoHRoblox VoxelBrickRenderer)
		local studTex = Instance.new("Texture")
		studTex.Name = "StudTexture_Top"
		studTex.Face = Enum.NormalId.Right
		studTex.Texture = textureId
		studTex.StudsPerTileU = BLOCK_SIZE
		studTex.StudsPerTileV = BLOCK_SIZE
		studTex.OffsetStudsU = -offset.Z
		studTex.OffsetStudsV = -offset.X
		studTex.Parent = stud
	end

	return brick
end

local function buildZoneTeleporter(arena: Model, zone: ZonesData.ZoneConfig)
	if not zone.nextZoneId or not zone.nextZoneRequiredLevel then
		return
	end

	local nextZone = ZonesData.GetZone(zone.nextZoneId)
	local portalCenter = ArenaBuilder.PORTAL_POSITION
	local portalModel = Instance.new("Model")
	portalModel.Name = "ZonePortalModel"

	-- Socle blindé extérieur
	local outerBase = Instance.new("Part")
	outerBase.Name = "PortalOuterBase"
	outerBase.Shape = Enum.PartType.Cylinder
	outerBase.Size = Vector3.new(0.6, 12.5, 12.5)
	outerBase.CFrame = CFrame.new(portalCenter.X, 0.3, portalCenter.Z) * CFrame.Angles(0, 0, math.rad(90))
	outerBase.Color = Color3.fromRGB(245, 210, 20)
	outerBase.Material = Enum.Material.SmoothPlastic
	outerBase.Anchored = true
	outerBase.CanCollide = false
	outerBase.Parent = portalModel
	addAllFacesTexture(outerBase, TEXTURES.HazardStripes, 4, 4)

	-- Disque d'énergie central (changé dynamiquement côté client en vert/cyan quand le joueur a le niveau requis)
	local portalCore = Instance.new("Part")
	portalCore.Name = "ZonePortalCore"
	portalCore.Shape = Enum.PartType.Cylinder
	portalCore.Size = Vector3.new(0.85, 9.2, 9.2)
	portalCore.CFrame = CFrame.new(portalCenter.X, 0.45, portalCenter.Z) * CFrame.Angles(0, 0, math.rad(90))
	portalCore.Color = Color3.fromRGB(255, 80, 40)
	portalCore.Material = Enum.Material.Neon
	portalCore.Anchored = true
	portalCore.CanCollide = false
	portalCore.Parent = portalModel

	local coreLight = Instance.new("PointLight")
	coreLight.Name = "PortalCoreLight"
	coreLight.Color = nextZone.themeColor
	coreLight.Brightness = 3.2
	coreLight.Range = 28
	coreLight.Parent = portalCore

	-- Colonne énergétique holographique verticale
	local beam = Instance.new("Part")
	beam.Name = "ZonePortalBeam"
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(11.0, 8.6, 8.6)
	beam.CFrame = CFrame.new(portalCenter.X, 6.0, portalCenter.Z) * CFrame.Angles(0, 0, math.rad(90))
	beam.Color = Color3.fromRGB(255, 80, 40)
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.78
	beam.Anchored = true
	beam.CanCollide = false
	beam.CastShadow = false
	beam.Parent = portalModel

	-- Deux pylônes latéraux blindés + arche supérieure
	for _, xOffset in ipairs({ -6.8, 6.8 }) do
		local pylon = Instance.new("Part")
		pylon.Name = if xOffset < 0 then "PortalPylonLeft" else "PortalPylonRight"
		pylon.Size = Vector3.new(2.4, 13.0, 2.4)
		pylon.Position = Vector3.new(portalCenter.X + xOffset, 6.5, portalCenter.Z)
		pylon.Color = Color3.fromRGB(165, 175, 190)
		pylon.Material = Enum.Material.SmoothPlastic
		pylon.Anchored = true
		pylon.CanCollide = true
		pylon.Parent = portalModel
		addAllFacesTexture(pylon, TEXTURES.IronArmor, 3, 3)

		local strip = Instance.new("Part")
		strip.Name = "PylonEnergyStrip"
		strip.Size = Vector3.new(0.8, 11.5, 2.6)
		strip.Position = pylon.Position
		strip.Color = nextZone.themeColor
		strip.Material = Enum.Material.Neon
		strip.Anchored = true
		strip.CanCollide = false
		strip.Parent = portalModel
	end

	local arch = Instance.new("Part")
	arch.Name = "PortalArch"
	arch.Size = Vector3.new(16.4, 2.2, 2.8)
	arch.Position = Vector3.new(portalCenter.X, 13.5, portalCenter.Z)
	arch.Color = Color3.fromRGB(150, 160, 175)
	arch.Material = Enum.Material.SmoothPlastic
	arch.Anchored = true
	arch.CanCollide = false
	arch.Parent = portalModel
	addAllFacesTexture(arch, TEXTURES.IronArmor, 4, 2)

	-- Ancre BillboardGui flottante visible dans toute l'arène
	local labelAnchor = Instance.new("Part")
	labelAnchor.Name = "PortalLabelAnchor"
	labelAnchor.Size = Vector3.new(1, 1, 1)
	labelAnchor.Position = Vector3.new(portalCenter.X, 16.5, portalCenter.Z)
	labelAnchor.Transparency = 1
	labelAnchor.Anchored = true
	labelAnchor.CanCollide = false
	labelAnchor.Parent = portalModel

	local bb = Instance.new("BillboardGui")
	bb.Name = "PortalBillboard"
	bb.Size = UDim2.new(0, 320, 0, 68)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 240
	bb.Parent = labelAnchor

	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
	bg.BackgroundTransparency = 0.15
	bg.BorderSizePixel = 0
	bg.Parent = bb

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 8)
	bgCorner.Parent = bg

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Name = "PortalStroke"
	bgStroke.Color = nextZone.themeColor
	bgStroke.Thickness = 2
	bgStroke.Parent = bg

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Name = "TitleLabel"
	titleLbl.Size = UDim2.new(1, -12, 0, 28)
	titleLbl.Position = UDim2.new(0, 6, 0, 6)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.GothamBlack
	titleLbl.TextSize = 14
	titleLbl.TextColor3 = nextZone.themeColor
	titleLbl.Text = string.format("TÉLÉPORTEUR ➔ %s", nextZone.name)
	titleLbl.Parent = bg

	local reqLbl = Instance.new("TextLabel")
	reqLbl.Name = "ReqLabel"
	reqLbl.Size = UDim2.new(1, -12, 0, 26)
	reqLbl.Position = UDim2.new(0, 6, 0, 34)
	reqLbl.BackgroundTransparency = 1
	reqLbl.Font = Enum.Font.GothamBold
	reqLbl.TextSize = 13
	reqLbl.TextColor3 = Color3.fromRGB(255, 95, 75)
	reqLbl.Text = string.format("VERROUILLÉ — NIVEAU %d REQUIS", zone.nextZoneRequiredLevel)
	reqLbl.Parent = bg

	portalModel.Parent = arena
end

function ArenaBuilder.BuildArena(zoneOverride: ZonesData.ZoneConfig?)
	local zone = zoneOverride or ZonesData.GetZone(1)

	Workspace:SetAttribute("ZoneId", zone.zoneId)
	Workspace:SetAttribute("ZoneName", zone.name)
	Workspace:SetAttribute("NextZoneId", zone.nextZoneId or 0)
	Workspace:SetAttribute("NextZoneRequiredLevel", zone.nextZoneRequiredLevel or 0)

	local existing = Workspace:FindFirstChild("MechaArena")
	if existing then
		existing:Destroy()
	end

	local arena = Instance.new("Model")
	arena.Name = "MechaArena"

	-- 1. Collision Subfloor (plaque invisible garantissant zéro chute et une physique lisse sous les briques)
	local subfloor = Instance.new("Part")
	subfloor.Name = "CollisionSubfloor"
	subfloor.Size = Vector3.new(152, 4, 152)
	subfloor.Position = Vector3.new(0, -3, 0)
	subfloor.Transparency = 1
	subfloor.Anchored = true
	subfloor.CanCollide = true
	subfloor.Parent = arena

	-- 2. Génération de l'arène Voxel LEGO complète (36 x 36 blocs = 144 x 144 studs)
	local blocksFolder = Instance.new("Folder")
	blocksFolder.Name = "LegoFloorBlocks"
	blocksFolder.Parent = arena

	local GRID_MIN = -18
	local GRID_MAX = 17 -- 36 blocs (-18 à 17)

	for gx = GRID_MIN, GRID_MAX do
		for gz = GRID_MIN, GRID_MAX do
			local worldX = gx * BLOCK_SIZE + 2
			local worldZ = gz * BLOCK_SIZE + 2

			-- Détermination de la zone du bloc
			local isBorder = (gx <= GRID_MIN + 1 or gx >= GRID_MAX - 1 or gz <= GRID_MIN + 1 or gz >= GRID_MAX - 1)
			local isCrosswalk = (gx == 0 or gx == -1 or gz == 0 or gz == -1)
			local isReactor = (gx >= -3 and gx <= 2 and gz >= -3 and gz <= 2)

			local bColor: Color3
			local bMat: Enum.Material
			local bTex: string

			if isBorder then
				-- Bandes de danger jaunes & noires LEGO
				bColor = Color3.fromRGB(245, 210, 20)
				bMat = Enum.Material.SmoothPlastic
				bTex = TEXTURES.HazardStripes
			elseif isReactor then
				-- Réacteur à plasma central lumineux teinté par la Zone
				bColor = zone.themeColor
				bMat = Enum.Material.Neon
				bTex = TEXTURES.ReactorCore
			elseif isCrosswalk then
				-- Passerelles transversales en acier riveté (IronArmor)
				bColor = Color3.fromRGB(190, 195, 205)
				bMat = Enum.Material.SmoothPlastic
				bTex = TEXTURES.IronArmor
			else
				-- Dalles de combat standard teintées selon la Zone
				bColor = zone.floorTint
				bMat = Enum.Material.SmoothPlastic
				bTex = TEXTURES.NetheritePlating
			end

			createLegoBlock(blocksFolder, worldX, worldZ, bColor, bMat, bTex)
		end
	end

	-- 3. Lumière dynamique du réacteur central
	local reactorCoreLight = Instance.new("PointLight")
	reactorCoreLight.Name = "ReactorLight"
	reactorCoreLight.Color = zone.themeColor
	reactorCoreLight.Brightness = 2.8
	reactorCoreLight.Range = 38
	reactorCoreLight.Shadows = true
	local centerPad = Instance.new("Part")
	centerPad.Name = "CenterLightAnchor"
	centerPad.Size = Vector3.new(2, 2, 2)
	centerPad.Position = Vector3.new(0, 1.2, 0)
	centerPad.Transparency = 1
	centerPad.Anchored = true
	centerPad.CanCollide = false
	centerPad.Parent = arena
	reactorCoreLight.Parent = centerPad

	-- 4. Barrières Laser d'énergie en périphérie (Nord, Sud, Est, Ouest à 73 studs)
	local wallConfigs = {
		{ name = "WallNorth", size = Vector3.new(144, 16, 2), pos = Vector3.new(0, 8, 73) },
		{ name = "WallSouth", size = Vector3.new(144, 16, 2), pos = Vector3.new(0, 8, -73) },
		{ name = "WallEast",  size = Vector3.new(2, 16, 144), pos = Vector3.new(73, 8, 0) },
		{ name = "WallWest",  size = Vector3.new(2, 16, 144), pos = Vector3.new(-73, 8, 0) },
	}

	for _, cfg in ipairs(wallConfigs) do
		local wall = Instance.new("Part")
		wall.Name = cfg.name
		wall.Size = cfg.size
		wall.Position = cfg.pos
		wall.Color = zone.themeColor
		wall.Material = Enum.Material.Neon
		wall.Transparency = 0.72
		wall.Anchored = true
		wall.CanCollide = true
		wall.Parent = arena
	end

	-- 5. Balises industrielles RedstoneLamp le long du périmètre
	local beaconPositions = {
		Vector3.new(-48, 0.5, 68), Vector3.new(0, 0.5, 68), Vector3.new(48, 0.5, 68),
		Vector3.new(-48, 0.5, -68), Vector3.new(0, 0.5, -68), Vector3.new(48, 0.5, -68),
		Vector3.new(68, 0.5, -48), Vector3.new(68, 0.5, 0), Vector3.new(68, 0.5, 48),
		Vector3.new(-68, 0.5, -48), Vector3.new(-68, 0.5, 0), Vector3.new(-68, 0.5, 48),
	}

	for bIdx, bPos in ipairs(beaconPositions) do
		local lamp = Instance.new("Part")
		lamp.Name = "PerimeterLamp_" .. bIdx
		lamp.Size = Vector3.new(3.8, 1.2, 3.8)
		lamp.Position = bPos
		lamp.Color = Color3.fromRGB(255, 175, 60)
		lamp.Material = Enum.Material.Neon
		lamp.Anchored = true
		lamp.CanCollide = false
		lamp.Parent = arena
		addAllFacesTexture(lamp, TEXTURES.RedstoneLamp, 2, 2)

		local lLight = Instance.new("PointLight")
		lLight.Color = Color3.fromRGB(255, 180, 70)
		lLight.Brightness = 1.6
		lLight.Range = 20
		lLight.Parent = lamp
	end

	-- 6. 4 Tours énergétiques lourdes aux coins avec ObserverSensor
	local cornerPositions = {
		Vector3.new(66, 0, 66),
		Vector3.new(-66, 0, 66),
		Vector3.new(66, 0, -66),
		Vector3.new(-66, 0, -66),
	}

	for idx, cPos in ipairs(cornerPositions) do
		local tower = Instance.new("Part")
		tower.Name = "Tower_" .. idx
		tower.Size = Vector3.new(8, 24, 8)
		tower.Position = cPos + Vector3.new(0, 12, 0)
		tower.Color = Color3.fromRGB(180, 185, 195)
		tower.Material = Enum.Material.SmoothPlastic
		tower.Anchored = true
		tower.CanCollide = true
		tower.Parent = arena
		addAllFacesTexture(tower, TEXTURES.IronArmor, 4, 4)

		local towerLight = Instance.new("Part")
		towerLight.Name = "TowerCore"
		towerLight.Size = Vector3.new(4, 22, 4)
		towerLight.Position = tower.Position
		towerLight.Color = zone.themeColor
		towerLight.Material = Enum.Material.Neon
		towerLight.Anchored = true
		towerLight.CanCollide = false
		towerLight.Parent = arena

		local pLight = Instance.new("PointLight")
		pLight.Color = zone.themeColor
		pLight.Brightness = 2.5
		pLight.Range = 35
		pLight.Parent = towerLight

		local cap = Instance.new("Part")
		cap.Name = "TowerCap_" .. idx
		cap.Size = Vector3.new(6, 4, 6)
		cap.Position = cPos + Vector3.new(0, 26, 0)
		cap.Color = Color3.fromRGB(115, 115, 120)
		cap.Material = Enum.Material.SmoothPlastic
		cap.Anchored = true
		cap.CanCollide = false
		cap.Parent = arena
		addAllFacesTexture(cap, TEXTURES.ObserverSensor, 3, 3)
	end

	-- 6B. Téléporteur inter-serveurs vers la Zone suivante (verrouillé par niveau)
	buildZoneTeleporter(arena, zone)

	-- 7. Spawn Central
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MechaSpawn"
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.Position = Vector3.new(0, 0.1, 0)
	spawn.Transparency = 1
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = arena

	arena.Parent = Workspace

	-- 8. Éclairage Sci-Fi Lumineux & Net (fidèle à Unity Directional Light Intensity 2.0)
	Lighting.ClockTime = 14.0
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(130, 135, 145)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 145, 160)
	Lighting.FogColor = Color3.fromRGB(180, 200, 220)
	Lighting.FogStart = 500
	Lighting.FogEnd = 1200
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.8

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.5
		bloom.Size = 16
		bloom.Threshold = 0.9
		bloom.Parent = Lighting
	end

	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Contrast = 0.08
		cc.Saturation = 0.12
		cc.Parent = Lighting
	end
end

return ArenaBuilder
