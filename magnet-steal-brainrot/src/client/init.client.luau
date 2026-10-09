-- Magnet & Steal a Brainrot - punkt startowy klienta.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local UI = require(script.UI)
local Effects = require(script.Effects)
local Minigame = require(script.Minigame)
local Tug = require(script.Tug)
local ShopUI = require(script.ShopUI)
local IndexUI = require(script.IndexUI)
local Tools = require(script.Tools)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local refs = UI.build()
Effects.start()
Minigame.init()
Tug.init()
ShopUI.init()
IndexUI.init()
Tools.init()

refs.shopButton.MouseButton1Click:Connect(ShopUI.toggle)
refs.indexButton.MouseButton1Click:Connect(IndexUI.toggle)
refs.devButton.MouseButton1Click:Connect(function()
	Remotes.DevCheat:FireServer()
end)

Remotes.Notify.OnClientEvent:Connect(function(text, kind)
	UI.toast(text, kind)
end)

Remotes.Ragdoll.OnClientEvent:Connect(function(seconds, impulse)
	Effects.ragdoll(seconds, impulse)
end)

local function nearMe(position: Vector3?, radius: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and position ~= nil and (root.Position - position).Magnitude <= radius
end

Remotes.Alert.OnClientEvent:Connect(function(data)
	local kind = data.kind
	local rarity = Config.Rarities[data.rarity or 1] or Config.Rarities[1]
	if kind == "catch" then
		local isMe = data.player == player.DisplayName
		UI.banner(
			string.upper(rarity.id) .. " DROP!",
			data.player .. " wyłowił: " .. data.itemName .. " (strefa " .. tostring(data.zone) .. ")",
			rarity.color,
			if rarity.id == "Mythic" then 7 else 5
		)
		UI.flash(rarity.color, if isMe then 0.8 else 0.45)
		Effects.play("Alert", 0.9)
		Effects.shake(if isMe then 4 else 2, 0.6)
	elseif kind == "hooked" then
		UI.banner(
			"NA HACZYKU: " .. string.upper(rarity.id) .. "!",
			data.player .. " wyciąga coś ogromnego w strefie " .. tostring(data.zone) .. " - słup światła wskazuje miejsce!",
			rarity.color,
			4
		)
		Effects.play("Clank", 0.8, 0.8)
	elseif kind == "steal" then
		local text = data.player .. " ukradł " .. data.itemName .. " graczowi " .. data.victim .. "!"
		if rarity.inHands then
			UI.banner("KRADZIEŻ " .. string.upper(rarity.id) .. "!", text, rarity.color, 4)
			Effects.play("Steal", 0.9, 0.8)
		else
			UI.toast(text, "info")
		end
	elseif kind == "sunk" then
		UI.banner(
			string.upper(rarity.id) .. " ZATONĄŁ!",
			data.itemName .. " leży na dnie" .. (if data.player ~= "" then " (wypadł graczowi " .. data.player .. ")" else "") .. ". Kto pierwszy rzuci magnes, ten bierze!",
			rarity.color,
			5
		)
	elseif kind == "splash" then
		if nearMe(data.position, 90) then
			Effects.play("Splash", 0.9)
		end
	elseif kind == "slip" then
		if nearMe(data.position, 70) then
			Effects.play("Slip", 0.8)
		end
	elseif kind == "event" then
		UI.banner(data.title, data.text, Color3.fromRGB(150, 110, 255), 5)
		if data.on then
			UI.flash(Color3.fromRGB(120, 80, 255), 0.5)
			Effects.play("Alert", 0.7, 0.7)
		end
	elseif kind == "rebirth" then
		UI.toast(data.player .. " zrobił REBIRTH " .. tostring(data.rebirths) .. "!", "good")
	elseif kind == "collect" then
		UI.toast("+" .. Format.money(data.amount) .. " z Kasy garażu", "good")
		Effects.play("Buy", 0.6, 1.2)
	end
end)

for _, name in ipairs({ "Cash", "CPS", "Pending", "Carried", "Capacity", "Magnet", "Protected" }) do
	player:GetAttributeChangedSignal(name):Connect(UI.refreshStats)
end
workspace:GetAttributeChangedSignal("Storm"):Connect(UI.refreshStats)
UI.refreshStats()

task.spawn(function()
	while true do
		UI.refreshZone()
		task.wait(0.25)
	end
end)

UI.toast("Weź Wędkę Magnetyczną (1), podejdź do kanału i przytrzymaj klik!", "info")
