-- Niesione przedmioty (plecak + ręce), ich wizualizacja na postaci,
-- prędkość ruchu i narzędzia gracza. Jedyne miejsce, które modyfikuje
-- listę session.carried.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Loot = require(Shared.Loot)

local Session = require(script.Parent.Session)
local Models = require(script.Parent.Models)

local Inventory = {}

local TOOL_FISH = "Wędka Magnetyczna"
local TOOL_STEAL = "Hak do Kradzieży"
local TOOL_BANANA = "Skórka od Banana"
local TOOL_SHIELD = "Tarcza Magnesowa"
Inventory.ToolNames = {
	Fish = TOOL_FISH,
	Steal = TOOL_STEAL,
	Banana = TOOL_BANANA,
	Shield = TOOL_SHIELD,
}

local function torsoOf(character: Model): BasePart?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return torso
	end
	return nil
end

function Inventory.rootOf(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Inventory.isFull(s: Session.State): boolean
	return #s.carried >= Session.capacity(s)
end

-- Przedmiot z rąk (Secret+) ma priorytet jako cel kradzieży
function Inventory.handItem(s: Session.State): Loot.Item?
	for _, item in ipairs(s.carried) do
		if Loot.rarityOf(item).inHands then
			return item
		end
	end
	return nil
end

function Inventory.top(s: Session.State): Loot.Item?
	return Inventory.handItem(s) or s.carried[#s.carried]
end

function Inventory.topBackpack(s: Session.State): Loot.Item?
	local hand = Inventory.handItem(s)
	for i = #s.carried, 1, -1 do
		if s.carried[i] ~= hand then
			return s.carried[i]
		end
	end
	return nil
end

local function clearVisuals(s: Session.State)
	for _, model in pairs(s.carriedModels) do
		model:Destroy()
	end
	table.clear(s.carriedModels)
	if s.pillar then
		s.pillar:Destroy()
		s.pillar = nil
	end
end

function Inventory.rebuildVisuals(s: Session.State)
	clearVisuals(s)
	local character = s.player.Character
	if not character then
		return
	end
	local torso = torsoOf(character)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not torso or not root then
		return
	end

	local hand = Inventory.handItem(s)
	local stackIndex = 0
	for _, item in ipairs(s.carried) do
		local model = Models.brainrot(item)
		local body = model.PrimaryPart :: BasePart
		if item == hand then
			model:ScaleTo(model:GetScale() * 0.8)
			model:PivotTo(root.CFrame * CFrame.new(0, 0.5, -2.6))
			Models.label(model, item, nil, 120)
		else
			model:ScaleTo(model:GetScale() * 0.5)
			model:PivotTo(torso.CFrame * CFrame.new(0, 0.2 + stackIndex * 1.5, 1.6))
			stackIndex += 1
		end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.Massless = true
				d.CanCollide = false
			end
		end
		local w = Instance.new("WeldConstraint")
		w.Part0 = if item == hand then root else torso
		w.Part1 = body
		w.Parent = body
		model.Parent = character
		s.carriedModels[item.uid] = model
	end

	if hand then
		local rarity = Loot.rarityOf(hand)
		local pillar = Models.lightPillar(rarity.color)
		pillar.CFrame = CFrame.new(root.Position + Vector3.new(0, 152, 0)) * CFrame.Angles(0, 0, math.rad(90))
		pillar.Anchored = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = pillar
		w.Parent = pillar
		pillar.Parent = character
		s.pillar = pillar
	end
end

function Inventory.updateSpeed(s: Session.State)
	local character = s.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local m = Config.Movement
	local speed = m.BaseSpeed * math.max(m.MinSpeedFactor, 1 - m.PerItemPenalty * #s.carried)
	if Inventory.handItem(s) then
		speed *= m.HandItemFactor
	end
	if s.tug then
		speed *= Config.Steal.TugSpeedMult
	end
	if s.fishing then
		speed = 0
	end
	humanoid.WalkSpeed = speed
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = if s.fishing then 0 else 7.2
end

function Inventory.changed(s: Session.State)
	Inventory.rebuildVisuals(s)
	Inventory.updateSpeed(s)
	Session.sync(s)
end

-- Zwraca false, gdy brak miejsca
function Inventory.add(s: Session.State, item: Loot.Item): boolean
	if Inventory.isFull(s) then
		return false
	end
	table.insert(s.carried, item)
	Inventory.changed(s)
	return true
end

function Inventory.remove(s: Session.State, uid: string): Loot.Item?
	for i, item in ipairs(s.carried) do
		if item.uid == uid then
			table.remove(s.carried, i)
			Inventory.changed(s)
			return item
		end
	end
	return nil
end

function Inventory.takeAll(s: Session.State): { Loot.Item }
	local items = s.carried
	s.carried = {}
	Inventory.changed(s)
	return items
end

function Inventory.modelOf(s: Session.State, uid: string): Model?
	return s.carriedModels[uid]
end

----------------------------------------------------------------------
-- Narzędzia
----------------------------------------------------------------------
local function findTool(player: Player, name: string): Tool?
	local backpack = player:FindFirstChildOfClass("Backpack")
	local inBackpack = backpack and backpack:FindFirstChild(name)
	if inBackpack and inBackpack:IsA("Tool") then
		return inBackpack
	end
	local character = player.Character
	local equipped = character and character:FindFirstChild(name)
	if equipped and equipped:IsA("Tool") then
		return equipped
	end
	return nil
end

function Inventory.isEquipped(player: Player, name: string): boolean
	local character = player.Character
	local tool = character and character:FindFirstChild(name)
	return tool ~= nil and tool:IsA("Tool")
end

function Inventory.equippedTool(player: Player, name: string): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChild(name)
	if tool and tool:IsA("Tool") then
		return tool
	end
	return nil
end

function Inventory.refreshTools(s: Session.State)
	local player = s.player
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack or not player.Character then
		return
	end
	if not findTool(player, TOOL_FISH) then
		Models.tool(TOOL_FISH, Color3.fromRGB(200, 40, 40), "Przytrzymaj i puść nad kanałem").Parent = backpack
	end
	if not findTool(player, TOOL_STEAL) then
		Models.tool(TOOL_STEAL, Color3.fromRGB(40, 90, 220), "Kliknij gracza niosącego łup").Parent = backpack
	end
	local banana = findTool(player, TOOL_BANANA)
	if s.data.bananas > 0 then
		if not banana then
			banana = Models.tool(TOOL_BANANA, Color3.fromRGB(255, 220, 40), "Połóż pułapkę pod nogami")
			banana.Parent = backpack
		end
		(banana :: Tool).ToolTip = "Skórki: " .. s.data.bananas
	elseif banana then
		banana:Destroy()
	end
	if s.data.shield and not findTool(player, TOOL_SHIELD) then
		Models.tool(TOOL_SHIELD, Color3.fromRGB(60, 220, 255), "8 s odporności na kradzież").Parent = backpack
	end
end

return Inventory
