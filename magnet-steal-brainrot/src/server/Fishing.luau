-- Łowienie magnesem. Serwer losuje łup w chwili rzutu (klient nie zna
-- wyniku, tylko kolor tieru do minigry), pilnuje cooldownów, zasięgu
-- magnesu, miejsca w plecaku i minimalnego czasu minigry.
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Brainrots = require(Shared.Brainrots)
local Loot = require(Shared.Loot)
local Geo = require(Shared.Geo)
local Format = require(Shared.Format)

local Session = require(script.Parent.Session)
local Models = require(script.Parent.Models)
local Inventory = require(script.Parent.Inventory)
local Hazards = require(script.Parent.Hazards)
local Events = require(script.Parent.Events)
local Net = require(script.Parent.Net)

local Fishing = {}

local rng = Random.new()
local F = Config.Fishing

type Rig = { magnet: BasePart, beam: Beam, pillar: BasePart? }
type FishState = {
	token: string,
	item: Loot.Item,
	rarity: number,
	startedAt: number,
	biteDelay: number,
	hookable: boolean,
	castPoint: Vector3,
	rig: Rig?,
}

local function buildRig(player: Player, castPoint: Vector3): Rig?
	local tool = Inventory.equippedTool(player, Inventory.ToolNames.Fish)
	local handle = tool and tool:FindFirstChild("Handle")
	local tip = handle and handle:FindFirstChild("Tip") :: Attachment?
	if not tip then
		return nil
	end
	local magnet = Models.magnetHead()
	magnet.CFrame = CFrame.new(castPoint)
	magnet.Parent = workspace
	local beam = Models.line(tip, magnet:FindFirstChild("LineAttachment") :: Attachment, Color3.fromRGB(230, 230, 230))
	-- Magnes opada pod wodę
	TweenService:Create(magnet, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.new(castPoint - Vector3.new(0, 5, 0)),
	}):Play()
	return { magnet = magnet, beam = beam, pillar = nil }
end

local function destroyRig(rig: Rig?, pullUp: boolean)
	if not rig then
		return
	end
	if pullUp then
		local tween = TweenService:Create(rig.magnet, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = rig.magnet.CFrame + Vector3.new(0, 7, 0),
		})
		tween:Play()
		tween.Completed:Wait()
	end
	rig.beam:Destroy()
	rig.magnet:Destroy()
	if rig.pillar then
		rig.pillar:Destroy()
	end
end

local function luckFor(s: Session.State, zone: number, perfectCast: boolean): number
	local magnet = Config.Magnets[s.data.magnet]
	local luck = 1
		+ magnet.luck
		+ Config.Zones[zone].luck
		+ Config.Rebirth.luckBonus * s.data.rebirths
		+ (if perfectCast then F.PerfectCastLuck else 0)
	return luck * Events.luckMultiplier() * Config.Debug.LuckMultiplier
end

local function rollItem(s: Session.State, zone: number, perfectCast: boolean): (Loot.Item, number)
	local d = s.data
	local rarityIdx: number
	if d.casts == 0 then
		rarityIdx = 1 -- onboarding: pierwszy łup zawsze Common
	elseif d.casts == 1 then
		rarityIdx = 2 -- drugi zawsze Rare (uczy skill-checku)
	else
		local forceMin = nil
		if d.castsSinceSecret + 1 >= F.SecretPity then
			forceMin = Config.RarityIndex.Secret
		elseif not d.hadEpic and d.casts + 1 >= F.NewPlayerEpicPity then
			forceMin = Config.RarityIndex.Epic
		end
		rarityIdx = Loot.rollRarity(rng, luckFor(s, zone, perfectCast), zone, forceMin)
	end
	local rarity = Config.Rarities[rarityIdx]
	local b = Brainrots.forZone(zone, rarity.id)
	local item: Loot.Item = {
		uid = HttpService:GenerateGUID(false),
		id = b.id,
		mut = if d.casts < 2 then "Rust" else Loot.rollMutation(rng),
		size = if d.casts < 2 then "Normal" else Loot.rollSize(rng),
	}
	d.casts += 1
	if rarityIdx >= Config.RarityIndex.Epic then
		d.hadEpic = true
	end
	if rarityIdx >= Config.RarityIndex.Secret then
		d.castsSinceSecret = 0
	else
		d.castsSinceSecret += 1
	end
	return item, rarityIdx
end

local function finish(s: Session.State, success: boolean, reason: string?)
	local f = s.fishing :: FishState?
	if not f then
		return
	end
	s.fishing = nil
	Session.setCooldown(s, "cast", Config.Magnets[s.data.magnet].cooldown)
	local player = s.player
	local item = f.item

	if success then
		local rarity = Config.Rarities[f.rarity]
		local isNew = not s.data.index[item.id]
		s.data.index[item.id] = true
		if not Inventory.add(s, item) then
			local root = Inventory.rootOf(player)
			if root then
				Hazards.scatter(item, root.Position)
			end
		end
		Net.notify(
			player,
			"Wyłowiono: " .. Loot.displayName(item) .. " (" .. Format.money(Loot.cps(item) * Loot.rebirthMult(s.data.rebirths)) .. "/s)",
			"good"
		)
		if isNew then
			Net.event("IndexUpdate"):FireClient(player, s.data.index)
		end
		if rarity.announce then
			Net.alert({
				kind = "catch",
				rarity = f.rarity,
				player = player.DisplayName,
				itemName = Loot.displayName(item),
				zone = Geo.zoneAtZ(f.castPoint.Z),
			})
		end
	else
		if f.hookable and reason == "cancel" then
			-- Przerwane łowienie: obiekt wraca na dno, każdy może go wyłowić
			Hazards.sink(item, f.castPoint, player.DisplayName)
		elseif f.hookable then
			Net.notify(player, if reason == "snap" then "Lina pękła! Obiekt wrócił na dno." else "Uciekło...", "bad")
		end
	end

	Inventory.updateSpeed(s)
	Session.sync(s)
	task.spawn(destroyRig, f.rig, success)
end

function Fishing.cancel(s: Session.State)
	if s.fishing then
		Net.event("FishStart"):FireClient(s.player, { cancel = true })
		finish(s, false, "cancel")
	end
end

function Fishing.onCast(player: Player, power: any)
	local s = Session.get(player)
	local root = Inventory.rootOf(player)
	if not s or not root then
		return
	end
	if s.fishing or s.tug then
		return
	end
	if not Inventory.isEquipped(player, Inventory.ToolNames.Fish) then
		return
	end
	if not Session.cooldownReady(s, "cast") then
		return
	end
	local zone = Geo.fishingZone(root.Position)
	if not zone then
		Net.notify(player, "Podejdź do brzegu kanału albo wejdź na pomost", "bad")
		return
	end
	local magnet = Config.Magnets[s.data.magnet]
	local zoneCfg = Config.Zones[zone]
	if magnet.reach < zoneCfg.reach then
		Net.notify(player, magnet.name .. " sięga " .. magnet.reach .. " m, a " .. zoneCfg.name .. " wymaga " .. zoneCfg.reach .. " m. Ulepsz magnes!", "bad")
		return
	end
	if Inventory.isFull(s) then
		Net.notify(player, "Pełny transport! Zanieś łup do garażu albo kup większy plecak.", "bad")
		return
	end

	local p = if type(power) == "number" then math.clamp(power, 0, 1) else 0.5
	local perfectCast = p >= F.PerfectCastMin and p <= F.PerfectCastMax

	local castPoint = Geo.castPoint(root.Position, root.CFrame.LookVector)
	local item = Hazards.takeSunkNear(castPoint)
	local rarityIdx: number
	local hookable = true
	if item then
		rarityIdx = Config.RarityIndex[Loot.rarityOf(item).id]
	else
		item, rarityIdx = rollItem(s, zone, perfectCast)
		hookable = magnet.pull >= Loot.weight(item) * F.HookableRatio
	end
	local rarity = Config.Rarities[rarityIdx]

	local fish: FishState = {
		token = HttpService:GenerateGUID(false),
		item = item,
		rarity = rarityIdx,
		startedAt = os.clock(),
		biteDelay = rng:NextNumber(F.BiteDelayMin, F.BiteDelayMax),
		hookable = hookable,
		castPoint = castPoint,
		rig = nil,
	}
	s.fishing = fish
	fish.rig = buildRig(player, castPoint)
	Inventory.updateSpeed(s)
	Session.sync(s)

	local rope = Config.Ropes[s.data.rope]
	Net.event("FishStart"):FireClient(player, {
		token = fish.token,
		rarity = rarityIdx,
		biteDelay = fish.biteDelay,
		hookWindow = F.HookWindow,
		tooHeavy = not hookable,
		weight = math.floor(Loot.weight(item)),
		pull = magnet.pull,
		needPull = math.ceil(Loot.weight(item) * F.HookableRatio),
		field = magnet.field,
		durability = rope.durability,
		reel = rope.reel,
		perfectCast = perfectCast,
		teaseName = if hookable then nil else (Brainrots.get(item.id) :: Brainrots.Brainrot).name,
	})

	-- Secret+ na haczyku: słup światła z wody widoczny dla wszystkich
	task.delay(fish.biteDelay, function()
		if s.fishing ~= fish or not hookable or not rarity.inHands then
			return
		end
		local pillar = Models.lightPillar(rarity.color)
		pillar.Anchored = true
		pillar.CFrame = CFrame.new(castPoint + Vector3.new(0, 150, 0)) * CFrame.Angles(0, 0, math.rad(90))
		pillar.Parent = workspace
		if fish.rig then
			fish.rig.pillar = pillar
		else
			task.delay(30, function()
				pillar:Destroy()
			end)
		end
		Net.alert({ kind = "hooked", rarity = rarityIdx, player = player.DisplayName, zone = zone })
	end)

	if not hookable then
		-- Za ciężkie: tylko pokaz sylwetki, bez minigry
		task.delay(fish.biteDelay + 2.5, function()
			if s.fishing == fish then
				finish(s, false, "tooHeavy")
			end
		end)
	end

	task.delay(F.Timeout, function()
		if s.fishing == fish then
			finish(s, false, "timeout")
		end
	end)
end

function Fishing.onResult(player: Player, token: any, success: any, reason: any)
	local s = Session.get(player)
	if not s then
		return
	end
	local f = s.fishing :: FishState?
	if not f or f.token ~= token or not f.hookable then
		return
	end
	local ok = success == true
	if ok then
		-- Walidacja: minigra nie może być krótsza niż minimum dla tieru
		local elapsed = os.clock() - f.startedAt
		local minimum = f.biteDelay + Config.Rarities[f.rarity].minTime * 0.8
		if elapsed < minimum then
			warn(("[MSB] Podejrzanie szybka minigra: %s %.2fs < %.2fs"):format(player.Name, elapsed, minimum))
			ok = false
		end
	end
	finish(s, ok, if type(reason) == "string" then reason else nil)
end

return Fishing
