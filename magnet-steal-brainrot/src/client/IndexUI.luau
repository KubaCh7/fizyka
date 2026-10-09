-- Index (kolekcja): 30 Brainrotów, odkryte pokazują nazwę i kolor tieru.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Brainrots = require(Shared.Brainrots)

local UI = require(script.Parent.UI)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local IndexUI = {}

local frame: Frame
local cells: { [string]: TextLabel } = {}
local counter: TextLabel
local discovered: { [string]: boolean } = {}

function IndexUI.refresh()
	local found = 0
	for _, b in ipairs(Brainrots.List) do
		local cell = cells[b.id]
		local rarity = Config.Rarities[Config.RarityIndex[b.rarity]]
		if discovered[b.id] then
			found += 1
			cell.Text = b.name
			cell.TextColor3 = rarity.color
			cell.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
		else
			cell.Text = "??? (" .. b.rarity .. ")"
			cell.TextColor3 = Color3.fromRGB(110, 110, 120)
			cell.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
		end
	end
	counter.Text = ("Odkryto %d / %d"):format(found, #Brainrots.List)
end

function IndexUI.toggle()
	frame.Visible = not frame.Visible
	IndexUI.refresh()
end

function IndexUI.init()
	frame = UI.make("Frame", {
		Name = "Index",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 720, 0, 460),
		BackgroundColor3 = Color3.fromRGB(22, 20, 32),
		Visible = false,
		ZIndex = 40,
		Parent = UI.root(),
	}, { UI.corner(16), UI.stroke(3, Color3.fromRGB(140, 110, 255)) })
	UI.label({
		Position = UDim2.new(0, 16, 0, 8),
		Size = UDim2.new(0.5, 0, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "BRAINROT INDEX",
		TextColor3 = Color3.fromRGB(170, 140, 255),
		ZIndex = 41,
		Parent = frame,
	})
	counter = UI.label({
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0.5, -70, 0, 28),
		Text = "",
		ZIndex = 41,
		Parent = frame,
	})
	local closeButton = UI.button("X", Color3.fromRGB(200, 60, 60), {
		Position = UDim2.new(1, -54, 0, 8),
		Size = UDim2.new(0, 44, 0, 36),
		ZIndex = 41,
		Parent = frame,
	})
	closeButton.MouseButton1Click:Connect(function()
		frame.Visible = false
	end)

	-- Siatka: kolumna = strefa, wiersz = rzadkość
	local grid = UI.make("Frame", {
		Position = UDim2.new(0, 12, 0, 52),
		Size = UDim2.new(1, -24, 1, -64),
		BackgroundTransparency = 1,
		ZIndex = 41,
		Parent = frame,
	})
	local zones = #Config.Zones
	local rarities = #Config.Rarities
	for z = 1, zones do
		UI.label({
			Position = UDim2.new((z - 1) / zones, 2, 0, 0),
			Size = UDim2.new(1 / zones, -4, 0, 24),
			Text = z .. ". " .. Config.Zones[z].name,
			TextColor3 = Config.Zones[z].color,
			ZIndex = 42,
			Parent = grid,
		})
	end
	for _, b in ipairs(Brainrots.List) do
		local r = Config.RarityIndex[b.rarity]
		local cell = UI.label({
			Position = UDim2.new((b.zone - 1) / zones, 3, 0, 28 + (r - 1) * 60),
			Size = UDim2.new(1 / zones, -6, 0, 54),
			BackgroundTransparency = 0,
			TextStrokeTransparency = 0.6,
			ZIndex = 42,
			Text = "",
			Parent = grid,
		})
		UI.corner(8).Parent = cell
		UI.make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = cell })
		cells[b.id] = cell
	end
	assert(rarities == 6, "Siatka Indexu zakłada 6 rzadkości")

	Remotes.IndexUpdate.OnClientEvent:Connect(function(index)
		if type(index) == "table" then
			discovered = index
			IndexUI.refresh()
		end
	end)
	IndexUI.refresh()
end

return IndexUI
