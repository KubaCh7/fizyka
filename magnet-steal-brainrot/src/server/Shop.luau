-- Sklep: kolejne poziomy ulepszeń, przedmioty i Rebirth.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local Session = require(script.Parent.Session)
local Inventory = require(script.Parent.Inventory)
local Garage = require(script.Parent.Garage)
local Net = require(script.Parent.Net)

local Shop = {}

local TRACKS = {
	Magnet = { field = "magnet", list = Config.Magnets },
	Rope = { field = "rope", list = Config.Ropes },
	Transport = { field = "transport", list = Config.Transports },
	Garage = { field = "garage", list = Config.GarageLevels },
}

function Shop.rebirthCost(rebirths: number): number
	return Config.Rebirth.baseCost * Config.Rebirth.costGrowth ^ rebirths
end

local function pay(s: Session.State, price: number): boolean
	if s.data.cash < price then
		return false
	end
	s.data.cash -= price
	return true
end

function Shop.purchase(player: Player, category: any): (boolean, string)
	local s = Session.get(player)
	if not s or type(category) ~= "string" then
		return false, "Błąd"
	end
	local d = s.data
	local track = TRACKS[category]
	if track then
		local level = d[track.field]
		local nextEntry = track.list[level + 1]
		if not nextEntry then
			return false, "Maksymalny poziom"
		end
		if not pay(s, nextEntry.price) then
			return false, "Brakuje " .. Format.money(nextEntry.price - d.cash)
		end
		d[track.field] = level + 1
		if category == "Garage" then
			Garage.refresh(s)
		end
		Inventory.updateSpeed(s)
		Session.sync(s)
		return true, "Kupiono!"
	elseif category == "Banana" then
		local cfg = Config.Items.BananaPack
		if not pay(s, cfg.price) then
			return false, "Brakuje " .. Format.money(cfg.price - d.cash)
		end
		d.bananas += cfg.amount
		Inventory.refreshTools(s)
		Session.sync(s)
		return true, "+" .. cfg.amount .. " skórki"
	elseif category == "Shield" then
		if d.shield then
			return false, "Masz już tarczę"
		end
		if not pay(s, Config.Items.Shield.price) then
			return false, "Brakuje " .. Format.money(Config.Items.Shield.price - d.cash)
		end
		d.shield = true
		Inventory.refreshTools(s)
		Session.sync(s)
		return true, "Tarcza w ekwipunku!"
	elseif category == "Rebirth" then
		local cost = Shop.rebirthCost(d.rebirths)
		if #s.carried > 0 or s.tug or s.fishing then
			return false, "Najpierw odnieś łup do garażu"
		end
		if not pay(s, cost) then
			return false, "Rebirth kosztuje " .. Format.money(cost)
		end
		d.rebirths += 1
		d.cash = 0
		d.pending = 0
		d.magnet, d.rope, d.transport, d.garage = 1, 1, 1, 1
		d.racks = {}
		Garage.refresh(s)
		Inventory.updateSpeed(s)
		Session.sync(s)
		Net.alert({ kind = "rebirth", player = player.DisplayName, rebirths = d.rebirths })
		return true, "REBIRTH " .. d.rebirths .. "!"
	end
	return false, "Nieznany produkt"
end

return Shop
