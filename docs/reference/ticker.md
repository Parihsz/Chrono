# Ticker

Each entity type has one shared ticker on the server, available after `Chrono.Start()` through its config:

```lua
--server
local chrono = require(ReplicatedStorage.Packages.chrono)
local config = chrono.Config.GetEntityType("NPC")
local ticker = assert(config.ticker) -- since its ticker? this converts it to ticker
```

!!! warning
    `config.ticker` is only available on the server. It is nil on clients, and on the server before `Chrono.Start()`. 

If another script calls `Start`, retrieve the config inside [`chrono.Started(function() ... end)`](../getting-started/start-chrono.md#waiting-for-startup) so it is initialized before you access its ticker.

## Ticked signal

### `Ticked:Connect(callback: (ticker: Ticker, dt: number) -> ()) -> Connection`

Connects a handler at the type's `TICK_RATE`. The signal fires on the server before Chrono iterates the entities under the type.

`dt` is elapsed time since the last tick in seconds (it is not clamped).

Use `ticker.lastTicked` as the timestamp for `Entity.Push` if you don't have a model set.

```lua
local connection = ticker.Ticked:Connect(function(tick, dt)
    chrono.Entity.Push(entity, tick.lastTicked, Simulate(dt))
end)
```

## Fields

These fields should be read-only. Modifying them may break Chrono's behavior.

| Field | Meaning |
|---|---|
| `config` | The initialized config. |
| `tickRate` | Configured interval between ticks, in seconds. |
| `lastTicked` | Timestamp to use for `Entity.Push` inside a handler, on the server's `os.clock()` timeline. |
| `dt` | Elapsed time for the current or most recent tick, in seconds.|
| `isHalf` | Whether the current tick also updates half-rate entities. Alternates on each update |
| `objects` | Chrono's active entities of for this type. It does not include entities that are not being ticked|

