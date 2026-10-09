-- Pomocnicze funkcje sieciowe serwera.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Net = {}

function Net.event(name: string): RemoteEvent
	return Remotes:WaitForChild(name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return Remotes:WaitForChild(name) :: RemoteFunction
end

-- kind: "info" | "good" | "bad"
function Net.notify(player: Player, text: string, kind: string?)
	Net.event("Notify"):FireClient(player, text, kind or "info")
end

function Net.broadcast(text: string, kind: string?)
	Net.event("Notify"):FireAllClients(text, kind or "info")
end

function Net.alert(data: { [string]: any })
	Net.event("Alert"):FireAllClients(data)
end

return Net
