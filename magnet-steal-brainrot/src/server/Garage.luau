-- Garaże: przydział działek, stojaki z Brainrotami, dochód (CPS),
-- Kasa do odbioru, auto-odkładanie łupu po wejściu do Safe Zone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Loot = require(Shared.Loot)
local Geo = require(Shared.Geo)
local Format = require(Shared.Format)

local Session = require(script.Parent.Session)
local Models = require(script.Parent.Models)
local Inventory = require(script.Parent.Inventory)
local MapBuilder = require(script.Parent.MapBuilder)
local Net = require(script.Parent.Net)

local MAX_SLOTS = 24
local Garage = {}

local owners: { [number]: Player } = {}

local function plotFolder(index: number): Folder
	return MapBuilder.plotFolder(index)
end

local function setGateText(index: number, text: string)
	local beam = plotFolder(index):FindFirstChild("GateBeam")
	if not beam then
		return
	end
	for _, gui in ipairs(beam:GetChildren()) do
		if gui:IsA("SurfaceGui") then
			local label = gui:FindFirstChildOfClass("TextLabel")
			if label then
				label.Text = text
			end
		end
	end
end

function Garage.ownerOf(index: number): Player?
	return owners[index]
end

function Garage.spawnCFrame(index: number): CFrame
	local c = Geo.plotCenter(index)
	return CFrame.new(c.X - 8, 4, c.Z + Config.Layout.PlotSizeZ / 2 - 4) * CFrame.Angles(0, math.rad(180), 0)
end

-- Odświeża wszystkie 24 stojaki działki gracza
function Garage.refresh(s: Session.State)
	local index = s.plot
	if not index then
		return
	end
	local folder = plotFolder(index)
	local items = folder:FindFirstChild("Items") :: Folder
	items:ClearAllChildren()
	local unlocked = Config.GarageLevels[s.data.garage].slots
	local pedestals = folder:FindFirstChild("Pedestals") :: Folder
	for slot = 1, MAX_SLOTS do
		local ped = pedestals:FindFirstChild("Pedestal_" .. slot) :: BasePart
		local prompt = ped:FindFirstChild("SellPrompt") :: ProximityPrompt
		local item = s.data.racks[tostring(slot)]
		if slot > unlocked then
			ped.Transparency = 0.8
			ped.Color = Color3.fromRGB(60, 60, 60)
			prompt.Enabled = false
		else
			ped.Transparency = 0
			ped.Color = if item then Loot.rarityOf(item).color else Color3.fromRGB(70, 70, 80)
			prompt.Enabled = item ~= nil
		end
		if item and slot <= unlocked then
			local model = Models.brainrot(item)
			model:PivotTo(CFrame.new(ped.Position + Vector3.new(0, 2.6 * Loot.size(item.size).scale, 0)) * CFrame.Angles(0, math.rad(180), 0))
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			Models.label(model, item, Models.cpsText(item, s.data.rebirths), 45)
			model.Parent = items
			prompt.ObjectText = Loot.displayName(item)
			prompt.ActionText = "Sprzedaj " .. Format.money(Loot.sellValue(item, s.data.rebirths))
		end
	end
end

function Garage.assign(s: Session.State): number?
	for i = 1, Config.Layout.PlotCount do
		if owners[i] == nil then
			owners[i] = s.player
			s.plot = i
			setGateText(i, "GARAŻ: " .. string.upper(s.player.DisplayName))
			Garage.refresh(s)
			return i
		end
	end
	return nil
end

function Garage.release(s: Session.State)
	local index = s.plot
	if not index then
		return
	end
	owners[index] = nil
	setGateText(index, "WOLNY GARAŻ")
	local folder = plotFolder(index)
	;(folder:FindFirstChild("Items") :: Folder):ClearAllChildren()
	local pedestals = folder:FindFirstChild("Pedestals") :: Folder
	for _, ped in ipairs(pedestals:GetChildren()) do
		local prompt = ped:FindFirstChild("SellPrompt") :: ProximityPrompt?
		if prompt then
			prompt.Enabled = false
		end
		if ped:IsA("BasePart") then
			ped.Transparency = 0
			ped.Color = Color3.fromRGB(70, 70, 80)
		end
	end
	s.plot = nil
end

local function freeSlot(s: Session.State): number?
	local unlocked = Config.GarageLevels[s.data.garage].slots
	for slot = 1, unlocked do
		if s.data.racks[tostring(slot)] == nil then
			return slot
		end
	end
	return nil
end

local function weakestSlot(s: Session.State): (number?, number)
	local unlocked = Config.GarageLevels[s.data.garage].slots
	local best, bestCps = nil, math.huge
	for slot = 1, unlocked do
		local item = s.data.racks[tostring(slot)]
		if item then
			local cps = Loot.cps(item)
			if cps < bestCps then
				best, bestCps = slot, cps
			end
		end
	end
	return best, bestCps
end

local function sellItem(s: Session.State, item: Loot.Item): number
	local value = Loot.sellValue(item, s.data.rebirths)
	Session.addCash(s, value)
	return value
end

-- Odkłada wszystkie niesione przedmioty. Gdy brak wolnych stojaków,
-- słabszy z pary (nowy vs najsłabszy na stojaku) idzie do Skupu.
function Garage.deposit(s: Session.State)
	if #s.carried == 0 then
		return
	end
	local items = Inventory.takeAll(s)
	local placed, soldTotal = 0, 0
	for _, item in ipairs(items) do
		local slot = freeSlot(s)
		if slot then
			s.data.racks[tostring(slot)] = item
			placed += 1
		else
			local weak, weakCps = weakestSlot(s)
			if weak and Loot.cps(item) > weakCps then
				local old = s.data.racks[tostring(weak)]
				s.data.racks[tostring(weak)] = item
				soldTotal += sellItem(s, old)
				placed += 1
			else
				soldTotal += sellItem(s, item)
			end
		end
	end
	Garage.refresh(s)
	Session.sync(s)
	local msg = "Zabezpieczono " .. placed .. " szt. w garażu"
	if soldTotal > 0 then
		msg ..= " · Skup: +" .. Format.money(soldTotal)
	end
	Net.notify(s.player, msg, "good")
end

function Garage.sellSlot(player: Player, slot: number)
	local s = Session.get(player)
	if not s then
		return
	end
	local item = s.data.racks[tostring(slot)]
	if not item then
		return
	end
	s.data.racks[tostring(slot)] = nil
	local value = sellItem(s, item)
	Garage.refresh(s)
	Session.sync(s)
	Net.notify(player, "Sprzedano " .. Loot.displayName(item) .. " za " .. Format.money(value), "good")
end

function Garage.collect(s: Session.State)
	if s.data.pending < 1 then
		return
	end
	local amount = math.floor(s.data.pending)
	s.data.pending -= amount
	Session.addCash(s, amount)
	Session.sync(s)
	Net.event("Alert"):FireClient(s.player, { kind = "collect", amount = amount })
end

local function updatePadLabel(s: Session.State)
	if not s.plot then
		return
	end
	local pad = plotFolder(s.plot):FindFirstChild("Pad")
	local gui = pad and pad:FindFirstChild("PadGui")
	local label = gui and gui:FindFirstChild("PadLabel") :: TextLabel?
	if label then
		label.Text = "KASA: " .. Format.money(s.data.pending)
	end
end

-- Co sekundę: dochód trafia do Kasy (z limitem 30 min dochodu)
function Garage.incomeTick(s: Session.State, dt: number)
	local cps = Session.totalCps(s)
	local cap = math.max(1000, cps * Config.Economy.PendingCapSeconds)
	s.data.pending = math.min(cap, s.data.pending + cps * dt)
	updatePadLabel(s)
end

-- Kilka razy na sekundę: wejście do garażu i na Kasę
function Garage.positionTick(s: Session.State, pos: Vector3)
	if not s.plot then
		return
	end
	local here = Geo.plotAt(pos)
	if here == s.plot then
		if #s.carried > 0 and s.tug == nil then
			Garage.deposit(s)
		end
		local pad = plotFolder(s.plot):FindFirstChild("Pad") :: BasePart?
		if pad then
			local d = Vector2.new(pos.X - pad.Position.X, pos.Z - pad.Position.Z).Magnitude
			if d < 4 then
				Garage.collect(s)
			end
		end
	end
end

function Garage.init()
	for i = 1, Config.Layout.PlotCount do
		local pedestals = plotFolder(i):WaitForChild("Pedestals")
		for _, ped in ipairs(pedestals:GetChildren()) do
			local prompt = ped:FindFirstChild("SellPrompt") :: ProximityPrompt?
			local slot = ped:GetAttribute("Slot")
			if prompt and type(slot) == "number" then
				prompt.Triggered:Connect(function(player: Player)
					if owners[i] ~= player then
						Net.notify(player, "To nie twój garaż!", "bad")
						return
					end
					Garage.sellSlot(player, slot)
				end)
			end
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		for i, p in pairs(owners) do
			if p == player then
				owners[i] = nil
			end
		end
	end)
end

return Garage
