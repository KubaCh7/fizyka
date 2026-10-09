-- Dźwięki, wstrząsy kamery, tęczowe mutacje i ragdoll (poślizg/szarpnięcie).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local player = Players.LocalPlayer
local Effects = {}

local soundCache: { [string]: Sound } = {}

function Effects.play(name: string, volume: number?, pitch: number?)
	local id = (Config.Sounds :: any)[name]
	if not id then
		return
	end
	local sound = soundCache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Parent = SoundService
		soundCache[name] = sound
	end
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = pitch or 1
	sound.TimePosition = 0
	sound:Play()
end

local shakeUntil, shakePower = 0, 0
function Effects.shake(power: number, seconds: number)
	shakePower = math.max(shakePower, power)
	shakeUntil = math.max(shakeUntil, os.clock() + seconds)
end

local rainbowParts: { BasePart } = {}
local function track(inst: Instance)
	if inst:IsA("BasePart") then
		table.insert(rainbowParts, inst)
	end
end

function Effects.start()
	for _, inst in ipairs(CollectionService:GetTagged("Rainbow")) do
		track(inst)
	end
	CollectionService:GetInstanceAddedSignal("Rainbow"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("Rainbow"):Connect(function(inst)
		local i = table.find(rainbowParts, inst :: any)
		if i then
			table.remove(rainbowParts, i)
		end
	end)

	-- Po skrypcie kamery, żeby wstrząs nie był nadpisany
	RunService:BindToRenderStep("MSB_Effects", Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock()
		local hue = (t * 0.25) % 1
		for _, p in ipairs(rainbowParts) do
			p.Color = Color3.fromHSV(hue, 0.8, 1)
		end
		if t < shakeUntil then
			local camera = workspace.CurrentCamera
			local f = shakePower * ((shakeUntil - t) / 0.5)
			camera.CFrame *= CFrame.Angles(
				math.rad((math.random() - 0.5) * f),
				math.rad((math.random() - 0.5) * f),
				0
			)
		else
			shakePower = 0
		end
	end)
end

-- Ragdoll po stronie klienta (postać jest własnością klienta fizycznie)
function Effects.ragdoll(seconds: number, impulse: Vector3)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end
	Effects.play("Slip", 0.8)
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = impulse
	root.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-3, 3), math.random(-6, 6))
	task.delay(seconds, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

return Effects
