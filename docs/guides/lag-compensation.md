# Lag Compensation
Lag compensation for hitboxes is usually done with a table of player movement snapshots so you can rewind and view where a player was at. Chrono timestamps server snapshots using the server's os.clock while forwarding the client's clock for interpolation. This allows lag compensation to be done easily.

## How?

### Client
When firing a hitbox event, send `workspace:GetServerTimeNow()`:

```lua
local clientServerTimeNow = workspace:GetServerTimeNow()
Hitbox:FireServer(targetPlayer, clientServerTimeNow)
```

### Server
To use it for hit validation, receive the time, then rewind.

```lua
local Entity = require(chrono.Shared.Entity)
local Holder = require(chrono.Shared.Holder)

Hitbox.OnServerEvent:Connect(function(attacker: Player, target: Player, clientServerTimeNow: number)
	local latency = workspace:GetServerTimeNow() - clientServerTimeNow
	local rewindTo = os.clock() - latency
	local attackerWasAt = Entity.GetAt(Holder.GetEntityFromPlayer(attacker), rewindTo)
	local targetWasAt = Entity.GetAt(Holder.GetEntityFromPlayer(target), rewindTo)
end)
```