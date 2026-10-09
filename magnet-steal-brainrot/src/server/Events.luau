-- Eventy serwerowe. Na razie: Burza Magnetyczna (Luck x2) co 10 minut.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Net = require(script.Parent.Net)

local Events = {}

local stormActive = false

function Events.luckMultiplier(): number
	return if stormActive then Config.Events.StormLuck else 1
end

local function setStorm(on: boolean)
	stormActive = on
	workspace:SetAttribute("Storm", on)
	local goal = if on
		then { OutdoorAmbient = Color3.fromRGB(90, 70, 160), ClockTime = 19.5 }
		else { OutdoorAmbient = Color3.fromRGB(140, 140, 150), ClockTime = 14.5 }
	TweenService:Create(Lighting, TweenInfo.new(3), goal):Play()
	Net.alert({
		kind = "event",
		title = if on then "BURZA MAGNETYCZNA!" else "Burza minęła",
		text = if on
			then "Luck x" .. Config.Events.StormLuck .. " przez " .. Config.Events.StormDuration .. " s"
			else "Do następnej burzy " .. math.floor(Config.Events.StormEvery / 60) .. " min",
		on = on,
	})
end

function Events.start()
	task.spawn(function()
		task.wait(Config.Events.StormFirstDelay)
		while true do
			setStorm(true)
			task.wait(Config.Events.StormDuration)
			setStorm(false)
			task.wait(math.max(0, Config.Events.StormEvery - Config.Events.StormDuration))
		end
	end)
end

return Events
