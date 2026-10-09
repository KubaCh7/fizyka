-- Magnet & Steal a Brainrot - punkt startowy serwera.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local MapBuilder = require(script.MapBuilder)
MapBuilder.build()

local Net = require(script.Net)
local Session = require(script.Session)
local Inventory = require(script.Inventory)
local Garage = require(script.Garage)
local Hazards = require(script.Hazards)
local Fishing = require(script.Fishing)
local Steal = require(script.Steal)
local Shop = require(script.Shop)
local Events = require(script.Events)

Garage.init()
Events.start()

----------------------------------------------------------------------
-- Gracze
----------------------------------------------------------------------
local function onCharacter(player: Player, character: Model)
	local s = Session.get(player)
	if not s then
		return
	end
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	task.wait()
	if s.plot then
		character:PivotTo(Garage.spawnCFrame(s.plot))
	end
	s.inWater = false
	Inventory.refreshTools(s)
	Inventory.changed(s)

	humanoid.Died:Connect(function()
		Steal.forceEnd(player)
		Fishing.cancel(s)
		-- Śmierć w Lawless Zone = łup zostaje na ziemi dla innych
		for _, item in ipairs(Inventory.takeAll(s)) do
			Hazards.scatter(item, root.Position)
		end
	end)
end

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Kasa"
	cash.Parent = leaderstats
	local cps = Instance.new("StringValue")
	cps.Name = "CPS"
	cps.Parent = leaderstats
	leaderstats.Parent = player

	local s = Session.create(player)
	if not player.Parent then
		Session.remove(player)
		return
	end
	if not Garage.assign(s) then
		player:Kick("Brak wolnych garaży na tym serwerze")
		return
	end
	Session.sync(s)
	Net.event("IndexUpdate"):FireClient(player, s.data.index)
	if s.offlineEarned >= 1 then
		Net.notify(player, "Dochód offline czeka w Kasie: " .. Format.money(s.offlineEarned), "good")
	end
	if not s.saveEnabled then
		Net.notify(player, "Uwaga: zapis postępu wyłączony (brak dostępu do DataStore)", "bad")
	end

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local s = Session.get(player)
	if s then
		Steal.forceEnd(player)
		Fishing.cancel(s)
		-- Wyjście z łupem w rękach = łup zostaje na mapie (anty rage-quit)
		local root = Inventory.rootOf(player)
		for _, item in ipairs(s.carried) do
			if root then
				Hazards.scatter(item, root.Position)
			end
		end
		s.carried = {}
		Garage.release(s)
	end
	Session.remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	for player in pairs(Session.all()) do
		Session.save(player)
	end
end)

----------------------------------------------------------------------
-- Zdarzenia sieciowe
----------------------------------------------------------------------
Net.event("CastRequest").OnServerEvent:Connect(Fishing.onCast)
Net.event("FishResult").OnServerEvent:Connect(Fishing.onResult)
Net.event("StealRequest").OnServerEvent:Connect(Steal.onRequest)
Net.event("TugTap").OnServerEvent:Connect(Steal.onTap)
Net.event("PlaceBanana").OnServerEvent:Connect(Hazards.placeBanana)
Net.event("UseShield").OnServerEvent:Connect(Hazards.useShield)

Net.func("Purchase").OnServerInvoke = function(player, category)
	local ok, msg = Shop.purchase(player, category)
	return ok, msg
end

Net.event("DevCheat").OnServerEvent:Connect(function(player)
	if not (RunService:IsStudio() and Config.Debug.StudioCheats) then
		return
	end
	local s = Session.get(player)
	if s then
		Session.addCash(s, math.max(1_000_000, s.data.cash * 9))
		Session.sync(s)
	end
end)

----------------------------------------------------------------------
-- Pętle świata
----------------------------------------------------------------------
local fastAcc, slowAcc, saveAcc = 0, 0, 0
RunService.Heartbeat:Connect(function(dt)
	fastAcc += dt
	slowAcc += dt
	saveAcc += dt

	if fastAcc >= 0.2 then
		fastAcc = 0
		for player, s in pairs(Session.all()) do
			if s.loaded then
				local root = Inventory.rootOf(player)
				if root then
					Garage.positionTick(s, root.Position)
					Hazards.waterTick(s, root.Position)
				end
			end
		end
	end

	if slowAcc >= 1 then
		local step = slowAcc
		slowAcc = 0
		for _, s in pairs(Session.all()) do
			if s.loaded then
				Garage.incomeTick(s, step)
				Session.sync(s)
			end
		end
		Hazards.cleanup()
	end

	if saveAcc >= 120 then
		saveAcc = 0
		for player in pairs(Session.all()) do
			task.spawn(Session.save, player)
		end
	end
end)

print("[MSB] Serwer gotowy")
