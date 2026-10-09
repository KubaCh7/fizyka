--!strict
-- Czysta logika losowania i wyceny (bez API Robloxa poza Random),
-- dzięki czemu da się ją testować poza Studio.

local Config = require(script.Parent.Config)
local Brainrots = require(script.Parent.Brainrots)

export type Item = {
	uid: string,
	id: string,
	mut: string,
	size: string,
}

local Loot = {}

local mutById: { [string]: any } = {}
for _, m in ipairs(Config.Mutations) do
	mutById[m.id] = m
end
local sizeById: { [string]: any } = {}
for _, s in ipairs(Config.Sizes) do
	sizeById[s.id] = s
end

local MYTHIC_CAP = 1 / 500

-- Zwraca indeks rzadkości (1 = Common ... 6 = Mythic).
function Loot.rollRarity(rng: Random, luck: number, zone: number, forceMin: number?): number
	local zoneCfg = Config.Zones[zone]
	local chances = table.create(#Config.Rarities, 0)
	local total = 0
	for i = 2, #Config.Rarities do
		local r = Config.Rarities[i]
		local p = r.chance * luck
		if r.id == "Cursed" then
			p *= zoneCfg.cursedBoost
		elseif r.id == "Mythic" then
			p = math.min(p, MYTHIC_CAP)
		end
		chances[i] = p
		total += p
	end
	-- Przy ogromnym Luck nie pozwalamy, by Common zniknął całkiem
	if total > 0.95 then
		local scale = 0.95 / total
		for i = 2, #chances do
			chances[i] *= scale
		end
	end
	local roll = rng:NextNumber()
	local acc = 0
	local result = 1
	for i = #Config.Rarities, 2, -1 do
		acc += chances[i]
		if roll < acc then
			result = i
			break
		end
	end
	if forceMin and result < forceMin then
		result = forceMin
	end
	return result
end

local function pickWeighted(rng: Random, entries: { any }): any
	local roll = rng:NextNumber()
	local acc = 0
	for _, e in ipairs(entries) do
		acc += e.chance
		if roll < acc then
			return e
		end
	end
	return entries[1]
end

function Loot.rollMutation(rng: Random): string
	return pickWeighted(rng, Config.Mutations).id
end

function Loot.rollSize(rng: Random): string
	return pickWeighted(rng, Config.Sizes).id
end

function Loot.mutation(id: string): any
	return mutById[id] or Config.Mutations[1]
end

function Loot.size(id: string): any
	return sizeById[id] or Config.Sizes[2]
end

function Loot.rarityOf(item: Item): Config.Rarity
	local b = Brainrots.get(item.id)
	local idx = b and Config.RarityIndex[b.rarity] or 1
	return Config.Rarities[idx]
end

-- Dochód na sekundę bez mnożnika Rebirth
function Loot.cps(item: Item): number
	local b = Brainrots.get(item.id)
	if not b then
		return 0
	end
	local rarity = Config.Rarities[Config.RarityIndex[b.rarity]]
	local zone = Config.Zones[b.zone]
	return zone.base * rarity.mult * Loot.mutation(item.mut).mult * Loot.size(item.size).mult
end

function Loot.weight(item: Item): number
	local b = Brainrots.get(item.id)
	if not b then
		return 1
	end
	local rarity = Config.Rarities[Config.RarityIndex[b.rarity]]
	return b.weight * rarity.weightMult * Loot.size(item.size).mult
end

function Loot.displayName(item: Item): string
	local b = Brainrots.get(item.id)
	local name = b and b.name or item.id
	local prefix = {}
	local s = Loot.size(item.size)
	if s.name ~= "" then
		table.insert(prefix, s.name)
	end
	local m = Loot.mutation(item.mut)
	if m.name ~= "" then
		table.insert(prefix, m.name)
	end
	if #prefix > 0 then
		return table.concat(prefix, " ") .. " " .. name
	end
	return name
end

function Loot.sellValue(item: Item, rebirths: number): number
	return math.floor(Loot.cps(item) * Config.Economy.SellMultiplier * Loot.rebirthMult(rebirths))
end

function Loot.rebirthMult(rebirths: number): number
	return 1 + Config.Rebirth.cpsBonus * rebirths
end

return Loot
