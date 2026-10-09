-- Buduje całą mapę kodem: ulica, 8 garaży ze stojakami, kanał z wodą
-- (Terrain), 3 pomosty ze strefami, most kolejowy. Dzięki temu plik
-- .rbxlx działa od razu po otwarciu w Studio, bez ręcznego budowania.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Geo = require(Shared.Geo)

local L = Config.Layout
local MapBuilder = {}

local map: Folder

local function block(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or map
	return p
end

local function sign(parent: BasePart, text: string, color: Color3, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	label.TextColor3 = color
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
end

local function billboard(parent: BasePart, text: string, color: Color3, offset: number, size: Vector2?, name: string?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = name or "BillboardGui"
	local s = size or Vector2.new(260, 70)
	gui.Size = UDim2.fromOffset(s.X, s.Y)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	gui.MaxDistance = 250
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
	return label
end

local function buildGround()
	local concrete = Color3.fromRGB(95, 95, 100)
	local grass = Color3.fromRGB(70, 110, 60)
	local canalLen = L.ZoneLength * #Config.Zones + 5
	local w = L.MapHalfWidth * 2
	-- Ulica + teren garaży (od tyłu garaży do brzegu kanału)
	local streetDepth = L.CanalStartZ - L.StreetMinZ
	block("Street", Vector3.new(w, 16, streetDepth), CFrame.new(0, -8, L.StreetMinZ + streetDepth / 2), concrete, Enum.Material.Asphalt)
	-- Pasy terenu po bokach kanału i za nim
	local sideW = L.MapHalfWidth - L.CanalMaxX
	block("BankLeft", Vector3.new(sideW, 16, canalLen + 30), CFrame.new(-L.MapHalfWidth + sideW / 2, -8, L.CanalStartZ + (canalLen + 30) / 2), grass, Enum.Material.Grass)
	block("BankRight", Vector3.new(sideW, 16, canalLen + 30), CFrame.new(L.MapHalfWidth - sideW / 2, -8, L.CanalStartZ + (canalLen + 30) / 2), grass, Enum.Material.Grass)
	block("BankBack", Vector3.new(L.CanalMaxX - L.CanalMinX, 16, 30), CFrame.new(0, -8, L.CanalStartZ + canalLen + 15), grass, Enum.Material.Grass)
	-- Dno kanału
	block("CanalFloor", Vector3.new(L.CanalMaxX - L.CanalMinX, 2, canalLen), CFrame.new(0, L.FloorY - 1, L.CanalStartZ + canalLen / 2), Color3.fromRGB(60, 55, 40), Enum.Material.Mud)

	-- Woda: Terrain (pływanie działa), a gdy go brak - półprzezroczysta płyta
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	local waterTop = L.WaterY
	local waterH = waterTop - L.FloorY
	local waterCf = CFrame.new(0, L.FloorY + waterH / 2, L.CanalStartZ + canalLen / 2)
	local waterSize = Vector3.new(L.CanalMaxX - L.CanalMinX, waterH, canalLen)
	if terrain then
		terrain.WaterColor = Color3.fromRGB(60, 80, 45)
		terrain.WaterTransparency = 0.35
		terrain.WaterReflectance = 0.2
		terrain.WaterWaveSize = 0.08
		terrain:FillBlock(waterCf, waterSize, Enum.Material.Water)
	else
		local water = block("WaterFallback", waterSize, waterCf, Color3.fromRGB(60, 80, 45), Enum.Material.Glass)
		water.Transparency = 0.4
		water.CanCollide = false
	end

	-- Niewidzialne ściany granic mapy
	local h = 120
	for _, data in ipairs({
		{ Vector3.new(w, h, 2), Vector3.new(0, h / 2, L.StreetMinZ - 1) },
		{ Vector3.new(w, h, 2), Vector3.new(0, h / 2, L.CanalStartZ + canalLen + 31) },
		{ Vector3.new(2, h, canalLen + 200), Vector3.new(-L.MapHalfWidth - 1, h / 2, 60) },
		{ Vector3.new(2, h, canalLen + 200), Vector3.new(L.MapHalfWidth + 1, h / 2, 60) },
	}) do
		local wall = block("Boundary", data[1], CFrame.new(data[2]), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		wall.Transparency = 1
	end
end

local function buildPiers()
	local canalEnd = L.CanalStartZ + L.ZoneLength * #Config.Zones
	for _, x in ipairs(L.PierXs) do
		local length = canalEnd - L.CanalStartZ + 3
		local deck = block("Pier", Vector3.new(L.PierWidth, 1, length), CFrame.new(x, 0, L.CanalStartZ - 2 + length / 2), Color3.fromRGB(120, 85, 55), Enum.Material.WoodPlanks)
		deck:SetAttribute("Pier", true)
		-- Słupy
		for z = L.CanalStartZ + 10, canalEnd, 20 do
			for _, side in ipairs({ -1, 1 }) do
				local postH = -L.FloorY + 0.5
				block("Post", Vector3.new(1, postH, 1), CFrame.new(x + side * (L.PierWidth / 2 - 0.5), -postH / 2, z), Color3.fromRGB(80, 55, 35), Enum.Material.Wood)
			end
		end
		-- Pasy stref + tablice
		for i, zone in ipairs(Config.Zones) do
			local z0 = L.CanalStartZ + (i - 1) * L.ZoneLength
			for _, side in ipairs({ -1, 1 }) do
				local stripe = block("ZoneStripe", Vector3.new(0.6, 0.2, L.ZoneLength - 1), CFrame.new(x + side * (L.PierWidth / 2 - 0.3), 0.6, z0 + L.ZoneLength / 2), zone.color, Enum.Material.Neon)
				stripe.CanCollide = false
			end
			local pole = block("ZoneSign", Vector3.new(0.6, 6, 0.6), CFrame.new(x + L.PierWidth / 2 - 0.3, 3.5, z0 + 2), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
			billboard(pole, "STREFA " .. i .. ": " .. string.upper(zone.name) .. "\nwymagany zasięg " .. zone.reach .. " m", zone.color, 4)
		end
	end
	-- Pochylnie z dna kanału na brzeg (wyjście dla tych, którzy wpadli)
	local depth = -L.FloorY
	local run = depth * 2
	local slope = math.atan2(depth, run)
	for _, x in ipairs({ -205, -70, 70, 205 }) do
		local ramp = block("Ramp", Vector3.new(6, 1, math.sqrt(depth * depth + run * run)), CFrame.new(x, -depth / 2, L.CanalStartZ + run / 2) * CFrame.Angles(slope, 0, 0), Color3.fromRGB(110, 110, 100), Enum.Material.DiamondPlate)
		ramp:SetAttribute("Ramp", true)
	end

	-- Most kolejowy nad strefą 3 ("Pod Mostem")
	local bridgeZ = L.CanalStartZ + L.ZoneLength * 2.5
	block("RailBridge", Vector3.new(L.MapHalfWidth * 2, 3, 14), CFrame.new(0, 24, bridgeZ), Color3.fromRGB(90, 60, 50), Enum.Material.CorrodedMetal)
	for _, x in ipairs({ -210, -70, 70, 210 }) do
		block("BridgePillar", Vector3.new(4, 40, 4), CFrame.new(x, 4, bridgeZ), Color3.fromRGB(110, 100, 95), Enum.Material.Concrete)
	end
	-- Wylot ścieku na końcu kanału (strefa 5)
	local pipe = block("SewerPipe", Vector3.new(10, 18, 18), CFrame.new(0, -2, canalEnd + 12) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(70, 75, 60), Enum.Material.CorrodedMetal)
	pipe.Shape = Enum.PartType.Cylinder
end

-- Struktura działki: Plot_i/{Floor, Sign, Pad, Pedestals/Pedestal_n, Items}
local function buildPlot(index: number)
	local folder = Instance.new("Folder")
	folder.Name = "Plot_" .. index
	folder:SetAttribute("Index", index)
	folder.Parent = map

	local c = Geo.plotCenter(index)
	local sx, sz = L.PlotSizeX, L.PlotSizeZ
	local floorColor = Color3.fromHSV((index - 1) / L.PlotCount, 0.35, 0.75)
	block("Floor", Vector3.new(sx, 1, sz), CFrame.new(c.X, -0.3, c.Z), floorColor, Enum.Material.Concrete, folder)
	local wallColor = Color3.fromRGB(150, 140, 130)
	block("WallBack", Vector3.new(sx, 12, 1), CFrame.new(c.X, 6, c.Z - sz / 2), wallColor, Enum.Material.Brick, folder)
	block("WallLeft", Vector3.new(1, 12, sz), CFrame.new(c.X - sx / 2, 6, c.Z), wallColor, Enum.Material.Brick, folder)
	block("WallRight", Vector3.new(1, 12, sz), CFrame.new(c.X + sx / 2, 6, c.Z), wallColor, Enum.Material.Brick, folder)
	-- Belka nad wjazdem z nazwą właściciela
	local beam = block("GateBeam", Vector3.new(sx, 3, 1), CFrame.new(c.X, 13.5, c.Z + sz / 2), Color3.fromRGB(50, 50, 55), Enum.Material.Metal, folder)
	sign(beam, "WOLNY GARAŻ", Color3.fromRGB(255, 255, 255), Enum.NormalId.Front)
	sign(beam, "WOLNY GARAŻ", Color3.fromRGB(255, 255, 255), Enum.NormalId.Back)
	-- Linia Safe Zone na podjeździe
	local line = block("SafeLine", Vector3.new(sx, 0.1, 0.8), CFrame.new(c.X, 0.25, c.Z + sz / 2 + L.DrivewayDepth), Color3.fromRGB(80, 255, 120), Enum.Material.Neon, folder)
	line.CanCollide = false

	-- Kasa (odbiór dochodu)
	local pad = block("Pad", Vector3.new(6, 0.4, 6), CFrame.new(c.X + 17, 0.4, c.Z + sz / 2 - 5), Color3.fromRGB(60, 220, 90), Enum.Material.Neon, folder)
	local padLabel = billboard(pad, "KASA: $0", Color3.fromRGB(120, 255, 140), 4, Vector2.new(200, 50), "PadGui")
	padLabel.Name = "PadLabel"

	-- Stojaki: 6 kolumn x 4 rzędy = 24 miejsca
	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = folder
	local n = 0
	for row = 0, 3 do
		for col = 0, 5 do
			n += 1
			local x = c.X - 18.75 + col * 7.5
			local z = c.Z - sz / 2 + 6 + row * 7
			local ped = block("Pedestal_" .. n, Vector3.new(1.2, 4.5, 4.5), CFrame.new(x, 0.6, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 70, 80), Enum.Material.DiamondPlate, pedestals)
			ped.Shape = Enum.PartType.Cylinder
			ped:SetAttribute("Slot", n)
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "SellPrompt"
			prompt.ActionText = "Sprzedaj"
			prompt.ObjectText = ""
			prompt.HoldDuration = 0.6
			prompt.MaxActivationDistance = 7
			prompt.RequiresLineOfSight = false
			prompt.Enabled = false
			prompt.Parent = ped
		end
	end

	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = folder
end

local function buildDecor()
	-- Latarnie wzdłuż ulicy
	for x = -250, 250, 50 do
		local pole = block("Lamp", Vector3.new(0.8, 14, 0.8), CFrame.new(x, 7, -40), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
		local head = block("LampHead", Vector3.new(2, 1, 2), CFrame.new(x, 14.5, -40), Color3.fromRGB(255, 230, 160), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Range = 24
		light.Brightness = 1.5
		light.Color = Color3.fromRGB(255, 220, 160)
		light.Parent = head
		pole.CanCollide = true
	end
	-- Tablica startowa
	local board = block("Welcome", Vector3.new(24, 8, 1), CFrame.new(0, 6, -20), Color3.fromRGB(30, 30, 35), Enum.Material.Metal)
	sign(board, "MAGNET & STEAL A BRAINROT\nŁów na pomostach → nieś do garażu → nie daj się okraść!", Color3.fromRGB(255, 220, 80), Enum.NormalId.Back)
	sign(board, "Strefy 1-5: im dalej na pomoście, tym rzadsze Brainroty", Color3.fromRGB(255, 220, 80), Enum.NormalId.Front)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "FallbackSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.1, -50)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = map
end

local function buildLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atm = Instance.new("Atmosphere")
		atm.Density = 0.32
		atm.Haze = 1.5
		atm.Color = Color3.fromRGB(200, 190, 170)
		atm.Parent = Lighting
	end
end

function MapBuilder.build(): Folder
	local existing = workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	buildGround()
	buildPiers()
	for i = 1, L.PlotCount do
		buildPlot(i)
	end
	buildDecor()
	buildLighting()
	return map
end

function MapBuilder.plotFolder(index: number): Folder
	return map:WaitForChild("Plot_" .. index) :: Folder
end

return MapBuilder
