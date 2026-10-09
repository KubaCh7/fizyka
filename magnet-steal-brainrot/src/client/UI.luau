-- HUD, powiadomienia i banery alertów. Całe UI jest tworzone kodem.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Geo = require(Shared.Geo)

local player = Players.LocalPlayer

local UI = {}

local FONT = Enum.Font.FredokaOne

function UI.make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function UI.corner(radius: number?): UICorner
	return UI.make("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function UI.stroke(thickness: number?, color: Color3?): UIStroke
	return UI.make("UIStroke", { Thickness = thickness or 2, Color = color or Color3.new(0, 0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function UI.label(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextStrokeTransparency = 0.4,
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	return UI.make("TextLabel", base)
end

function UI.button(text: string, color: Color3, props: { [string]: any }): TextButton
	local base = {
		Text = text,
		Font = FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = color,
		AutoButtonColor = true,
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	local b = UI.make("TextButton", base, { UI.corner(10), UI.stroke(2) })
	UI.make("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = b,
	})
	return b
end

local gui: ScreenGui
local overlay: ScreenGui
local refs: { [string]: any } = {}

function UI.root(): ScreenGui
	return gui
end

-- Warstwa pełnoekranowa bez UIScale (łapacz dotyku minigry, błysk ekranu)
function UI.overlay(): ScreenGui
	return overlay
end

function UI.build()
	gui = UI.make("ScreenGui", {
		Name = "MSB_HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	overlay = UI.make("ScreenGui", {
		Name = "MSB_Overlay",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- Skalowanie całego HUD na małych ekranach (telefony)
	local scale = UI.make("UIScale", { Parent = gui })
	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(vp.X / 1100, vp.Y / 650), 0.5, 1)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	-- Panel statystyk (lewy górny róg)
	local panel = UI.make("Frame", {
		Name = "Stats",
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(0, 250, 0, 168),
		BackgroundColor3 = Color3.fromRGB(20, 20, 28),
		BackgroundTransparency = 0.25,
		Parent = gui,
	}, { UI.corner(12), UI.stroke(2, Color3.fromRGB(255, 200, 60)) })
	UI.make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel })
	UI.make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingRight = UDim.new(0, 8), Parent = panel })
	local function row(name: string, order: number, color: Color3?, height: number?): TextLabel
		local l = UI.label({
			Name = name,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, height or 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color or Color3.new(1, 1, 1),
			Text = "",
			Parent = panel,
		})
		return l
	end
	refs.cash = row("Cash", 1, Color3.fromRGB(120, 255, 120), 30)
	refs.cps = row("CPS", 2, Color3.fromRGB(255, 230, 120))
	refs.pending = row("Pending", 3, Color3.fromRGB(160, 220, 255))
	refs.carried = row("Carried", 4)
	refs.magnet = row("Magnet", 5, Color3.fromRGB(255, 160, 160))
	refs.zone = row("Zone", 6)

	refs.protected = UI.label({
		Name = "Protected",
		Position = UDim2.new(0, 10, 0, 184),
		Size = UDim2.new(0, 250, 0, 26),
		BackgroundColor3 = Color3.fromRGB(40, 120, 60),
		BackgroundTransparency = 0.1,
		Text = "L · Ochrona Nowicjusza",
		Visible = false,
		Parent = gui,
	})
	UI.corner(8).Parent = refs.protected

	-- Przyciski (prawa strona)
	refs.shopButton = UI.button("SKLEP", Color3.fromRGB(255, 170, 30), {
		Position = UDim2.new(1, -140, 0.35, 0),
		Size = UDim2.new(0, 130, 0, 50),
		Parent = gui,
	})
	refs.indexButton = UI.button("INDEX", Color3.fromRGB(120, 90, 255), {
		Position = UDim2.new(1, -140, 0.35, 60),
		Size = UDim2.new(0, 130, 0, 50),
		Parent = gui,
	})
	refs.devButton = UI.button("DEV x10 $", Color3.fromRGB(200, 60, 60), {
		Position = UDim2.new(1, -140, 0.35, 120),
		Size = UDim2.new(0, 130, 0, 40),
		Visible = RunService:IsStudio() and Config.Debug.StudioCheats,
		Parent = gui,
	})

	-- Pasek siły rzutu
	refs.charge = UI.make("Frame", {
		Name = "Charge",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -120),
		Size = UDim2.new(0, 300, 0, 26),
		BackgroundColor3 = Color3.fromRGB(30, 30, 35),
		Visible = false,
		Parent = gui,
	}, { UI.corner(8), UI.stroke(2) })
	UI.make("Frame", {
		Name = "Perfect",
		Position = UDim2.new(Config.Fishing.PerfectCastMin, 0, 0, 0),
		Size = UDim2.new(Config.Fishing.PerfectCastMax - Config.Fishing.PerfectCastMin, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(60, 220, 90),
		BorderSizePixel = 0,
		Parent = refs.charge,
	})
	refs.chargeNeedle = UI.make("Frame", {
		Name = "Needle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 6, 1.4, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = refs.charge,
	}, { UI.corner(3) })
	UI.label({
		Position = UDim2.new(0, 0, -1.1, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Text = "Puść na zielonym = Perfect Cast (+10% Luck)",
		Parent = refs.charge,
	})

	-- Powiadomienia (dół ekranu)
	refs.toasts = UI.make("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.new(0, 520, 0, 150),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.make("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = refs.toasts,
	})

	-- Baner alertów (góra ekranu)
	refs.banner = UI.make("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -140),
		Size = UDim2.new(0, 620, 0, 110),
		BackgroundColor3 = Color3.fromRGB(20, 20, 25),
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, { UI.corner(16) })
	refs.bannerStroke = UI.stroke(4, Color3.new(1, 1, 1))
	refs.bannerStroke.Parent = refs.banner
	refs.bannerTitle = UI.label({
		Position = UDim2.new(0, 10, 0, 6),
		Size = UDim2.new(1, -20, 0.55, 0),
		Text = "",
		Parent = refs.banner,
	})
	refs.bannerText = UI.label({
		Position = UDim2.new(0, 10, 0.58, 0),
		Size = UDim2.new(1, -20, 0.36, 0),
		Text = "",
		Parent = refs.banner,
	})

	-- Wskaźnik burzy
	refs.storm = UI.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.new(0, 360, 0, 30),
		BackgroundColor3 = Color3.fromRGB(90, 50, 200),
		BackgroundTransparency = 0.1,
		Text = "BURZA MAGNETYCZNA · LUCK x" .. Config.Events.StormLuck,
		Visible = false,
		Parent = gui,
	})
	UI.corner(8).Parent = refs.storm

	-- Błysk ekranu
	refs.flash = UI.make("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = overlay,
	})

	return refs
end

function UI.refs()
	return refs
end

function UI.refreshStats()
	local cash = player:GetAttribute("Cash") or 0
	local cps = player:GetAttribute("CPS") or 0
	local pending = player:GetAttribute("Pending") or 0
	local carried = player:GetAttribute("Carried") or 0
	local capacity = player:GetAttribute("Capacity") or 1
	local magnet = Config.Magnets[player:GetAttribute("Magnet") or 1]
	refs.cash.Text = "Kasa: " .. Format.money(cash)
	refs.cps.Text = "Dochód: " .. Format.money(cps) .. "/s"
	refs.pending.Text = "W Kasie garażu: " .. Format.money(pending)
	refs.carried.Text = "Niesiesz: " .. carried .. "/" .. capacity
	refs.carried.TextColor3 = if carried >= capacity then Color3.fromRGB(255, 120, 120) else Color3.new(1, 1, 1)
	refs.magnet.Text = "Magnes: " .. (magnet and magnet.name or "?")
	refs.protected.Visible = player:GetAttribute("Protected") == true
	refs.storm.Visible = workspace:GetAttribute("Storm") == true
end

function UI.refreshZone()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local text, safe = Geo.zoneLabel(root.Position)
	refs.zone.Text = text
	refs.zone.TextColor3 = if safe then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 110, 110)
end

local toastColors = {
	info = Color3.fromRGB(40, 40, 50),
	good = Color3.fromRGB(30, 110, 50),
	bad = Color3.fromRGB(140, 35, 35),
}
local toastOrder = 0

function UI.toast(text: string, kind: string?)
	toastOrder += 1
	local t = UI.label({
		LayoutOrder = toastOrder,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = toastColors[kind or "info"] or toastColors.info,
		BackgroundTransparency = 0.15,
		Text = text,
		TextStrokeTransparency = 0.6,
		Parent = refs.toasts,
	})
	UI.corner(8).Parent = t
	UI.make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = t })
	local children = refs.toasts:GetChildren()
	local labels = {}
	for _, c in ipairs(children) do
		if c:IsA("TextLabel") then
			table.insert(labels, c)
		end
	end
	if #labels > 4 then
		table.sort(labels, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		labels[1]:Destroy()
	end
	task.delay(4, function()
		if t.Parent then
			TweenService:Create(t, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			task.wait(0.4)
			t:Destroy()
		end
	end)
end

local bannerToken = 0
function UI.banner(title: string, text: string, color: Color3, seconds: number?)
	bannerToken += 1
	local my = bannerToken
	refs.bannerTitle.Text = title
	refs.bannerTitle.TextColor3 = color
	refs.bannerText.Text = text
	refs.bannerStroke.Color = color
	TweenService:Create(refs.banner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 40),
	}):Play()
	task.delay(seconds or 4, function()
		if bannerToken == my then
			TweenService:Create(refs.banner, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -140) }):Play()
		end
	end)
end

function UI.flash(color: Color3, strength: number?)
	refs.flash.BackgroundColor3 = color
	refs.flash.BackgroundTransparency = 1 - (strength or 0.6)
	TweenService:Create(refs.flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
end

return UI
