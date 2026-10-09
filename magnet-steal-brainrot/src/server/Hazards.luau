-- Rzeczy, które produkują klipy: łup na ziemi, łup zatopiony w kanale,
-- skórki od banana, tarcza magnesowa.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Loot = require(Shared.Loot)
local Geo = require(Shared.Geo)

local Session = require(script.Parent.Session)
local Models = require(script.Parent.Models)
local Inventory = require(script.Parent.Inventory)
local Net = require(script.Parent.Net)

local Hazards = {}

local lootFolder = Instance.new("Folder")
lootFolder.Name = "Loot"
lootFolder.Parent = workspace

type Sunk = { item: Loot.Item, position: Vector3, expires: number, marker: Instance }
local sunk: { Sunk } = {}

----------------------------------------------------------------------
-- Łup na ziemi: każdy może podnieść (ProximityPrompt)
----------------------------------------------------------------------
function Hazards.spawnGroundLoot(item: Loot.Item, position: Vector3)
	local model = Models.brainrot(item)
	model:PivotTo(CFrame.new(position + Vector3.new(0, 1.5, 0)))
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	Models.label(model, item, "Wolny łup!", 80)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Podnieś"
	prompt.ObjectText = Loot.displayName(item)
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	model.Parent = lootFolder

	local taken = false
	prompt.Triggered:Connect(function(player: Player)
		if taken then
			return
		end
		local s = Session.get(player)
		if not s then
			return
		end
		if s.tug or s.fishing then
			return
		end
		if Inventory.isFull(s) then
			Net.notify(player, "Nie masz miejsca! Ulepsz transport w sklepie.", "bad")
			return
		end
		taken = true
		model:Destroy()
		Inventory.add(s, item)
		Net.notify(player, "Podniesiono: " .. Loot.displayName(item), "good")
	end)

	task.delay(Config.Hazards.GroundLootLifetime, function()
		if not taken and model.Parent then
			taken = true
			model:Destroy()
		end
	end)
end

-- Wyrzuca przedmiot obok pozycji (rozrzut 4-6 studs)
function Hazards.scatter(item: Loot.Item, around: Vector3)
	local angle = math.random() * math.pi * 2
	local r = 4 + math.random() * 2
	local pos = around + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
	if Geo.inWater(Vector3.new(pos.X, -1, pos.Z)) and not Geo.pierAt(pos) then
		Hazards.sink(item, Vector3.new(pos.X, Config.Layout.WaterY, pos.Z), nil)
		return
	end
	Hazards.spawnGroundLoot(item, Vector3.new(pos.X, math.max(around.Y - 3, 0.5), pos.Z))
end

----------------------------------------------------------------------
-- Zatopiony łup: kto pierwszy rzuci magnes w pobliżu, ten go wyłowi
----------------------------------------------------------------------
function Hazards.sink(item: Loot.Item, position: Vector3, ownerName: string?)
	local marker = Instance.new("Part")
	marker.Name = "SunkLoot"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.3, 6, 6)
	marker.CFrame = CFrame.new(position.X, Config.Layout.WaterY + 0.1, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	marker.Material = Enum.Material.Neon
	local rarity = Loot.rarityOf(item)
	marker.Color = rarity.color
	marker.Transparency = 0.4
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Rate = 12
	bubbles.Lifetime = NumberRange.new(0.6, 1.2)
	bubbles.Speed = NumberRange.new(3, 6)
	bubbles.SpreadAngle = Vector2.new(25, 25)
	bubbles.EmissionDirection = Enum.NormalId.Right
	bubbles.Size = NumberSequence.new(0.4)
	bubbles.Parent = marker
	if rarity.inHands then
		local pillar = Models.lightPillar(rarity.color)
		pillar.Anchored = true
		pillar.CFrame = CFrame.new(position + Vector3.new(0, 150, 0)) * CFrame.Angles(0, 0, math.rad(90))
		pillar.Parent = marker
	end
	marker.Parent = lootFolder

	table.insert(sunk, {
		item = item,
		position = position,
		expires = os.clock() + Config.Hazards.SunkLootLifetime,
		marker = marker,
	})
	if rarity.inHands then
		Net.alert({
			kind = "sunk",
			rarity = Config.RarityIndex[rarity.id],
			itemName = Loot.displayName(item),
			player = ownerName or "",
		})
	end
end

function Hazards.takeSunkNear(position: Vector3): Loot.Item?
	local best, bestDist = nil, Config.Hazards.SunkLootRadius
	for i, entry in ipairs(sunk) do
		local d = Vector2.new(entry.position.X - position.X, entry.position.Z - position.Z).Magnitude
		if d <= bestDist then
			best, bestDist = i, d
		end
	end
	if best then
		local entry = table.remove(sunk, best) :: Sunk
		entry.marker:Destroy()
		return entry.item
	end
	return nil
end

function Hazards.cleanup()
	local now = os.clock()
	for i = #sunk, 1, -1 do
		if now >= sunk[i].expires then
			sunk[i].marker:Destroy()
			table.remove(sunk, i)
		end
	end
end

-- Wejście do wody: każdy niesiony przedmiot tonie z szansą 50%
function Hazards.waterTick(s: Session.State, pos: Vector3)
	local wet = Geo.inWater(pos)
	if wet and not s.inWater then
		s.inWater = true
		if s.tug then
			return
		end
		local lost = 0
		for i = #s.carried, 1, -1 do
			if math.random() < Config.Hazards.SinkChance then
				local item = s.carried[i]
				table.remove(s.carried, i)
				local offset = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
				Hazards.sink(item, pos + offset, s.player.DisplayName)
				lost += 1
			end
		end
		if lost > 0 then
			Inventory.changed(s)
			Net.notify(s.player, "PLUSK! Zatonęło " .. lost .. " szt. łupu - ktoś może je wyłowić!", "bad")
		end
		Net.alert({ kind = "splash", player = s.player.DisplayName, position = pos })
	elseif not wet and s.inWater then
		s.inWater = false
	end
end

----------------------------------------------------------------------
-- Skórka od banana
----------------------------------------------------------------------
function Hazards.placeBanana(player: Player)
	local s = Session.get(player)
	local root = Inventory.rootOf(player)
	if not s or not root then
		return
	end
	if not Inventory.isEquipped(player, Inventory.ToolNames.Banana) then
		return
	end
	if s.data.bananas <= 0 then
		return
	end
	if s.bananasPlaced >= Config.Hazards.MaxBananas then
		Net.notify(player, "Maks. " .. Config.Hazards.MaxBananas .. " skórki naraz", "bad")
		return
	end
	if Geo.isSafe(root.Position) then
		Net.notify(player, "W garażu nie ma kogo trollować", "bad")
		return
	end
	s.data.bananas -= 1
	s.bananasPlaced += 1
	Inventory.refreshTools(s)
	Session.sync(s)

	local peel = Instance.new("Part")
	peel.Name = "BananaPeel"
	peel.Anchored = true
	peel.CanCollide = false
	peel.Size = Vector3.new(2.2, 0.3, 1.2)
	peel.Color = Color3.fromRGB(255, 220, 40)
	peel.Material = Enum.Material.SmoothPlastic
	peel.CFrame = CFrame.new(root.Position.X, root.Position.Y - 2.9, root.Position.Z) * CFrame.Angles(0, math.random() * 6.28, 0)
	peel.Parent = lootFolder

	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		peel:Destroy()
		s.bananasPlaced = math.max(0, s.bananasPlaced - 1)
	end

	peel.Touched:Connect(function(hit: BasePart)
		if done then
			return
		end
		local character = hit.Parent
		local victim = character and Players:GetPlayerFromCharacter(character)
		if not victim or victim == player then
			return
		end
		local vs = Session.get(victim)
		local vroot = Inventory.rootOf(victim)
		if not vs or not vroot or Session.isProtected(vs) then
			return
		end
		finish()
		Net.event("Ragdoll"):FireClient(victim, Config.Hazards.SlipSeconds, vroot.CFrame.LookVector * 30 + Vector3.new(0, 25, 0))
		local item = Inventory.topBackpack(vs) or Inventory.top(vs)
		if item and not vs.tug then
			Inventory.remove(vs, item.uid)
			Hazards.scatter(item, vroot.Position)
			Net.notify(victim, "Poślizgnąłeś się na skórce gracza " .. player.DisplayName .. "! Wypadło: " .. Loot.displayName(item), "bad")
		end
		Net.notify(player, victim.DisplayName .. " wywinął orła na twojej skórce!", "good")
		Net.alert({ kind = "slip", player = victim.DisplayName, position = vroot.Position })
	end)
	task.delay(Config.Hazards.BananaLifetime, finish)
end

----------------------------------------------------------------------
-- Tarcza magnesowa
----------------------------------------------------------------------
function Hazards.useShield(player: Player)
	local s = Session.get(player)
	local character = player.Character
	if not s or not character or not s.data.shield then
		return
	end
	if not Inventory.isEquipped(player, Inventory.ToolNames.Shield) then
		return
	end
	if not Session.cooldownReady(s, "shield") then
		Net.notify(player, "Tarcza się ładuje", "bad")
		return
	end
	local cfg = Config.Items.Shield
	Session.setCooldown(s, "shield", cfg.cooldown)
	s.shieldUntil = os.clock() + cfg.duration
	local ff = Instance.new("ForceField")
	ff.Visible = true
	ff.Parent = character
	task.delay(cfg.duration, function()
		ff:Destroy()
	end)
	Net.notify(player, "Tarcza aktywna przez " .. cfg.duration .. " s", "good")
end

function Hazards.isShielded(s: Session.State): boolean
	return os.clock() < s.shieldUntil
end

return Hazards
