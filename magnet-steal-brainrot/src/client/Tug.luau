-- UI przeciągania liny. Klikaj, gdy zmniejszający się pierścień dotknie
-- środka (takt co 0,6 s). Serwer ocenia każde kliknięcie i przesuwa linę.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local UI = require(script.Parent.UI)
local Effects = require(script.Parent.Effects)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local S = Config.Steal

local Tug = {}

local gui: { [string]: any } = {}
local active: any = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function build()
	local root = UI.root()
	gui.panel = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.62, 0),
		Size = UDim2.new(0, 560, 0, 300),
		BackgroundColor3 = Color3.fromRGB(25, 15, 15),
		BackgroundTransparency = 0.1,
		Visible = false,
		ZIndex = 31,
		Parent = root,
	}, { UI.corner(16), UI.stroke(4, Color3.fromRGB(255, 70, 70)) })
	gui.title = UI.label({
		Position = UDim2.new(0, 16, 0, 8),
		Size = UDim2.new(1, -32, 0, 34),
		ZIndex = 32,
		Text = "PRZECIĄGANIE LINY!",
		TextColor3 = Color3.fromRGB(255, 90, 90),
		Parent = gui.panel,
	})
	gui.sub = UI.label({
		Position = UDim2.new(0, 16, 0, 42),
		Size = UDim2.new(1, -32, 0, 22),
		ZIndex = 32,
		Text = "",
		Parent = gui.panel,
	})
	gui.rope = UI.make("Frame", {
		Position = UDim2.new(0, 30, 0, 76),
		Size = UDim2.new(1, -60, 0, 26),
		BackgroundColor3 = Color3.fromRGB(120, 90, 60),
		ZIndex = 32,
		Parent = gui.panel,
	}, { UI.corner(8), UI.stroke(2) })
	UI.label({
		Position = UDim2.new(0, -26, 0, 0),
		Size = UDim2.new(0, 24, 1, 0),
		ZIndex = 33,
		Text = "TY",
		TextColor3 = Color3.fromRGB(120, 255, 140),
		Parent = gui.rope,
	})
	gui.marker = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 16, 1.8, 0),
		BackgroundColor3 = Color3.fromRGB(255, 60, 60),
		ZIndex = 34,
		Parent = gui.rope,
	}, { UI.corner(4) })

	gui.target = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 185),
		Size = UDim2.new(0, 80, 0, 80),
		BackgroundColor3 = Color3.fromRGB(255, 200, 60),
		BackgroundTransparency = 0.3,
		ZIndex = 32,
		Parent = gui.panel,
	}, { UI.corner(40) })
	gui.ring = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 185),
		Size = UDim2.new(0, 200, 0, 200),
		BackgroundTransparency = 1,
		ZIndex = 33,
		Parent = gui.panel,
	}, { UI.corner(100), UI.stroke(4, Color3.new(1, 1, 1)) })
	gui.judge = UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 185),
		Size = UDim2.new(0, 200, 0, 40),
		ZIndex = 35,
		Text = "",
		Parent = gui.panel,
	})
	gui.hint = UI.label({
		Position = UDim2.new(0, 16, 1, -34),
		Size = UDim2.new(1, -150, 0, 26),
		ZIndex = 32,
		TextColor3 = Color3.fromRGB(220, 220, 220),
		Text = "Klik / Spacja, gdy pierścień dotknie środka!",
		Parent = gui.panel,
	})
	-- Duży przycisk dla dotyku (pełnoekranowy łapacz blokowałby gałkę ruchu)
	gui.tapButton = UI.button("SZARP!", Color3.fromRGB(220, 50, 50), {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.new(0, 120, 0, 90),
		ZIndex = 36,
		Parent = gui.panel,
	})
end

local function close()
	if active and active.conn then
		active.conn:Disconnect()
	end
	active = nil
	gui.panel.Visible = false
	ContextActionService:UnbindAction("MSB_Tug")
end

local function tap()
	local a = active
	if not a or a.over then
		return
	end
	local t = now()
	local beat = math.floor((t - a.firstBeat) / a.interval + 0.5) + 1
	if beat < 1 or beat > a.maxBeats or a.tapped[beat] then
		return
	end
	a.tapped[beat] = true
	local offset = t - (a.firstBeat + (beat - 1) * a.interval)
	Remotes.TugTap:FireServer(a.id, beat, offset)
	Effects.play("Clank", 0.4, 1.6)
end

local function judgeText(mult: number): (string, Color3)
	if mult >= S.PerfectMult then
		return "PERFECT!", Color3.fromRGB(120, 255, 140)
	elseif mult >= S.GoodMult then
		return "Dobrze", Color3.fromRGB(255, 220, 80)
	end
	return "Pudło", Color3.fromRGB(255, 110, 110)
end

local function render()
	local a = active
	if not a then
		return
	end
	local t = now()
	if t < a.firstBeat then
		gui.judge.Text = tostring(math.ceil(a.firstBeat - t))
		gui.judge.TextColor3 = Color3.new(1, 1, 1)
	end
	-- Pierścień: maleje od 200 px do 80 px dokładnie w chwili taktu
	local phase = ((t - a.firstBeat) / a.interval) % 1
	local size = 80 + 120 * (1 - phase)
	gui.ring.Size = UDim2.new(0, size, 0, size)
	-- Pozycja liny z perspektywy gracza: wygrywasz, gdy znacznik idzie w lewo
	local mine = if a.role == "attacker" then a.pos else -a.pos
	gui.marker.Position = UDim2.new(math.clamp(0.5 - mine / (2 * a.threshold), 0, 1), 0, 0.5, 0)
end

function Tug.start(data: { [string]: any })
	if active then
		close()
	end
	active = {
		id = data.id,
		role = data.role,
		firstBeat = data.firstBeat,
		interval = data.interval,
		maxBeats = data.maxBeats,
		threshold = data.threshold,
		pos = 0,
		tapped = {},
		over = false,
		conn = nil,
	}
	local rarity = Config.Rarities[data.rarity] or Config.Rarities[1]
	if data.role == "attacker" then
		gui.title.Text = "KRADNIESZ!"
		gui.sub.Text = "Wyrywasz " .. data.itemName .. " graczowi " .. data.opponent
	else
		gui.title.Text = "KTOŚ CIĘ OKRADA!"
		gui.sub.Text = data.opponent .. " chce wyrwać: " .. data.itemName .. " · uciekaj do garażu albo trzymaj!"
	end
	gui.sub.TextColor3 = rarity.color
	gui.judge.Text = ""
	gui.panel.Visible = true
	Effects.play("Steal", 0.8)
	Effects.shake(2, 0.4)
	UI.flash(Color3.fromRGB(255, 60, 60), 0.35)
	ContextActionService:BindActionAtPriority("MSB_Tug", function(_, state)
		if state == Enum.UserInputState.Begin then
			tap()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2)
	active.conn = RunService.RenderStepped:Connect(render)
end

function Tug.update(data: { [string]: any })
	local a = active
	if not a or a.id ~= data.id then
		return
	end
	a.pos = data.pos
	local mine = if a.role == "attacker" then data.ja else data.jd
	local text, color = judgeText(mine)
	gui.judge.Text = text
	gui.judge.TextColor3 = color
end

function Tug.finish(data: { [string]: any })
	local a = active
	if not a or a.id ~= data.id then
		return
	end
	a.over = true
	gui.judge.Text = if data.won then "WYGRANA!" else "PRZEGRANA!"
	gui.judge.TextColor3 = if data.won then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 90, 90)
	if data.won then
		Effects.play("Catch", 0.8)
	else
		Effects.play("Snap", 0.8)
	end
	task.delay(1.4, function()
		if active == a then
			close()
		end
	end)
end

function Tug.isActive(): boolean
	return active ~= nil
end

function Tug.init()
	build()
	gui.tapButton.MouseButton1Down:Connect(tap)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			tap()
		end
	end)
	Remotes.TugStart.OnClientEvent:Connect(Tug.start)
	Remotes.TugUpdate.OnClientEvent:Connect(Tug.update)
	Remotes.TugEnd.OnClientEvent:Connect(Tug.finish)
end

return Tug
