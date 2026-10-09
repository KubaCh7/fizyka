-- Proceduralne modele: Brainroty, słupy światła, narzędzia gracza.
-- Brak zewnętrznych assetów, więc wszystko składamy z prymitywów.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Brainrots = require(Shared.Brainrots)
local Loot = require(Shared.Loot)
local Format = require(Shared.Format)

local Models = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = true
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function addEyes(model: Model, body: BasePart, faceZ: number, eyeY: number, spread: number)
	for _, side in ipairs({ -1, 1 }) do
		local eye = part({
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.7, 0.7, 0.7),
			Color = Color3.new(1, 1, 1),
			Material = Enum.Material.SmoothPlastic,
		})
		eye.CFrame = body.CFrame * CFrame.new(side * spread, eyeY, -faceZ)
		eye.Parent = model
		weld(body, eye)
		local pupil = part({
			Name = "Pupil",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.35, 0.35, 0.35),
			Color = Color3.new(0, 0, 0),
			Material = Enum.Material.SmoothPlastic,
		})
		pupil.CFrame = eye.CFrame * CFrame.new(0, 0, -0.25)
		pupil.Parent = model
		weld(body, pupil)
	end
end

local function applyMutation(body: BasePart, mutId: string)
	if mutId == "Shiny" then
		body.Material = Enum.Material.Foil
		body.Reflectance = 0.25
	elseif mutId == "Gold" then
		body.Color = Color3.fromRGB(255, 200, 40)
		body.Material = Enum.Material.Foil
		body.Reflectance = 0.35
	elseif mutId == "Diamond" then
		body.Color = Color3.fromRGB(130, 230, 255)
		body.Material = Enum.Material.Glass
		body.Transparency = 0.2
	elseif mutId == "Radioactive" then
		body.Color = Color3.fromRGB(90, 255, 60)
		body.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = body.Color
		light.Range = 10
		light.Brightness = 2
		light.Parent = body
	elseif mutId == "Rainbow" then
		body.Material = Enum.Material.Neon
		CollectionService:AddTag(body, "Rainbow") -- klient płynnie zmienia kolor
	end
end

local function applyRarityFx(body: BasePart, rarity: Config.Rarity)
	if rarity.id == "Secret" then
		local s = Instance.new("Sparkles")
		s.SparkleColor = rarity.color
		s.Parent = body
	elseif rarity.id == "Cursed" then
		local f = Instance.new("Fire")
		f.Color = Color3.fromRGB(80, 255, 40)
		f.SecondaryColor = Color3.fromRGB(10, 40, 10)
		f.Size = 3
		f.Heat = 4
		f.Parent = body
	elseif rarity.id == "Mythic" then
		local s = Instance.new("Sparkles")
		s.SparkleColor = rarity.color
		s.Parent = body
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 14
		light.Brightness = 3
		light.Parent = body
	end
end

-- Buduje model Brainrota. Wszystkie części są przyspawane do "Body"
-- (PrimaryPart), niekolizyjne i bez masy.
function Models.brainrot(item: Loot.Item): Model
	local b = Brainrots.get(item.id)
	assert(b, "Nieznany brainrot " .. item.id)
	local rarity = Loot.rarityOf(item)

	local model = Instance.new("Model")
	model.Name = b.name

	local body: Part
	local faceZ, eyeY, spread = 1.2, 0.4, 0.55
	if b.shape == "Ball" then
		body = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3) })
		faceZ, eyeY = 1.35, 0.4
	elseif b.shape == "Cylinder" then
		body = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 2.4, 2.4) })
		body.CFrame = CFrame.Angles(0, 0, math.rad(90))
		faceZ, eyeY = 1.1, 0.5
	elseif b.shape == "Tall" then
		body = part({ Size = Vector3.new(2, 3.6, 1.8) })
		faceZ, eyeY, spread = 0.95, 1.0, 0.45
	elseif b.shape == "Flat" then
		body = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 3.2, 3.2) })
		body.CFrame = CFrame.Angles(0, 0, math.rad(90))
		faceZ, eyeY = 1.5, 0.45
	else
		body = part({ Size = Vector3.new(3.4, 2.6, 2.4) })
		faceZ, eyeY = 1.25, 0.4
	end
	body.Name = "Body"
	body.Color = b.color
	body.Material = Enum.Material.CorrodedMetal
	body.Parent = model
	model.PrimaryPart = body

	-- Akcent (pasek / czapka) w kolorze dodatkowym
	local upright = CFrame.new(body.Position)
	local accent = part({
		Name = "Accent",
		Size = Vector3.new(body.Size.Y > 3 and 2.2 or 2.6, 0.5, 2.0),
		Color = b.accent,
		Material = Enum.Material.SmoothPlastic,
	})
	local topY = if b.shape == "Tall" then 2.05 elseif b.shape == "Flat" then 0.65 else 1.45
	accent.CFrame = upright * CFrame.new(0, topY, 0)
	accent.Parent = model
	weld(body, accent)

	-- Oczy patrzą w -Z (przód modelu); dla walców liczymy względem pionu
	local faceRef = part({ Name = "FaceRef", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2) })
	faceRef.CFrame = upright
	faceRef.Parent = model
	weld(body, faceRef)
	addEyes(model, faceRef, faceZ, eyeY, spread)

	-- Korona dla Secret+ (czytelny sygnał rzadkości z daleka)
	if rarity.inHands then
		local crown = part({
			Name = "Crown",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 1.6, 1.6),
			Color = rarity.color,
			Material = Enum.Material.Neon,
		})
		crown.CFrame = upright * CFrame.new(0, topY + 0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
		crown.Parent = model
		weld(body, crown)
	end

	applyMutation(body, item.mut)
	applyRarityFx(body, rarity)

	local scale = Loot.size(item.size).scale
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	model:SetAttribute("Uid", item.uid)
	return model
end

function Models.label(model: Model, item: Loot.Item, extra: string?, maxDistance: number?)
	local rarity = Loot.rarityOf(item)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = maxDistance or 70
	gui.LightInfluence = 0
	gui.Adornee = model.PrimaryPart

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.45, 0)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Text = Loot.displayName(item)
	name.Parent = gui

	local tier = Instance.new("TextLabel")
	tier.BackgroundTransparency = 1
	tier.Position = UDim2.new(0, 0, 0.45, 0)
	tier.Size = UDim2.new(1, 0, 0.3, 0)
	tier.Font = Enum.Font.FredokaOne
	tier.TextScaled = true
	tier.TextColor3 = rarity.color
	tier.TextStrokeTransparency = 0.3
	tier.Text = string.upper(rarity.id)
	tier.Parent = gui

	if extra then
		local ex = Instance.new("TextLabel")
		ex.BackgroundTransparency = 1
		ex.Position = UDim2.new(0, 0, 0.75, 0)
		ex.Size = UDim2.new(1, 0, 0.25, 0)
		ex.Font = Enum.Font.FredokaOne
		ex.TextScaled = true
		ex.TextColor3 = Color3.fromRGB(120, 255, 120)
		ex.TextStrokeTransparency = 0.3
		ex.Text = extra
		ex.Parent = gui
	end
	gui.Parent = model
end

function Models.cpsText(item: Loot.Item, rebirths: number): string
	return Format.money(Loot.cps(item) * Loot.rebirthMult(rebirths)) .. "/s"
end

-- Słup światła widoczny z całej mapy (Secret+ w rękach lub na wodzie)
function Models.lightPillar(color: Color3): Part
	local p = part({
		Name = "LightPillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(300, 3, 3),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CastShadow = false,
	})
	return p
end

-- Magnes na końcu linki podczas łowienia/kradzieży
function Models.magnetHead(): Part
	local p = part({
		Name = "MagnetHead",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 1.6, 1.6),
		Color = Color3.fromRGB(70, 70, 80),
		Material = Enum.Material.Metal,
		Anchored = true,
	})
	local ring = part({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.85, 1.0, 1.0),
		Color = Color3.fromRGB(220, 40, 40),
		Material = Enum.Material.SmoothPlastic,
	})
	ring.CFrame = p.CFrame
	ring.Parent = p
	weld(p, ring)
	local a = Instance.new("Attachment")
	a.Name = "LineAttachment"
	a.Parent = p
	return p
end

function Models.line(a0: Attachment, a1: Attachment, color: Color3): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.12
	beam.Width1 = 0.12
	beam.Color = ColorSequence.new(color)
	beam.FaceCamera = true
	beam.Segments = 12
	beam.CurveSize0 = -2
	beam.CurveSize1 = 2
	beam.LightInfluence = 0
	beam.Parent = a0.Parent
	return beam
end

-- Narzędzie z małym uchwytem (orientacja uchwytu nie ma znaczenia wizualnie)
function Models.tool(name: string, color: Color3, tip: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.ToolTip = tip
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("GameTool", true)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 0.6, 1.4)
	handle.Color = color
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Size = Vector3.new(0.65, 0.65, 0.4)
	cap.Color = Color3.fromRGB(200, 200, 210)
	cap.Material = Enum.Material.Metal
	cap.CanCollide = false
	cap.Massless = true
	cap.CFrame = handle.CFrame * CFrame.new(0, 0, -0.85)
	cap.Parent = tool
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = cap
	w.Parent = handle

	local tipAtt = Instance.new("Attachment")
	tipAtt.Name = "Tip"
	tipAtt.Position = Vector3.new(0, 0, -1)
	tipAtt.Parent = handle
	return tool
end

return Models
