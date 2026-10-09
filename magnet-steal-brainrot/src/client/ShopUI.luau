-- Sklep: magnesy, liny, transport, garaż, przedmioty, Rebirth.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local UI = require(script.Parent.UI)
local Effects = require(script.Parent.Effects)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local ShopUI = {}

local frame: Frame
local rows: { [string]: { title: TextLabel, desc: TextLabel, button: TextButton } } = {}

local function attr(name: string, default: any): any
	local v = player:GetAttribute(name)
	if v == nil then
		return default
	end
	return v
end

local function rebirthCost(r: number): number
	return Config.Rebirth.baseCost * Config.Rebirth.costGrowth ^ r
end

-- Opis aktualnego i następnego poziomu dla każdej ścieżki
local function describe(category: string): (string, string, number?)
	if category == "Magnet" then
		local lvl = attr("Magnet", 1)
		local cur, nxt = Config.Magnets[lvl], Config.Magnets[lvl + 1]
		local desc = ("Teraz: %s · %d kg · zasięg %d m · luck +%d%%"):format(cur.name, cur.pull, cur.reach, math.floor(cur.luck * 100))
		if not nxt then
			return "Magnes (MAX)", desc, nil
		end
		return "Magnes → " .. nxt.name, desc .. ("\nNastępny: %d kg · zasięg %d m · pole %d%% · CD %.1f s"):format(nxt.pull, nxt.reach, math.floor(nxt.field * 100), nxt.cooldown), nxt.price
	elseif category == "Rope" then
		local lvl = attr("Rope", 1)
		local cur, nxt = Config.Ropes[lvl], Config.Ropes[lvl + 1]
		local desc = ("Teraz: %s · wytrzymałość %d · zasięg kradzieży %d"):format(cur.name, cur.durability, cur.pvpRange)
		if not nxt then
			return "Lina (MAX)", desc, nil
		end
		return "Lina → " .. nxt.name, desc .. ("\nNastępna: wytrzymałość %d · nawijanie x%.2f · zasięg %d"):format(nxt.durability, nxt.reel, nxt.pvpRange), nxt.price
	elseif category == "Transport" then
		local lvl = attr("Transport", 1)
		local cur, nxt = Config.Transports[lvl], Config.Transports[lvl + 1]
		local desc = ("Teraz: %s · %d szt."):format(cur.name, cur.capacity)
		if not nxt then
			return "Transport (MAX)", desc, nil
		end
		return "Transport → " .. nxt.name, desc .. ("\nNastępny: %d szt. naraz"):format(nxt.capacity), nxt.price
	elseif category == "Garage" then
		local lvl = attr("Garage", 1)
		local cur, nxt = Config.GarageLevels[lvl], Config.GarageLevels[lvl + 1]
		local desc = ("Teraz: %d stojaków"):format(cur.slots)
		if not nxt then
			return "Garaż (MAX)", desc, nil
		end
		return "Rozbudowa garażu → " .. nxt.slots .. " stojaków", desc, nxt.price
	elseif category == "Banana" then
		local cfg = Config.Items.BananaPack
		return cfg.name, "Pułapka: kto wejdzie, ten leży 1,5 s i gubi łup. Masz: " .. attr("Bananas", 0), cfg.price
	elseif category == "Shield" then
		local cfg = Config.Items.Shield
		if attr("HasShield", false) then
			return cfg.name .. " (KUPIONA)", "Odporność na kradzież przez " .. cfg.duration .. " s, CD " .. cfg.cooldown .. " s", nil
		end
		return cfg.name, "Odporność na kradzież przez " .. cfg.duration .. " s, CD " .. cfg.cooldown .. " s", cfg.price
	elseif category == "Rebirth" then
		local r = attr("Rebirths", 0)
		return "REBIRTH " .. (r + 1),
			("Reset postępu za +%d%% CPS i +%d%% Luck na zawsze. Masz %d Rebirth."):format(
				math.floor(Config.Rebirth.cpsBonus * 100),
				math.floor(Config.Rebirth.luckBonus * 100),
				r
			),
			rebirthCost(r)
	end
	return category, "", nil
end

local ORDER = { "Magnet", "Rope", "Transport", "Garage", "Banana", "Shield", "Rebirth" }

function ShopUI.refresh()
	if not frame or not frame.Visible then
		return
	end
	local cash = attr("Cash", 0)
	for _, category in ipairs(ORDER) do
		local row = rows[category]
		local title, desc, price = describe(category)
		row.title.Text = title
		row.desc.Text = desc
		if price then
			row.button.Text = Format.money(price)
			row.button.BackgroundColor3 = if cash >= price then Color3.fromRGB(50, 180, 80) else Color3.fromRGB(110, 110, 115)
			row.button.Active = true
		else
			row.button.Text = "—"
			row.button.BackgroundColor3 = Color3.fromRGB(70, 70, 75)
			row.button.Active = false
		end
	end
end

function ShopUI.toggle()
	frame.Visible = not frame.Visible
	ShopUI.refresh()
end

function ShopUI.init()
	frame = UI.make("Frame", {
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 640, 0, 520),
		BackgroundColor3 = Color3.fromRGB(25, 25, 32),
		Visible = false,
		ZIndex = 40,
		Parent = UI.root(),
	}, { UI.corner(16), UI.stroke(3, Color3.fromRGB(255, 170, 30)) })
	UI.make("UISizeConstraint", { MaxSize = Vector2.new(640, 520), Parent = frame })
	UI.label({
		Position = UDim2.new(0, 16, 0, 8),
		Size = UDim2.new(1, -80, 0, 40),
		Text = "SKLEP ZŁOMIARZA",
		TextColor3 = Color3.fromRGB(255, 190, 60),
		ZIndex = 41,
		Parent = frame,
	})
	local closeButton = UI.button("X", Color3.fromRGB(200, 60, 60), {
		Position = UDim2.new(1, -54, 0, 8),
		Size = UDim2.new(0, 44, 0, 40),
		ZIndex = 41,
		Parent = frame,
	})
	closeButton.MouseButton1Click:Connect(function()
		frame.Visible = false
	end)

	local list = UI.make("ScrollingFrame", {
		Position = UDim2.new(0, 12, 0, 56),
		Size = UDim2.new(1, -24, 1, -68),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 41,
		Parent = frame,
	})
	UI.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	for i, category in ipairs(ORDER) do
		local row = UI.make("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, -10, 0, 74),
			BackgroundColor3 = Color3.fromRGB(40, 40, 50),
			ZIndex = 42,
			Parent = list,
		}, { UI.corner(10) })
		local title = UI.label({
			Position = UDim2.new(0, 10, 0, 4),
			Size = UDim2.new(1, -150, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 43,
			Text = category,
			Parent = row,
		})
		local desc = UI.label({
			Position = UDim2.new(0, 10, 0, 32),
			Size = UDim2.new(1, -150, 0, 38),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(200, 200, 210),
			TextStrokeTransparency = 1,
			ZIndex = 43,
			Text = "",
			Parent = row,
		})
		local button = UI.button("$", Color3.fromRGB(50, 180, 80), {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0, 125, 0, 50),
			ZIndex = 43,
			Parent = row,
		})
		button.MouseButton1Click:Connect(function()
			local ok, msg = Remotes.Purchase:InvokeServer(category)
			UI.toast(msg, if ok then "good" else "bad")
			if ok then
				Effects.play("Buy", 0.7)
			end
			ShopUI.refresh()
		end)
		rows[category] = { title = title, desc = desc, button = button }
	end

	for _, name in ipairs({ "Cash", "Magnet", "Rope", "Transport", "Garage", "Bananas", "HasShield", "Rebirths" }) do
		player:GetAttributeChangedSignal(name):Connect(ShopUI.refresh)
	end
end

return ShopUI
