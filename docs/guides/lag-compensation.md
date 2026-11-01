# Lag Compensation

Lag compensation checks a hit against where the shooter saw the target. Chrono keeps a snapshot history for each entity, so the server can read a past position with `Entity.GetAt(entity, time)`.

## How it works

The client sends a time with the shot. The server turns it into a rewind time on its own clock (`os.clock()`), then reads the target's position at that time with `Entity.GetAt`.

There are three common ways to get the rewind time.

### Shot time

The client sends `workspace:GetServerTimeNow()`. The server rewinds by how long the shot took to arrive.

```lua
-- Client
Shoot:FireServer(target.id, workspace:GetServerTimeNow())
```

```lua
-- Server
local latency = workspace:GetServerTimeNow() - shotTime
local rewindTo = os.clock() - latency
```

This leaves out the interpolation buffer and the snapshot's trip to the shooter, so the rewind lands behind what the shooter saw.

### ServerClock (recommended)

The client sends `Entity.GetTargetRenderTime(target)`. The server converts it with `ServerClock.ToServerTime`.

```lua
-- Client
Shoot:FireServer(target.id, Entity.GetTargetRenderTime(target))
```

```lua
-- Server
local rewindTo = ServerClock.ToServerTime(target, renderTime)
```

`ToServerTime` clamps the result to the last second by default. The third argument sets the rewind limit. Returns nil for a missing entity or invalid time.

### Interpolation buffer

The client sends the shot time and its interpolation buffer for the target. The server subtracts the buffer, and subtracts the latency a second time as an estimate.

```lua
-- Client
local clock = Entity.GetClock(target)
local buffer = clock:GetEstimatedServerTime() - Entity.GetTargetRenderTime(target)
Shoot:FireServer(target.id, workspace:GetServerTimeNow(), buffer)
```

```lua
-- Server
local latency = workspace:GetServerTimeNow() - shotTime
local rewindTo = os.clock() - 2 * latency - buffer
```

!!! warning
    This has no rewind limit, so clamp `rewindTo`.

### Comparison

| | Shot time | ServerClock | Interpolation buffer |
|---|---|---|---|
| Client sends | `GetServerTimeNow()` | Target's render time | `GetServerTimeNow()` and buffer |
| Accuracy | Behind by the buffer and network delay | Matches the shooter's view | Close when latency is even |
| Uneven latency | Behind | Unaffected | Off by the difference |
| Median error, tested at 16 studs/s | 2–4 studs | 0.001–0.3 studs | 0.3–2 studs |

## Example: hitscan

The client raycasts and sends the target's ID and render time:

```lua
-- Client
local Shoot = ReplicatedStorage.Shoot 

local function FireShot(origin: Vector3, direction: Vector3)
	local result = workspace:Raycast(origin, direction)
	local model = result and (result.Instance:FindFirstAncestorOfClass("Model") or result.Instance)
	local target = model and Holder.GetEntityFromModel(model)
	if target then
		Shoot:FireServer(origin, target.id, Entity.GetTargetRenderTime(target))
	end
end
```

The server reads the target's past position and checks the distance:

```lua
-- Server
local Shoot = ReplicatedStorage.Shoot
local HIT_RADIUS = 3 -- studs

Shoot.OnServerEvent:Connect(function(shooter: Player, origin: Vector3, targetId: number, renderTime: number)
	local target = Holder.GetEntityFromId(targetId)
	local rewindTo = ServerClock.ToServerTime(target, renderTime)
	if not rewindTo then
		return
	end
	local wasAt = Entity.GetAt(target, rewindTo)
	if wasAt and (wasAt.Position - origin).Magnitude <= HIT_RADIUS then
		print(shooter.Name, "hit", targetId)
	end
end)
```

Replace the distance check with your game's hitbox test. For melee and projectiles, send the target and its render time the same way.

!!! note
    Clients control the time they send. Also check the shot's origin and line of sight on the server.

## Things to note

- Set `STORE_SNAPSHOTS = true` for server-owned entities. Without it, `Entity.GetAt` returns the current CFrame. Client-owned entities always keep history.
- Keep the rewind limit within your snapshot history. The default [`MAX_SNAPSHOT_COUNT`](../getting-started/configurations.md#max-snapshot-count) of 30 covers about 1.5 seconds at 20 Hz. Times outside the history return the nearest snapshot.
- In v2.2.3 and earlier, `ServerClock.ToServerTime` isn't available. For client-owned targets, use `renderTime + (target.latestTime - target.lastClientClock)` and clamp it yourself.
