--!strict
-- Katalog Brainrotów: 5 stref x 6 rzadkości = 30 obiektów.
-- weight = waga bazowa w kg (mnożona przez rzadkość i rozmiar).
-- shape = kształt proceduralnego modelu (Ball, Block, Cylinder, Tall, Flat).

export type Brainrot = {
	id: string,
	name: string,
	zone: number,
	rarity: string,
	weight: number,
	shape: string,
	color: Color3,
	accent: Color3,
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local list: { Brainrot } = {
	-- Strefa 1: Płycizna
	{ id = "kapsel", name = "Kapsel Kapselini", zone = 1, rarity = "Common", weight = 4, shape = "Flat", color = c(160, 90, 50), accent = c(220, 220, 220) },
	{ id = "srubapim", name = "Brr Brr Śrubapim", zone = 1, rarity = "Rare", weight = 8, shape = "Tall", color = c(120, 120, 130), accent = c(90, 160, 60) },
	{ id = "hulajnoga", name = "Hulajnoga Sigma", zone = 1, rarity = "Epic", weight = 12, shape = "Block", color = c(40, 40, 45), accent = c(0, 200, 120) },
	{ id = "rower", name = "Rower Taty (Poszedł po Mleko)", zone = 1, rarity = "Secret", weight = 10, shape = "Block", color = c(200, 40, 40), accent = c(240, 240, 240) },
	{ id = "wozek", name = "Przeklęty Wózek Sklepowy", zone = 1, rarity = "Cursed", weight = 9, shape = "Block", color = c(90, 90, 100), accent = c(120, 255, 60) },
	{ id = "zlotykapsel", name = "Złoty Kapsel Wszechświata", zone = 1, rarity = "Mythic", weight = 8, shape = "Flat", color = c(255, 210, 60), accent = c(255, 255, 255) },

	-- Strefa 2: Śluza
	{ id = "puszka", name = "Puszka Pusztini", zone = 2, rarity = "Common", weight = 20, shape = "Cylinder", color = c(180, 50, 50), accent = c(230, 230, 230) },
	{ id = "tralalero", name = "Tralalero Złomalala", zone = 2, rarity = "Rare", weight = 30, shape = "Ball", color = c(60, 120, 200), accent = c(250, 250, 250) },
	{ id = "chimpanzini", name = "Chimpanzini Magnesini", zone = 2, rarity = "Epic", weight = 40, shape = "Tall", color = c(230, 210, 60), accent = c(110, 70, 40) },
	{ id = "sejf", name = "Sejf z Kanału", zone = 2, rarity = "Secret", weight = 45, shape = "Block", color = c(70, 75, 85), accent = c(255, 200, 40) },
	{ id = "lalka", name = "Lalka Babci (Patrzy)", zone = 2, rarity = "Cursed", weight = 40, shape = "Tall", color = c(240, 200, 190), accent = c(255, 0, 0) },
	{ id = "tungtung", name = "Tung Tung Rdzawy Sahur", zone = 2, rarity = "Mythic", weight = 40, shape = "Tall", color = c(150, 95, 55), accent = c(255, 230, 120) },

	-- Strefa 3: Pod Mostem
	{ id = "kaloryfer", name = "Kaloryfer Kaloryferini", zone = 3, rarity = "Common", weight = 60, shape = "Block", color = c(220, 220, 215), accent = c(150, 80, 40) },
	{ id = "balerina", name = "Balerina Kapslina", zone = 3, rarity = "Rare", weight = 90, shape = "Tall", color = c(255, 160, 200), accent = c(120, 70, 40) },
	{ id = "bombardiro", name = "Bombardiro Magnetilo", zone = 3, rarity = "Epic", weight = 120, shape = "Cylinder", color = c(80, 110, 60), accent = c(200, 60, 60) },
	{ id = "lirili", name = "Lirili Rdzawila", zone = 3, rarity = "Secret", weight = 150, shape = "Ball", color = c(140, 160, 110), accent = c(255, 120, 40) },
	{ id = "assassino", name = "Kapsla Assassino", zone = 3, rarity = "Cursed", weight = 160, shape = "Tall", color = c(60, 40, 30), accent = c(255, 30, 30) },
	{ id = "trippi", name = "Trippi Śruppi Królewski", zone = 3, rarity = "Mythic", weight = 200, shape = "Ball", color = c(255, 140, 40), accent = c(80, 200, 255) },

	-- Strefa 4: Głębia
	{ id = "felga", name = "Felga Felgini", zone = 4, rarity = "Common", weight = 200, shape = "Flat", color = c(170, 170, 180), accent = c(60, 60, 60) },
	{ id = "bobrito", name = "Bobrito Złomito", zone = 4, rarity = "Rare", weight = 300, shape = "Ball", color = c(120, 80, 50), accent = c(240, 240, 240) },
	{ id = "pralka", name = "Pralka Wirówka Turbo", zone = 4, rarity = "Epic", weight = 400, shape = "Block", color = c(245, 245, 245), accent = c(40, 140, 255) },
	{ id = "lavaca", name = "La Vaca Magnetita", zone = 4, rarity = "Secret", weight = 450, shape = "Ball", color = c(250, 250, 250), accent = c(30, 30, 30) },
	{ id = "syrena", name = "Syrena z Kanału", zone = 4, rarity = "Cursed", weight = 500, shape = "Tall", color = c(40, 120, 110), accent = c(150, 255, 80) },
	{ id = "neodymalala", name = "Tralalero Neodymalala", zone = 4, rarity = "Mythic", weight = 600, shape = "Ball", color = c(40, 90, 255), accent = c(255, 255, 255) },

	-- Strefa 5: Przeklęty Ściek
	{ id = "rura", name = "Rura Rurini", zone = 5, rarity = "Common", weight = 600, shape = "Cylinder", color = c(100, 100, 90), accent = c(60, 200, 60) },
	{ id = "kaczka", name = "Gumowa Kaczka Mafii", zone = 5, rarity = "Rare", weight = 800, shape = "Ball", color = c(255, 220, 30), accent = c(20, 20, 20) },
	{ id = "czolg", name = "Czołg z Demobilu", zone = 5, rarity = "Epic", weight = 1000, shape = "Block", color = c(70, 90, 50), accent = c(40, 40, 40) },
	{ id = "bombombini", name = "Bombombini Gusini Ściekowy", zone = 5, rarity = "Secret", weight = 1200, shape = "Tall", color = c(200, 200, 200), accent = c(255, 140, 0) },
	{ id = "kapitan", name = "Skrzynia Przeklętego Kapitana", zone = 5, rarity = "Cursed", weight = 1300, shape = "Block", color = c(90, 55, 30), accent = c(130, 255, 80) },
	{ id = "magnetronio", name = "Magnetronio Imperatore", zone = 5, rarity = "Mythic", weight = 1500, shape = "Tall", color = c(30, 30, 40), accent = c(255, 215, 0) },
}

local byId: { [string]: Brainrot } = {}
local byZoneRarity: { [string]: Brainrot } = {}
for _, b in ipairs(list) do
	byId[b.id] = b
	byZoneRarity[b.zone .. ":" .. b.rarity] = b
end

local Brainrots = {}
Brainrots.List = list

function Brainrots.get(id: string): Brainrot?
	return byId[id]
end

function Brainrots.forZone(zone: number, rarity: string): Brainrot
	local b = byZoneRarity[zone .. ":" .. rarity]
	assert(b, "Brak brainrota dla strefy " .. zone .. " i rzadkości " .. rarity)
	return b
end

return Brainrots
