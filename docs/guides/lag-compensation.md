# Lag Compensation
Lag compensation for hitboxes is usually done with a table of player movement snapshots so you can rewind and view where a player was at. This should have been easy enough but since Chrono doesn't use `GetServerTimeNow` for timestamping snapshots, it will be a more involved process if you want to use chrono's snapshot system for lag compensation.

## How to use ServerClock
We implemented a tiny clock conversion layer that maps each player's client clock to the server's os.clock. The idea is that each player has a smoothed per-player offset (serverclock - clientclock) so you can convert timestamps between environments by just adding the offset.

When you attempt lag compensation, you will need to provide a `GetServerTimeNow()`  value so the conversion system can remove network delay from the clock offset calculation. This gives you actually accurate lag compensation

### Client
When firing a hitbox event, send both `os.clock()` and `workspace:GetServerTimeNow()`:

```lua
local hitTimeClient = os.clock()
local clientServerTimeNow = workspace:GetServerTimeNow()
Hitbox:FireServer(targetPlayer, hitTimeClient, clientServerTimeNow)
```

### Server
To use it for hit validation, receive the client's `os.clock()` and `GetServerTimeNow()`, then convert to server time and rewind the snapshot.

```lua
local ServerClock = require(chrono.Server.ServerClock)

Hitbox.OnServerEvent:Connect(function(attacker: Player, target: Player, hitTimeClient: number, clientServerTimeNow: number)
	ServerClock.Store(attacker, hitTimeClient, clientServerTimeNow)
	local hitTimeConverted = ServerClock.ConvertTo(attacker, hitTimeClient, "Server")

	local attackerWasAt = Entity.GetAt(Holder.GetEntityFromPlayer(attacker), hitTimeConverted)
	local targetWasAt = Entity.GetAt(Holder.GetEntityFromPlayer(target), hitTimeConverted)
end)
```