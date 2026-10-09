--!strict
-- Geometria mapy: gdzie są garaże, pomosty i strefy kanału.
-- Używana przez serwer (walidacja) i klienta (HUD).

local Config = require(script.Parent.Config)

local L = Config.Layout
local Geo = {}

function Geo.plotCenter(index: number): Vector3
	return Vector3.new(L.PlotStartX + (index - 1) * L.PlotSpacing, 0, L.PlotCenterZ)
end

function Geo.plotFrontZ(): number
	return L.PlotCenterZ + L.PlotSizeZ / 2
end

-- Indeks działki, na której stoi pozycja (z podjazdem), albo nil
function Geo.plotAt(pos: Vector3): number?
	local halfX = L.PlotSizeX / 2
	local minZ = L.PlotCenterZ - L.PlotSizeZ / 2 - 2
	local maxZ = Geo.plotFrontZ() + L.DrivewayDepth
	if pos.Z < minZ or pos.Z > maxZ then
		return nil
	end
	for i = 1, L.PlotCount do
		local c = Geo.plotCenter(i)
		if math.abs(pos.X - c.X) <= halfX then
			return i
		end
	end
	return nil
end

function Geo.isSafe(pos: Vector3): boolean
	return Geo.plotAt(pos) ~= nil
end

function Geo.zoneAtZ(z: number): number
	local idx = math.floor(math.max(z - L.CanalStartZ, 0) / L.ZoneLength) + 1
	return math.clamp(idx, 1, #Config.Zones)
end

function Geo.pierAt(pos: Vector3): number?
	for _, x in ipairs(L.PierXs) do
		if math.abs(pos.X - x) <= L.PierWidth / 2 + 1 then
			if pos.Z >= L.CanalStartZ - 3 and pos.Z <= L.CanalStartZ + L.ZoneLength * #Config.Zones + 2 then
				return x
			end
		end
	end
	return nil
end

-- Strefa łowienia dla pozycji HumanoidRootPart albo nil (za daleko od wody)
function Geo.fishingZone(pos: Vector3): number?
	if pos.Y < 0 then
		return nil -- w wodzie nie łowimy
	end
	if Geo.pierAt(pos) then
		return Geo.zoneAtZ(pos.Z)
	end
	local atBank = pos.Z >= L.CanalStartZ - 7 and pos.Z <= L.CanalStartZ + 1
	if atBank and pos.X > L.CanalMinX and pos.X < L.CanalMaxX then
		return 1
	end
	return nil
end

-- Punkt na wodzie, w który wpada magnes
function Geo.castPoint(pos: Vector3, look: Vector3): Vector3
	local pierX = Geo.pierAt(pos)
	if pierX then
		local side = look.X
		if math.abs(side) < 0.2 then
			side = pos.X - pierX
		end
		local dir = if side >= 0 then 1 else -1
		return Vector3.new(pierX + dir * (L.PierWidth / 2 + 4), L.WaterY, pos.Z + look.Z * 3)
	end
	return Vector3.new(pos.X + look.X * 3, L.WaterY, L.CanalStartZ + 5)
end

function Geo.inWater(pos: Vector3): boolean
	if pos.Y >= 0 then
		return false
	end
	return pos.X > L.CanalMinX
		and pos.X < L.CanalMaxX
		and pos.Z > L.CanalStartZ
		and pos.Z < L.CanalStartZ + L.ZoneLength * #Config.Zones + 6
end

function Geo.zoneLabel(pos: Vector3): (string, boolean)
	local plot = Geo.plotAt(pos)
	if plot then
		return "Garaż (Safe Zone)", true
	end
	local z = Geo.fishingZone(pos)
	if z then
		return "Strefa " .. z .. ": " .. Config.Zones[z].name .. " (Lawless)", false
	end
	if Geo.inWater(pos) then
		return "W kanale! (Lawless)", false
	end
	return "Ulica (Lawless Zone)", false
end

return Geo
