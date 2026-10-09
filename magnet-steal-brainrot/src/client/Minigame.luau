-- Minigra łowienia: opadanie magnesu -> "KLANG!" (Hook Check) -> wyciąganie.
-- Wyciąganie: trzymaj obiekt w polu magnetycznym, pilnuj napięcia liny
-- (sweet spot 40-70% daje +25% postępu, 100% = zerwana lina) i trafiaj
-- skill-checki przy szarpnięciach.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local UI = require(script.Parent.UI)
local Effects = require(script.Parent.Effects)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local F = Config.Fishing
local BAR_W = 480
local QTE_POINTS = {
	[1] = { 0.6 },
	[2] = { 0.45, 0.75 },
	[3] = { 0.4, 0.6, 0.8 },
}

local Minigame = {}

local active: any = nil -- stan bieżącej minigry
local gui: { [string]: any } = {}

local function build()
	local root = UI.root()
	gui.catcher = UI.make("TextButton", {
		Name = "HoldCatcher",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 20,
		Parent = UI.overlay(),
	})
	gui.panel = UI.make("Frame", {
		Name = "Minigame",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.new(0, BAR_W + 40, 0, 210),
		BackgroundColor3 = Color3.fromRGB(18, 22, 30),
		BackgroundTransparency = 0.1,
		Visible = false,
		ZIndex = 21,
		Parent = root,
	}, { UI.corner(14) })
	gui.panelStroke = UI.stroke(3, Color3.new(1, 1, 1))
	gui.panelStroke.Parent = gui.panel

	gui.title = UI.label({
		Position = UDim2.new(0, 20, 0, 6),
		Size = UDim2.new(1, -40, 0, 32),
		ZIndex = 22,
		Text = "",
		Parent = gui.panel,
	})
	gui.bar = UI.make("Frame", {
		Position = UDim2.new(0, 20, 0, 44),
		Size = UDim2.new(0, BAR_W, 0, 46),
		BackgroundColor3 = Color3.fromRGB(40, 60, 50),
		ZIndex = 22,
		Parent = gui.panel,
	}, { UI.corner(8), UI.stroke(2) })
	gui.field = UI.make("Frame", {
		Size = UDim2.new(0.25, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(90, 230, 120),
		BackgroundTransparency = 0.35,
		ZIndex = 23,
		Parent = gui.bar,
	}, { UI.corner(8) })
	gui.object = UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 34, 0, 34),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "?",
		TextColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 1,
		ZIndex = 24,
		Parent = gui.bar,
	})
	UI.corner(17).Parent = gui.object

	local function meter(y: number, label: string): (Frame, Frame)
		UI.label({
			Position = UDim2.new(0, 20, 0, y),
			Size = UDim2.new(0, 90, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,
			Text = label,
			Parent = gui.panel,
		})
		local back = UI.make("Frame", {
			Position = UDim2.new(0, 115, 0, y + 2),
			Size = UDim2.new(0, BAR_W - 95, 0, 14),
			BackgroundColor3 = Color3.fromRGB(35, 35, 40),
			ZIndex = 22,
			Parent = gui.panel,
		}, { UI.corner(6) })
		local fill = UI.make("Frame", {
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(90, 230, 120),
			ZIndex = 24,
			Parent = back,
		}, { UI.corner(6) })
		return back, fill
	end
	local _, progressFill = meter(100, "Postęp")
	gui.progress = progressFill
	local tensionBack, tensionFill = meter(124, "Napięcie")
	gui.tension = tensionFill
	UI.make("Frame", {
		Position = UDim2.new(F.SweetSpotMin, 0, 0, 0),
		Size = UDim2.new(F.SweetSpotMax - F.SweetSpotMin, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.75,
		ZIndex = 23,
		Parent = tensionBack,
	})

	gui.hint = UI.label({
		Position = UDim2.new(0, 20, 0, 146),
		Size = UDim2.new(1, -40, 0, 22),
		ZIndex = 22,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Text = "",
		Parent = gui.panel,
	})
	gui.status = UI.label({
		Position = UDim2.new(0, 20, 0, 172),
		Size = UDim2.new(1, -40, 0, 28),
		ZIndex = 22,
		Text = "",
		Parent = gui.panel,
	})

	-- Skill-check (szarpnięcie)
	gui.qte = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -12),
		Size = UDim2.new(0, 380, 0, 34),
		BackgroundColor3 = Color3.fromRGB(30, 30, 35),
		Visible = false,
		ZIndex = 25,
		Parent = gui.panel,
	}, { UI.corner(8), UI.stroke(3, Color3.fromRGB(255, 200, 60)) })
	gui.qteGood = UI.make("Frame", {
		BackgroundColor3 = Color3.fromRGB(240, 200, 60),
		ZIndex = 26,
		Parent = gui.qte,
	})
	gui.qtePerfect = UI.make("Frame", {
		BackgroundColor3 = Color3.fromRGB(80, 230, 100),
		ZIndex = 27,
		Parent = gui.qte,
	})
	gui.qteNeedle = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 6, 1.3, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 28,
		Parent = gui.qte,
	})
	UI.label({
		Position = UDim2.new(0, 0, -1, -2),
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 26,
		Text = "SZARPNIĘCIE! Kliknij na zielonym!",
		TextColor3 = Color3.fromRGB(255, 220, 80),
		Parent = gui.qte,
	})
end

local function setVisible(on: boolean)
	gui.panel.Visible = on
	gui.catcher.Visible = on
	if not on then
		gui.qte.Visible = false
	end
end

local function close()
	if active and active.conn then
		active.conn:Disconnect()
	end
	active = nil
	setVisible(false)
	ContextActionService:UnbindAction("MSB_Reel")
end

local function send(success: boolean, reason: string?)
	if not active or active.sent then
		return
	end
	active.sent = true
	Remotes.FishResult:FireServer(active.token, success, reason)
end

local function finish(success: boolean, reason: string?)
	if not active or active.done then
		return
	end
	active.done = true
	send(success, reason)
	local rarity = Config.Rarities[active.params.rarity]
	if success then
		gui.status.Text = "WYŁOWIONE!"
		gui.status.TextColor3 = rarity.color
		Effects.play("Catch", 0.8)
		if active.params.rarity >= 3 then
			UI.flash(rarity.color, 0.5)
		end
	else
		gui.status.Text = if reason == "snap" then "LINA PĘKŁA!" elseif reason == "hook" then "Za późno! Magnes się odczepił" else "Uciekło..."
		gui.status.TextColor3 = Color3.fromRGB(255, 100, 100)
		Effects.play("Snap", 0.7)
	end
	local me = active
	task.delay(1.2, function()
		if active == me then
			close()
		end
	end)
end

local function startQte()
	local a = active
	local rarity = Config.Rarities[a.params.rarity]
	a.qte = {
		t = 0,
		duration = 1.1,
		center = 0.3 + math.random() * 0.55,
		perfect = rarity.perfect,
		good = rarity.good,
	}
	gui.qtePerfect.Size = UDim2.new(rarity.perfect, 0, 1, 0)
	gui.qtePerfect.Position = UDim2.new(a.qte.center - rarity.perfect / 2, 0, 0, 0)
	gui.qteGood.Size = UDim2.new(rarity.good, 0, 1, 0)
	gui.qteGood.Position = UDim2.new(a.qte.center - rarity.good / 2, 0, 0, 0)
	gui.qte.Visible = true
	a.holding = false
	Effects.play("Clank", 0.5, 1.3)
	Effects.shake(1.5, 0.3)
end

local function resolveQte(pressed: boolean)
	local a = active
	local q = a.qte
	local dist = math.abs(q.t / q.duration - q.center)
	local result
	if pressed and dist <= q.perfect / 2 then
		result = "PERFECT!"
		a.progress = math.min(1, a.progress + 0.10)
		a.tension = math.max(0, a.tension - 0.20)
	elseif pressed and dist <= q.good / 2 then
		result = "Dobrze"
		a.progress = math.min(1, a.progress + 0.03)
	else
		result = "Pudło!"
		a.progress -= 0.15
		a.tension += 0.25 * a.tMult
	end
	gui.status.Text = result
	gui.status.TextColor3 = if result == "Pudło!" then Color3.fromRGB(255, 110, 110) else Color3.fromRGB(120, 255, 140)
	a.qte = nil
	gui.qte.Visible = false
end

local function press()
	local a = active
	if not a or a.done then
		return
	end
	if a.phase == "bite" then
		a.phase = "reel"
		gui.status.Text = ""
		gui.hint.Text = "Trzymaj = pole w prawo · puść = w lewo · pilnuj napięcia!"
		return
	end
	if a.phase ~= "reel" then
		return
	end
	if a.qte then
		resolveQte(true)
		return
	end
	a.holding = true
end

local function release()
	if active then
		active.holding = false
	end
end

local function step(dt: number)
	local a = active
	if not a or a.done then
		return
	end
	local params = a.params
	local rarity = Config.Rarities[params.rarity]
	a.elapsed += dt

	if a.phase == "wait" then
		gui.status.Text = "Magnes opada" .. string.rep(".", 1 + math.floor(a.elapsed * 3) % 3)
		if a.elapsed >= params.biteDelay then
			Effects.play("Clank", 1)
			Effects.shake(2.5, 0.35)
			gui.object.BackgroundColor3 = rarity.color
			if params.tooHeavy then
				a.phase = "tease"
				gui.title.Text = "KLANG! Coś ogromnego..."
				gui.title.TextColor3 = rarity.color
				gui.status.Text = (params.teaseName or "???") .. " · " .. params.weight .. " kg"
				gui.status.TextColor3 = rarity.color
				gui.hint.Text = "Za słaby magnes: potrzebujesz " .. params.needPull .. " kg siły (masz " .. params.pull .. " kg)"
				a.done = true
				task.delay(2.5, function()
					if active == a then
						close()
					end
				end)
				return
			end
			a.phase = "bite"
			a.biteAt = a.elapsed
			gui.status.Text = "KLANG! KLIKNIJ TERAZ!"
			gui.status.TextColor3 = Color3.fromRGB(255, 220, 60)
			if params.rarity >= 3 then
				UI.flash(rarity.color, 0.35)
			end
		end
		return
	elseif a.phase == "bite" then
		if a.elapsed - a.biteAt > params.hookWindow + 0.15 then
			finish(false, "hook")
		end
		return
	elseif a.phase ~= "reel" then
		return
	end

	-- Skill-check wstrzymuje resztę minigry
	if a.qte then
		a.qte.t += dt
		gui.qteNeedle.Position = UDim2.new(math.clamp(a.qte.t / a.qte.duration, 0, 1), 0, 0.5, 0)
		if a.qte.t >= a.qte.duration then
			resolveQte(false)
		end
		return
	end

	-- Klątwa: okresowo odwrócone sterowanie
	if params.rarity == Config.RarityIndex.Cursed then
		a.curseTimer -= dt
		if a.curseTimer <= 0 then
			a.reversed = not a.reversed
			a.curseTimer = if a.reversed then 1.5 else 3 + math.random() * 2
			gui.hint.Text = if a.reversed then "KLĄTWA! ODWRÓCONE STEROWANIE!" else "Trzymaj = pole w prawo · puść = w lewo"
		end
	end

	-- Pole magnetyczne gracza
	local push = a.holding
	if a.reversed then
		push = not push
	end
	a.v = math.clamp(a.v + (if push then F.FieldAccel else -F.FieldAccel) * dt, -F.FieldMaxSpeed, F.FieldMaxSpeed)
	a.fieldPos += a.v * dt
	if a.fieldPos < 0 then
		a.fieldPos = 0
		a.v = -a.v * 0.3
	elseif a.fieldPos > 1 - a.fieldW then
		a.fieldPos = 1 - a.fieldW
		a.v = -a.v * 0.3
	end

	-- Obiekt ucieka do losowych celów, czasem z "dashem"
	a.retarget -= dt
	if a.retarget <= 0 then
		a.target = 0.05 + math.random() * 0.9
		a.retarget = rarity.retarget * (0.6 + math.random() * 0.8)
		a.dash = math.random() < 0.25
	end
	local speed = rarity.speed * (if a.dash then 2 else 1)
	local diff = a.target - a.objPos
	a.objPos += math.sign(diff) * math.min(math.abs(diff), speed * dt)

	local inside = a.objPos >= a.fieldPos and a.objPos <= a.fieldPos + a.fieldW

	if a.holding then
		a.tension += (if inside then F.TensionHoldInside else F.TensionHoldOutside) * a.tMult * dt
	else
		a.tension -= F.TensionRelease * dt
	end
	a.tension = math.clamp(a.tension, 0, 1)
	if a.tension >= 1 then
		finish(false, "snap")
		return
	end

	local sweet = a.tension >= F.SweetSpotMin and a.tension <= F.SweetSpotMax
	if inside then
		a.progress += a.gain * dt * (if sweet then F.SweetSpotBonus else 1)
	else
		a.progress -= a.drain * dt
	end

	if a.progress >= 1 then
		a.progress = 1
		finish(true)
	elseif a.progress <= 0 then
		a.progress = 0
		finish(false, "escaped")
	elseif a.nextQte <= #a.qtePoints and a.progress >= a.qtePoints[a.nextQte] then
		a.nextQte += 1
		startQte()
	end

	-- Rysowanie
	gui.field.Size = UDim2.new(a.fieldW, 0, 1, 0)
	gui.field.Position = UDim2.new(a.fieldPos, 0, 0, 0)
	gui.field.BackgroundColor3 = if inside then Color3.fromRGB(90, 230, 120) else Color3.fromRGB(200, 200, 200)
	gui.object.Position = UDim2.new(a.objPos, 0, 0.5, 0)
	gui.progress.Size = UDim2.new(a.progress, 0, 1, 0)
	gui.tension.Size = UDim2.new(a.tension, 0, 1, 0)
	gui.tension.BackgroundColor3 = if a.tension > 0.85
		then Color3.fromRGB(255, 70, 70)
		elseif sweet then Color3.fromRGB(90, 230, 120)
		else Color3.fromRGB(240, 200, 60)
end

function Minigame.isActive(): boolean
	return active ~= nil
end

function Minigame.start(params: { [string]: any })
	if params.cancel then
		if active then
			gui.status.Text = "Przerwano!"
			gui.status.TextColor3 = Color3.fromRGB(255, 100, 100)
			active.done = true
			active.sent = true
			local me = active
			task.delay(1, function()
				if active == me then
					close()
				end
			end)
		end
		return
	end
	if active then
		close()
	end
	local rarity = Config.Rarities[params.rarity]
	local gainRatio = math.clamp(math.sqrt(params.pull / math.max(params.weight, 1)), 0.6, 1.6)
	active = {
		token = params.token,
		params = params,
		phase = "wait",
		elapsed = 0,
		biteAt = 0,
		holding = false,
		reversed = false,
		curseTimer = 2,
		v = 0,
		fieldW = if params.rarity == 1 and (player:GetAttribute("Magnet") or 1) == 1 then 0.32 else params.field,
		fieldPos = 0.35,
		objPos = 0.5,
		target = 0.5,
		retarget = 0.5,
		dash = false,
		progress = F.StartProgress,
		tension = F.TensionStart,
		gain = F.BaseGain * gainRatio * params.reel,
		drain = F.BaseDrain * rarity.drain,
		tMult = (100 / params.durability) * (if params.weight > params.pull then 1.2 else 1),
		qtePoints = QTE_POINTS[rarity.qte] or {},
		nextQte = 1,
		qte = nil,
		done = false,
		sent = false,
		conn = nil,
	}
	gui.title.Text = "Wyciąganie: ??? " .. (if params.perfectCast then "· PERFECT CAST!" else "")
	gui.title.TextColor3 = Color3.new(1, 1, 1)
	gui.panelStroke.Color = Color3.new(1, 1, 1)
	gui.object.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
	gui.status.Text = ""
	gui.hint.Text = "Czekaj na KLANG!, potem kliknij / dotknij"
	gui.progress.Size = UDim2.new(active.progress, 0, 1, 0)
	gui.tension.Size = UDim2.new(active.tension, 0, 1, 0)
	setVisible(true)
	Effects.play("Cast", 0.6)

	ContextActionService:BindActionAtPriority("MSB_Reel", function(_, state)
		if state == Enum.UserInputState.Begin then
			press()
		elseif state == Enum.UserInputState.End then
			release()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2)

	active.conn = RunService.RenderStepped:Connect(step)
	-- Tytuł z kolorem tieru pojawia się dopiero po zaczepieniu
	task.delay(params.biteDelay, function()
		if active and active.token == params.token and not params.tooHeavy then
			gui.title.Text = "Wyciąganie: " .. string.upper(rarity.id) .. (if params.perfectCast then " · PERFECT CAST!" else "")
			gui.title.TextColor3 = rarity.color
			gui.panelStroke.Color = rarity.color
		end
	end)
end

function Minigame.init()
	build()
	gui.catcher.MouseButton1Down:Connect(press)
	gui.catcher.MouseButton1Up:Connect(release)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			release()
		end
	end)
	Remotes.FishStart.OnClientEvent:Connect(Minigame.start)
end

return Minigame
