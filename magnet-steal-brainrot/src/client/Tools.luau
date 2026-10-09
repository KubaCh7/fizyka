-- Obsługa narzędzi: wędka (ładowanie rzutu), hak do kradzieży, banan, tarcza.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(script.Parent.UI)
local Effects = require(script.Parent.Effects)
local Minigame = require(script.Parent.Minigame)
local Tug = require(script.Parent.Tug)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local Tools = {}

local bound: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local charging = false
local chargeStart = 0

local CHARGE_PERIOD = 1.2

local function chargePower(): number
	-- Ping-pong 0 -> 1 -> 0
	local t = ((os.clock() - chargeStart) / CHARGE_PERIOD) % 2
	return if t <= 1 then t else 2 - t
end

local function busy(): boolean
	return Minigame.isActive() or Tug.isActive()
end

local function bindFishing(tool: Tool)
	tool.Activated:Connect(function()
		if busy() or charging then
			return
		end
		charging = true
		chargeStart = os.clock()
		UI.refs().charge.Visible = true
	end)
	local function releaseCast()
		if not charging then
			return
		end
		charging = false
		UI.refs().charge.Visible = false
		Remotes.CastRequest:FireServer(chargePower())
	end
	tool.Deactivated:Connect(releaseCast)
	tool.Unequipped:Connect(function()
		charging = false
		UI.refs().charge.Visible = false
	end)
end

local function bindSteal(tool: Tool)
	tool.Activated:Connect(function()
		if busy() then
			return
		end
		Effects.play("Steal", 0.5, 1.2)
		Remotes.StealRequest:FireServer(mouse.Hit.Position)
	end)
end

local function bindTool(tool: Instance)
	if not tool:IsA("Tool") or bound[tool] then
		return
	end
	bound[tool] = true
	if tool.Name == "Wędka Magnetyczna" then
		bindFishing(tool)
	elseif tool.Name == "Hak do Kradzieży" then
		bindSteal(tool)
	elseif tool.Name == "Skórka od Banana" then
		tool.Activated:Connect(function()
			Remotes.PlaceBanana:FireServer()
		end)
	elseif tool.Name == "Tarcza Magnesowa" then
		tool.Activated:Connect(function()
			Remotes.UseShield:FireServer()
		end)
	end
end

local function watch(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		bindTool(child)
	end
	container.ChildAdded:Connect(bindTool)
end

function Tools.init()
	watch(player:WaitForChild("Backpack"))
	player.CharacterAdded:Connect(function(character)
		watch(character)
		watch(player:WaitForChild("Backpack"))
	end)
	if player.Character then
		watch(player.Character)
	end

	RunService.RenderStepped:Connect(function()
		if charging then
			UI.refs().chargeNeedle.Position = UDim2.new(chargePower(), 0, 0.5, 0)
		end
	end)
end

return Tools
