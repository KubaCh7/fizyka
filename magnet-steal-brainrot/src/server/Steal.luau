-- Kradzież: rzut magnesem w niosącego łup gracza rozpoczyna przeciąganie
-- liny (Tug-of-War). Co takt (0,6 s) obie strony klikają w rytm; serwer
-- liczy przesunięcie liny z siły magnesu i oceny trafienia w takt.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Loot = require(Shared.Loot)
local Geo = require(Shared.Geo)

local Session = require(script.Parent.Session)
local Models = require(script.Parent.Models)
local Inventory = require(script.Parent.Inventory)
local Hazards = require(script.Parent.Hazards)
local Fishing = require(script.Parent.Fishing)
local Net = require(script.Parent.Net)

local S = Config.Steal
local Steal = {}

type Tug = {
	id: string,
	attacker: Player,
	defender: Player,
	itemUid: string,
	itemName: string,
	rarity: number,
	pos: number,
	firstBeat: number,
	judgements: { [Player]: { [number]: number } },
	beam: Beam?,
	attachment: Attachment?,
	over: boolean,
}

local tugs: { [string]: Tug } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function force(s: Session.State): number
	return math.sqrt(Config.Magnets[s.data.magnet].pull)
end

local function canBeTargeted(s: Session.State, pos: Vector3): boolean
	if #s.carried == 0 or s.tug then
		return false
	end
	if Geo.isSafe(pos) or Session.isProtected(s) or Hazards.isShielded(s) then
		return false
	end
	return os.clock() >= s.graceUntil
end

local function cleanupVisual(t: Tug)
	if t.beam then
		t.beam:Destroy()
	end
	if t.attachment then
		t.attachment:Destroy()
	end
end

local function endTug(t: Tug, attackerWins: boolean, reason: string)
	if t.over then
		return
	end
	t.over = true
	tugs[t.id] = nil
	cleanupVisual(t)

	local sa = Session.get(t.attacker)
	local sd = Session.get(t.defender)
	if sa then
		sa.tug = nil
	end
	if sd then
		sd.tug = nil
	end

	local winner, loser = t.defender, t.attacker
	if attackerWins and sa and sd then
		winner, loser = t.attacker, t.defender
		local item = Inventory.remove(sd, t.itemUid)
		if item then
			if not Inventory.add(sa, item) then
				local root = Inventory.rootOf(t.attacker)
				if root then
					Hazards.scatter(item, root.Position)
				end
			end
			sd.revenge[t.attacker.UserId] = os.clock() + S.RevengeSeconds
			Net.notify(t.defender, t.attacker.DisplayName .. " wyrwał ci " .. t.itemName .. "! Zemsta aktywna przez " .. S.RevengeSeconds .. " s", "bad")
			Net.notify(t.attacker, "Ukradziono: " .. t.itemName .. "! Uciekaj do garażu!", "good")
			if t.rarity >= Config.RarityIndex.Epic then
				Net.alert({
					kind = "steal",
					rarity = t.rarity,
					player = t.attacker.DisplayName,
					victim = t.defender.DisplayName,
					itemName = t.itemName,
				})
			end
		end
	else
		if sa then
			Session.setCooldown(sa, "steal", S.FailCooldown)
		end
		if sd then
			sd.graceUntil = os.clock() + S.DefenderGrace
		end
		Net.notify(t.defender, "Obroniłeś łup!", "good")
		Net.notify(t.attacker, if reason == "safe" then "Uciekł do garażu!" else "Kradzież nieudana - magnes przegrzany", "bad")
	end

	-- Przegrany dostaje szarpnięcie w stronę zwycięzcy (czasem prosto do kanału)
	local wr, lr = Inventory.rootOf(winner), Inventory.rootOf(loser)
	if wr and lr then
		local dir = (wr.Position - lr.Position) * Vector3.new(1, 0, 1)
		if dir.Magnitude > 0.1 then
			Net.event("Ragdoll"):FireClient(loser, 0.8, dir.Unit * 45 + Vector3.new(0, 30, 0))
		end
	end

	for _, p in ipairs({ t.attacker, t.defender }) do
		local ps = Session.get(p)
		if ps then
			Inventory.updateSpeed(ps)
			Session.sync(ps)
		end
		if p.Parent then
			Net.event("TugEnd"):FireClient(p, { id = t.id, attackerWins = attackerWins, won = p == winner, reason = reason })
		end
	end
end

local function judge(offset: number?): number
	if offset == nil then
		return S.MissMult
	end
	local a = math.abs(offset)
	if a <= S.PerfectWindow then
		return S.PerfectMult
	elseif a <= S.GoodWindow then
		return S.GoodMult
	end
	return S.MissMult
end

local function runTug(t: Tug)
	local sa = Session.get(t.attacker)
	local sd = Session.get(t.defender)
	if not sa or not sd then
		endTug(t, false, "left")
		return
	end
	local fa = force(sa)
	local fd = force(sd) * S.DefenderBonus
	local revenge = sa.revenge[t.defender.UserId]
	if revenge and os.clock() < revenge then
		fa *= S.RevengeBonus
	end
	local top = math.max(fa, fd)
	fa = math.max(fa / top, S.MinForceRatio)
	fd = math.max(fd / top, S.MinForceRatio)
	local range = Config.Ropes[sa.data.rope].pvpRange * S.RopeSnapRangeMult

	for beat = 1, S.MaxBeats do
		-- Ocena taktu 0,25 s po jego czasie (zapas na ping)
		local evalAt = t.firstBeat + (beat - 1) * S.BeatInterval + 0.25
		while now() < evalAt and not t.over do
			task.wait(0.03)
			local ar, dr = Inventory.rootOf(t.attacker), Inventory.rootOf(t.defender)
			if not ar or not dr or not t.attacker.Parent or not t.defender.Parent then
				endTug(t, false, "left")
				return
			end
			if Geo.isSafe(dr.Position) then
				endTug(t, false, "safe")
				return
			end
			if (ar.Position - dr.Position).Magnitude > range then
				endTug(t, false, "snap")
				return
			end
		end
		if t.over then
			return
		end
		local ja = judge(t.judgements[t.attacker][beat])
		local jd = judge(t.judgements[t.defender][beat])
		t.pos += S.ShiftPerBeat * (fa * ja - fd * jd)
		for _, p in ipairs({ t.attacker, t.defender }) do
			Net.event("TugUpdate"):FireClient(p, { id = t.id, pos = t.pos, beat = beat, ja = ja, jd = jd })
		end
		if t.pos >= S.WinThreshold then
			endTug(t, true, "pulled")
			return
		elseif t.pos <= -S.WinThreshold then
			endTug(t, false, "held")
			return
		end
	end
	endTug(t, false, "timeout")
end

local function startTug(attacker: Player, sa: Session.State, defender: Player, sd: Session.State)
	local item = Inventory.top(sd) :: Loot.Item
	local rarity = Loot.rarityOf(item)
	local t: Tug = {
		id = HttpService:GenerateGUID(false),
		attacker = attacker,
		defender = defender,
		itemUid = item.uid,
		itemName = Loot.displayName(item),
		rarity = Config.RarityIndex[rarity.id],
		pos = 0,
		firstBeat = now() + 1.2,
		judgements = { [attacker] = {}, [defender] = {} },
		beam = nil,
		attachment = nil,
		over = false,
	}
	tugs[t.id] = t
	sa.tug = t
	sd.tug = t
	-- Łowiącej ofierze przerywamy minigrę (obiekt wraca na dno)
	Fishing.cancel(sd)
	Fishing.cancel(sa)
	Inventory.updateSpeed(sa)
	Inventory.updateSpeed(sd)

	-- Czerwona linka od kradnącego do przedmiotu
	local tool = Inventory.equippedTool(attacker, Inventory.ToolNames.Steal)
	local handle = tool and tool:FindFirstChild("Handle")
	local tip = handle and handle:FindFirstChild("Tip") :: Attachment?
	local model = Inventory.modelOf(sd, item.uid)
	if tip and model and model.PrimaryPart then
		local a1 = Instance.new("Attachment")
		a1.Parent = model.PrimaryPart
		t.attachment = a1
		local beam = Models.line(tip, a1, Color3.fromRGB(255, 60, 60))
		beam.Width0 = 0.25
		beam.Width1 = 0.25
		beam.CurveSize0 = 0
		beam.CurveSize1 = 0
		t.beam = beam
	end

	local payload = {
		id = t.id,
		itemName = t.itemName,
		rarity = t.rarity,
		firstBeat = t.firstBeat,
		interval = S.BeatInterval,
		maxBeats = S.MaxBeats,
		threshold = S.WinThreshold,
	}
	payload.role = "attacker"
	payload.opponent = defender.DisplayName
	Net.event("TugStart"):FireClient(attacker, table.clone(payload))
	payload.role = "defender"
	payload.opponent = attacker.DisplayName
	Net.event("TugStart"):FireClient(defender, table.clone(payload))

	task.spawn(runTug, t)
end

function Steal.onRequest(player: Player, aim: any)
	if typeof(aim) ~= "Vector3" then
		return
	end
	local sa = Session.get(player)
	local root = Inventory.rootOf(player)
	if not sa or not root then
		return
	end
	if not Inventory.isEquipped(player, Inventory.ToolNames.Steal) then
		return
	end
	if sa.tug or sa.fishing then
		return
	end
	if not Session.cooldownReady(sa, "steal") then
		Net.notify(player, "Magnes jeszcze stygnie...", "bad")
		return
	end
	if Session.isProtected(sa) then
		Net.notify(player, "Masz Ochronę Nowicjusza (L) - nie możesz jeszcze kraść", "bad")
		return
	end
	if Geo.isSafe(root.Position) then
		Net.notify(player, "W garażu nie można kraść", "bad")
		return
	end
	local range = Config.Ropes[sa.data.rope].pvpRange
	local best, bestDist = nil, S.AimTolerance
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local so = Session.get(other)
			local orr = Inventory.rootOf(other)
			if so and orr and canBeTargeted(so, orr.Position) then
				local distToAim = (orr.Position - aim).Magnitude
				local distToMe = (orr.Position - root.Position).Magnitude
				if distToAim <= bestDist and distToMe <= range then
					best, bestDist = other, distToAim
				end
			end
		end
	end
	if not best then
		Session.setCooldown(sa, "steal", S.MissCooldown)
		Net.notify(player, "Pudło! (zasięg liny: " .. range .. " studs)", "info")
		return
	end
	local sd = Session.get(best) :: Session.State
	startTug(player, sa, best, sd)
end

function Steal.onTap(player: Player, id: any, beat: any, offset: any)
	if type(id) ~= "string" or type(beat) ~= "number" or type(offset) ~= "number" then
		return
	end
	local t = tugs[id]
	if not t or t.over then
		return
	end
	local list = t.judgements[player]
	if not list then
		return
	end
	beat = math.floor(beat)
	if beat < 1 or beat > S.MaxBeats or list[beat] ~= nil then
		return -- liczy się tylko pierwszy klik w danym takcie (spam = pudło)
	end
	list[beat] = math.clamp(offset, -1, 1)
end

function Steal.forceEnd(player: Player)
	local s = Session.get(player)
	local t = s and s.tug :: Tug?
	if t then
		endTug(t, false, "left")
	end
end

return Steal
