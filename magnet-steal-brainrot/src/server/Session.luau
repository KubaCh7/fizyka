-- Stan gracza: zapisywane dane (DataStore) + stan sesji (niesione przedmioty,
-- łowienie, przeciąganie liny, cooldowny). Serwer jest jedynym źródłem prawdy.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Loot = require(Shared.Loot)

local Session = {}

export type Data = {
	cash: number,
	totalEarned: number,
	magnet: number,
	rope: number,
	transport: number,
	garage: number,
	rebirths: number,
	bananas: number,
	shield: boolean,
	racks: { [string]: Loot.Item },
	index: { [string]: boolean },
	casts: number,
	castsSinceSecret: number,
	hadEpic: boolean,
	newbieDone: boolean,
	pending: number,
	lastOnline: number,
}

export type State = {
	player: Player,
	data: Data,
	loaded: boolean,
	saveEnabled: boolean,
	plot: number?,
	carried: { Loot.Item },
	carriedModels: { [string]: Model },
	pillar: BasePart?,
	fishing: any?,
	tug: any?,
	cooldowns: { [string]: number },
	protectedUntil: number,
	shieldUntil: number,
	graceUntil: number,
	revenge: { [number]: number },
	inWater: boolean,
	bananasPlaced: number,
	offlineEarned: number,
}

local sessions: { [Player]: State } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[MSB] DataStore niedostępny:", result)
	end
end

local function defaultData(): Data
	return {
		cash = Config.Debug.StartCash,
		totalEarned = 0,
		magnet = 1,
		rope = 1,
		transport = 1,
		garage = 1,
		rebirths = 0,
		bananas = 3,
		shield = false,
		racks = {},
		index = {},
		casts = 0,
		castsSinceSecret = 0,
		hadEpic = false,
		newbieDone = false,
		pending = 0,
		lastOnline = os.time(),
	}
end

local function reconcile(data: any): Data
	local base = defaultData()
	if type(data) ~= "table" then
		return base
	end
	for k, v in pairs(base) do
		if data[k] == nil or type(data[k]) ~= type(v) then
			data[k] = v
		end
	end
	-- Poziomy ulepszeń zawsze w zakresie aktualnej konfiguracji
	data.magnet = math.clamp(data.magnet, 1, #Config.Magnets)
	data.rope = math.clamp(data.rope, 1, #Config.Ropes)
	data.transport = math.clamp(data.transport, 1, #Config.Transports)
	data.garage = math.clamp(data.garage, 1, #Config.GarageLevels)
	return data
end

local function canSave(): boolean
	if store == nil then
		return false
	end
	if RunService:IsStudio() and not Config.Debug.SaveInStudio then
		return false
	end
	return true
end

local function key(player: Player): string
	return "u_" .. player.UserId
end

function Session.create(player: Player): State
	local state: State = {
		player = player,
		data = defaultData(),
		loaded = false,
		saveEnabled = false,
		plot = nil,
		carried = {},
		carriedModels = {},
		pillar = nil,
		fishing = nil,
		tug = nil,
		cooldowns = {},
		protectedUntil = 0,
		shieldUntil = 0,
		graceUntil = 0,
		revenge = {},
		inWater = false,
		bananasPlaced = 0,
		offlineEarned = 0,
	}
	sessions[player] = state

	local loadedData = nil
	local ok = true
	if canSave() then
		ok = false
		for attempt = 1, 3 do
			local success, result = pcall(function()
				return (store :: DataStore):GetAsync(key(player))
			end)
			if success then
				loadedData = result
				ok = true
				break
			end
			warn("[MSB] Błąd odczytu danych (próba " .. attempt .. "):", result)
			-- Brak dostępu do API w Studio nie minie po ponowieniu
			local message = tostring(result)
			if string.find(message, "403", 1, true) or string.find(message, "Studio", 1, true) then
				break
			end
			task.wait(1)
		end
	end

	state.data = reconcile(loadedData)
	state.saveEnabled = ok and canSave()
	state.loaded = true

	-- Dochód offline: 50% CPS, maks. 2 h, trafia do Kasy w garażu
	if loadedData ~= nil then
		local away = math.clamp(os.time() - state.data.lastOnline, 0, Config.Economy.OfflineMaxSeconds)
		local offline = Session.totalCps(state) * away * Config.Economy.OfflineRate
		state.data.pending += offline
		state.offlineEarned = offline
	end

	if not state.data.newbieDone then
		state.protectedUntil = os.clock() + Config.Economy.NewbieProtectionSeconds
	end
	return state
end

function Session.get(player: Player): State?
	local s = sessions[player]
	if s and s.loaded then
		return s
	end
	return nil
end

function Session.all(): { [Player]: State }
	return sessions
end

function Session.save(player: Player)
	local s = sessions[player]
	if not s or not s.loaded or not s.saveEnabled then
		return
	end
	s.data.lastOnline = os.time()
	local data = s.data
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player), function()
			return data
		end)
	end)
	if not ok then
		warn("[MSB] Błąd zapisu danych gracza " .. player.Name .. ":", err)
	end
end

function Session.remove(player: Player)
	Session.save(player)
	sessions[player] = nil
end

function Session.totalCps(s: State): number
	local total = 0
	local slots = Config.GarageLevels[s.data.garage].slots
	for slotKey, item in pairs(s.data.racks) do
		local slot = tonumber(slotKey)
		if slot and slot <= slots then
			total += Loot.cps(item)
		end
	end
	return total * Loot.rebirthMult(s.data.rebirths)
end

function Session.capacity(s: State): number
	return Config.Transports[s.data.transport].capacity
end

function Session.isProtected(s: State): boolean
	if s.data.newbieDone then
		return false
	end
	if os.clock() >= s.protectedUntil or s.data.totalEarned >= Config.Economy.NewbieProtectionEarnings then
		s.data.newbieDone = true
		return false
	end
	return true
end

function Session.addCash(s: State, amount: number)
	s.data.cash += amount
	if amount > 0 then
		s.data.totalEarned += amount
	end
end

-- Atrybuty gracza = tanie replikowanie stanu do HUD
function Session.sync(s: State)
	local p = s.player
	local d = s.data
	p:SetAttribute("Cash", d.cash)
	p:SetAttribute("Magnet", d.magnet)
	p:SetAttribute("Rope", d.rope)
	p:SetAttribute("Transport", d.transport)
	p:SetAttribute("Garage", d.garage)
	p:SetAttribute("Rebirths", d.rebirths)
	p:SetAttribute("Bananas", d.bananas)
	p:SetAttribute("HasShield", d.shield)
	p:SetAttribute("Capacity", Session.capacity(s))
	p:SetAttribute("Carried", #s.carried)
	p:SetAttribute("CPS", Session.totalCps(s))
	p:SetAttribute("Pending", d.pending)
	p:SetAttribute("Protected", Session.isProtected(s))
	p:SetAttribute("Plot", s.plot or 0)
	p:SetAttribute("Fishing", s.fishing ~= nil)

	local ls = p:FindFirstChild("leaderstats")
	if ls then
		local cash = ls:FindFirstChild("Kasa") :: StringValue?
		local cps = ls:FindFirstChild("CPS") :: StringValue?
		local fmt = require(Shared.Format)
		if cash then
			cash.Value = fmt.money(d.cash)
		end
		if cps then
			cps.Value = fmt.money(Session.totalCps(s)) .. "/s"
		end
	end
end

function Session.cooldownReady(s: State, name: string): boolean
	return os.clock() >= (s.cooldowns[name] or 0)
end

function Session.setCooldown(s: State, name: string, seconds: number)
	s.cooldowns[name] = os.clock() + seconds
end

return Session
