--!strict
-- Wszystkie wartości balansu w jednym miejscu. Zmiana tutaj nie wymaga
-- ruszania logiki serwera ani klienta.

local Config = {}

----------------------------------------------------------------------
-- Debug (tylko do testów; w Studio dodatkowo działa przycisk DEV +$)
----------------------------------------------------------------------
Config.Debug = {
	StartCash = 0,
	LuckMultiplier = 1, -- np. 50, żeby szybko zobaczyć Secret/Mythic
	StudioCheats = true, -- przycisk DEV na HUD, działa tylko w Studio
	SaveInStudio = true, -- wymaga "Enable Studio Access to API Services"
}

Config.DataStoreName = "MagnetStealBrainrot_v1"

----------------------------------------------------------------------
-- Rzadkości: szansa bazowa (Common dostaje resztę), mnożnik wartości,
-- parametry minigry i to, czy drop jest ogłaszany na serwerze.
----------------------------------------------------------------------
export type Rarity = {
	id: string,
	chance: number,
	mult: number,
	weightMult: number,
	color: Color3,
	inHands: boolean,
	announce: boolean,
	speed: number, -- prędkość obiektu w minigrze (szerokości paska / s)
	retarget: number, -- co ile sekund obiekt zmienia cel
	qte: number, -- liczba skill-checków
	drain: number, -- mnożnik spadku postępu poza polem
	perfect: number, -- szerokość strefy Perfect w skill-checku (0..1)
	good: number, -- szerokość strefy Good w skill-checku (0..1)
	minTime: number, -- dolna granica czasu minigry przy maks. umiejętnościach (walidacja serwera x0.8)
}

Config.Rarities = {
	{ id = "Common", chance = 0, mult = 1, weightMult = 1.0, color = Color3.fromRGB(190, 190, 190), inHands = false, announce = false,
		speed = 0.30, retarget = 1.2, qte = 0, drain = 1.0, perfect = 0.11, good = 0.25, minTime = 2.0 },
	{ id = "Rare", chance = 0.20, mult = 3, weightMult = 1.2, color = Color3.fromRGB(60, 140, 255), inHands = false, announce = false,
		speed = 0.40, retarget = 1.0, qte = 1, drain = 1.1, perfect = 0.09, good = 0.22, minTime = 1.8 },
	{ id = "Epic", chance = 0.06, mult = 10, weightMult = 1.5, color = Color3.fromRGB(170, 70, 255), inHands = false, announce = false,
		speed = 0.55, retarget = 0.85, qte = 1, drain = 1.25, perfect = 0.08, good = 0.19, minTime = 1.8 },
	{ id = "Secret", chance = 0.005, mult = 50, weightMult = 2.0, color = Color3.fromRGB(255, 50, 50), inHands = true, announce = true,
		speed = 0.70, retarget = 0.7, qte = 2, drain = 1.4, perfect = 0.06, good = 0.17, minTime = 1.5 },
	{ id = "Cursed", chance = 0.001, mult = 200, weightMult = 2.5, color = Color3.fromRGB(120, 255, 60), inHands = true, announce = true,
		speed = 0.85, retarget = 0.6, qte = 2, drain = 1.6, perfect = 0.05, good = 0.14, minTime = 1.5 },
	{ id = "Mythic", chance = 0.0001, mult = 1000, weightMult = 3.0, color = Color3.fromRGB(255, 200, 40), inHands = true, announce = true,
		speed = 1.00, retarget = 0.5, qte = 3, drain = 1.8, perfect = 0.04, good = 0.12, minTime = 1.2 },
} :: { Rarity }

Config.RarityIndex = {} :: { [string]: number }
for i, r in ipairs(Config.Rarities) do
	Config.RarityIndex[r.id] = i
end

-- Mutacje (losowane niezależnie od rzadkości)
Config.Mutations = {
	{ id = "Rust", name = "", chance = 0.80, mult = 1 },
	{ id = "Shiny", name = "Błyszczący", chance = 0.12, mult = 1.5 },
	{ id = "Gold", name = "Złoty", chance = 0.05, mult = 3 },
	{ id = "Diamond", name = "Diamentowy", chance = 0.02, mult = 5 },
	{ id = "Radioactive", name = "Radioaktywny", chance = 0.008, mult = 10 },
	{ id = "Rainbow", name = "Tęczowy", chance = 0.002, mult = 25 },
}

-- Rozmiary: mnożą wartość, wagę i skalę modelu
Config.Sizes = {
	{ id = "Mini", name = "Mini", chance = 0.20, mult = 0.8, scale = 0.75 },
	{ id = "Normal", name = "", chance = 0.60, mult = 1.0, scale = 1.0 },
	{ id = "Big", name = "Duży", chance = 0.15, mult = 1.5, scale = 1.3 },
	{ id = "Huge", name = "Ogromny", chance = 0.05, mult = 2.5, scale = 1.7 },
}

----------------------------------------------------------------------
-- Strefy kanału: wymagany zasięg magnesu, bazowy CPS Commona, bonus Luck
----------------------------------------------------------------------
Config.Zones = {
	{ name = "Płycizna", reach = 8, base = 1, luck = 0.0, cursedBoost = 1, color = Color3.fromRGB(120, 200, 120) },
	{ name = "Śluza", reach = 16, base = 5, luck = 0.10, cursedBoost = 1, color = Color3.fromRGB(80, 170, 220) },
	{ name = "Pod Mostem", reach = 28, base = 25, luck = 0.25, cursedBoost = 1, color = Color3.fromRGB(240, 200, 60) },
	{ name = "Głębia", reach = 45, base = 120, luck = 0.50, cursedBoost = 1, color = Color3.fromRGB(240, 120, 40) },
	{ name = "Przeklęty Ściek", reach = 70, base = 600, luck = 1.00, cursedBoost = 3, color = Color3.fromRGB(150, 40, 200) },
}

----------------------------------------------------------------------
-- Drzewko ulepszeń (ceny z symulacji tempa progresji)
----------------------------------------------------------------------
Config.Magnets = {
	{ name = "Magnes z Lodówki", pull = 10, reach = 8, cooldown = 6.0, field = 0.22, luck = 0.00, price = 0 },
	{ name = "Magnes Głośnikowy", pull = 25, reach = 12, cooldown = 5.5, field = 0.24, luck = 0.02, price = 300 },
	{ name = "Neodym N35 \"Pastylka\"", pull = 60, reach = 16, cooldown = 5.0, field = 0.26, luck = 0.05, price = 10_000 },
	{ name = "Neodym N42 \"Krążek\"", pull = 120, reach = 22, cooldown = 4.5, field = 0.28, luck = 0.08, price = 75_000 },
	{ name = "Neodym N52 Dwustronny", pull = 250, reach = 28, cooldown = 4.0, field = 0.30, luck = 0.12, price = 500_000 },
	{ name = "Elektromagnes Złomowy", pull = 500, reach = 35, cooldown = 4.0, field = 0.26, luck = 0.15, price = 4_000_000 },
	{ name = "Magnes \"Czołg\"", pull = 900, reach = 45, cooldown = 3.5, field = 0.32, luck = 0.20, price = 30_000_000 },
	{ name = "Magnes Kwantowy", pull = 1600, reach = 55, cooldown = 3.0, field = 0.34, luck = 0.30, price = 250_000_000 },
	{ name = "Czarna Dziura", pull = 3000, reach = 70, cooldown = 2.5, field = 0.36, luck = 0.45, price = 2_000_000_000 },
}

Config.Ropes = {
	{ name = "Sznurek od Snopowiązałki", durability = 100, reel = 1.00, pvpRange = 22, price = 0 },
	{ name = "Linka Nylonowa", durability = 120, reel = 1.05, pvpRange = 26, price = 1_500 },
	{ name = "Lina Wspinaczkowa", durability = 145, reel = 1.10, pvpRange = 30, price = 40_000 },
	{ name = "Stalowa Linka", durability = 175, reel = 1.15, pvpRange = 34, price = 800_000 },
	{ name = "Linka Kevlarowa", durability = 210, reel = 1.20, pvpRange = 38, price = 15_000_000 },
	{ name = "Lina Grafenowa", durability = 250, reel = 1.30, pvpRange = 44, price = 300_000_000 },
}

Config.Transports = {
	{ name = "Gołe Ręce", capacity = 1, price = 0 },
	{ name = "Reklamówka", capacity = 2, price = 200 },
	{ name = "Plecak Szkolny", capacity = 3, price = 5_000 },
	{ name = "Plecak Turystyczny", capacity = 5, price = 50_000 },
	{ name = "Wózek Sklepowy", capacity = 8, price = 600_000 },
	{ name = "Taczka", capacity = 12, price = 6_000_000 },
	{ name = "Skuter z Przyczepką", capacity = 16, price = 50_000_000 },
	{ name = "Wózek Widłowy", capacity = 24, price = 400_000_000 },
}

Config.GarageLevels = {
	{ slots = 4, price = 0 },
	{ slots = 6, price = 800 },
	{ slots = 8, price = 15_000 },
	{ slots = 10, price = 120_000 },
	{ slots = 12, price = 1_000_000 },
	{ slots = 16, price = 8_000_000 },
	{ slots = 20, price = 70_000_000 },
	{ slots = 24, price = 600_000_000 },
}

Config.Items = {
	BananaPack = { name = "Skórki od Banana x3", amount = 3, price = 500 },
	Shield = { name = "Tarcza Magnesowa", price = 25_000, duration = 8, cooldown = 45 },
}

Config.Rebirth = {
	baseCost = 5_000_000_000,
	costGrowth = 5,
	cpsBonus = 0.5, -- +50% CPS za każdy Rebirth (addytywnie)
	luckBonus = 0.10, -- +10% Luck za każdy Rebirth
}

----------------------------------------------------------------------
-- Ekonomia
----------------------------------------------------------------------
Config.Economy = {
	SellMultiplier = 15, -- sprzedaż = 15 x CPS przedmiotu
	PendingCapSeconds = 1800, -- Kasa w garażu mieści 30 min dochodu
	OfflineRate = 0.5, -- 50% CPS offline
	OfflineMaxSeconds = 7200, -- maks. 2 h offline
	NewbieProtectionSeconds = 600,
	NewbieProtectionEarnings = 5_000,
}

----------------------------------------------------------------------
-- Łowienie
----------------------------------------------------------------------
Config.Fishing = {
	BiteDelayMin = 1.5,
	BiteDelayMax = 4.0,
	HookWindow = 0.8, -- czas na klik po "KLANG!"
	PerfectCastMin = 0.86,
	PerfectCastMax = 0.98,
	PerfectCastLuck = 0.10,
	BaseGain = 0.14, -- postęp / s w polu (przy pull == weight)
	BaseDrain = 0.09, -- spadek postępu / s poza polem
	StartProgress = 0.25,
	FieldAccel = 3.0,
	FieldMaxSpeed = 1.2,
	TensionHoldInside = 0.30,
	TensionHoldOutside = 0.45,
	TensionRelease = 0.30,
	TensionStart = 0.30,
	SweetSpotMin = 0.40,
	SweetSpotMax = 0.70,
	SweetSpotBonus = 1.25,
	HookableRatio = 0.5, -- da się zaczepić, gdy pull >= 0.5 * waga
	Timeout = 90,
	NewPlayerEpicPity = 25, -- gwarantowany Epic w pierwszych N rzutach
	SecretPity = 500, -- twarde pity: Secret najpóźniej co N rzutów
}

----------------------------------------------------------------------
-- PvP: kradzież i przeciąganie liny
----------------------------------------------------------------------
Config.Steal = {
	AimTolerance = 10, -- studs od punktu celowania
	MissCooldown = 1.5,
	FailCooldown = 6,
	DefenderGrace = 3,
	BeatInterval = 0.6,
	MaxBeats = 12,
	WinThreshold = 40,
	ShiftPerBeat = 12,
	DefenderBonus = 1.15,
	RevengeBonus = 1.25,
	RevengeSeconds = 90,
	MinForceRatio = 0.5,
	PerfectWindow = 0.08,
	GoodWindow = 0.18,
	PerfectMult = 1.5,
	GoodMult = 1.0,
	MissMult = 0.25,
	TugSpeedMult = 0.35,
	RopeSnapRangeMult = 1.6,
}

Config.Hazards = {
	MaxBananas = 3,
	BananaLifetime = 60,
	SlipSeconds = 1.5,
	GroundLootLifetime = 60,
	SinkChance = 0.5,
	SunkLootLifetime = 90,
	SunkLootRadius = 25,
}

Config.Movement = {
	BaseSpeed = 18,
	PerItemPenalty = 0.03,
	MinSpeedFactor = 0.6,
	HandItemFactor = 0.8,
}

Config.Events = {
	StormFirstDelay = 300,
	StormEvery = 600,
	StormDuration = 90,
	StormLuck = 2,
}

----------------------------------------------------------------------
-- Układ mapy (studs). Mapa jest budowana kodem przy starcie serwera.
----------------------------------------------------------------------
Config.Layout = {
	PlotCount = 8,
	PlotStartX = -210,
	PlotSpacing = 60,
	PlotCenterZ = -112,
	PlotSizeX = 50,
	PlotSizeZ = 44,
	DrivewayDepth = 6,
	CanalMinX = -260,
	CanalMaxX = 260,
	CanalStartZ = 0,
	ZoneLength = 47,
	PierXs = { -140, 0, 140 },
	PierWidth = 10,
	WaterY = -0.5,
	FloorY = -14,
	MapHalfWidth = 280,
	StreetMinZ = -150,
}

-- Dźwięki: wbudowane pliki Robloxa; podmień na własne asset ID
Config.Sounds = {
	Cast = "rbxasset://sounds/swoosh.wav",
	Clank = "rbxasset://sounds/clickfast.wav",
	Catch = "rbxasset://sounds/electronicpingshort.wav",
	Snap = "rbxasset://sounds/snap.wav",
	Alert = "rbxasset://sounds/victory.wav",
	Steal = "rbxasset://sounds/swoosh.wav",
	Splash = "rbxasset://sounds/impact_water.mp3",
	Slip = "rbxasset://sounds/splat.wav",
	Buy = "rbxasset://sounds/button.wav",
}

return Config
